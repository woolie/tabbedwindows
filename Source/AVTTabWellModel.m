//
//  AVTTabbedWindows - AVTTabWellModel.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabWellModel.h"

#import "AVTContainer.h"
#import "AVTTabDocument.h"
#import "AVTTabWellModelDelegate.h"
#import "AVTTabWellModelOrderController.h"

@interface AVTTabWellModel()

- (void) changeSelectedDocumentFrom: (AVTTabDocument*) oldDocument toIndex: (NSInteger) toIndex;

@end

@implementation AVTTabWellModel

- (id) initWithDelegate: (NSObject<AVTTabWellModelDelegate>*) delegate
{
    self = [super init];
    if( self != nil )
    {
        _delegate = delegate;
        _orderController = [[AVTTabWellModelOrderController alloc] initWithTabWellModel: self];
        _selectedIndex = kNoTab;
        _documentData = [[NSMutableArray alloc] initWithCapacity: 100];
    }

    return self;
}

- (void) dealloc
{
    _delegate = nil;
    _document = nil;

    [_documentData release];
    [_observers release];

    [super dealloc];
}

- (BOOL) isContextMenuCommand: (AVTContextMenuCommand) commandID
       enabledForContextIndex: (NSInteger) contextIndex
{
    NSAssert( commandID > eCommandFirst && commandID < eCommandLast, @"Invalid context menu command" );

    switch( commandID )
    {
        case eCommandNewTab:
        case eCommandCloseTab:
        {
            return [self.delegate canCloseTab];
        }

        case eCommandReload:
        {
            AVTTabDocument* document = [self tabDocumentAtIndex: contextIndex];
            if( document )
            {
                if( [document.delegate respondsToSelector: @selector( canReloadDocument: )] )
                {
                    return [document.delegate canReloadDocument: document];
                }
                else
                {
                    return false;
                }
            }
            else
            {
                return false;
            }
        }

        case eCommandCloseOtherTabs:
        {
            NSUInteger miniTabCount = self.indexOfFirstNonMiniTab;
            NSUInteger nonMiniTabCount = self.count - miniTabCount;

            // Close other doesn't effect mini-tabs.

            return nonMiniTabCount > 1 || (nonMiniTabCount == 1 && contextIndex != miniTabCount);
        }

        case eCommandCloseTabsToRight:
        {
            // Close doesn't affect mini-tabs.

            return self.count != self.indexOfFirstNonMiniTab && contextIndex < (self.count - 1);
        }

        case eCommandDuplicate:
        {
            return [self.delegate canDuplicateDocumentAtIndex: contextIndex];
        }

        case eCommandRestoreTab:
        {
            return [self.delegate canRestoreTab];
        }

        case eCommandTogglePinned:
        {
            return ! [self isAppTabForIndex: contextIndex];
        }

        default:
        {
            NSAssert( NO, @"Unhandled command id" );
            break;
        }
    }

    return false;
}

// Determines if the specified index is contained within the TabWellModel.

- (BOOL) containsIndex: (NSInteger) index
{
    return index >= 0 && index < self.count;
}

- (void) tabDocumentWasDestroyed: (AVTTabDocument*) document
{
    NSInteger index = [self indexOfTabDocument: document];
    if( index != kNoTab )
    {
        // Note that we only detach the document here, not close it - it's already been closed. We just want to undo our bookkeeping.

        [self detachTabDocumentAtIndex: index];
    }
}

- (NSInteger) addTabDocument: (AVTTabDocument*) document
                     atIndex: (NSInteger) index
                withAddTypes: (NSUInteger) addTypes
{
    // If the newly-opened tab is part of the same task as the parent tab, we want
    // to inherit the parent's "group" attribute, so that if this tab is then
    // closed we'll jump back to the parent tab.

    BOOL inherit_group = (addTypes & eAddInheritGroup) == eAddInheritGroup;

    // For all other types, respect what was passed to us, normalizing -1s and
    // values that are too large.

    if( index < 0 || index > self.count )
        index = [self.orderController determineInsertionIndexForAppending];

    [self insertTabDocument: document
                    atIndex: index
                  withFlags: addTypes | (inherit_group ? eAddInheritGroup : 0)];

    // Reset the index, just in case insert ended up moving it on us.

    index = [self indexOfTabDocument: document];

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];

    return index;
}

// Adds the specified AVTTabDocument in the default location. Tabs opened in the foreground inherit the group of the previously selected tab.

- (void) appendTabDocument: (AVTTabDocument*) document
              inForeground: (BOOL) foreground
{
    NSInteger index = [self.orderController determineInsertionIndexForAppending];
    [self insertTabDocument: document atIndex: index withFlags: foreground ? (eAddInheritGroup | eAddSelected) : eAddNone];

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];
}

// Adds the specified AVTTabDocument at the specified location. |flags| is a bitmask of AVTAddTabTypes; see it for details.
//
// All append/insert methods end up in this method.
//
// NOTE: adding a tab using this method does NOT query the order controller, as such the eAddForceIndex AddType is meaningless here.
// The only time the |index| is changed is if using the index would result in breaking the constraint that all mini-tabs occur before non-mini-tabs.
// See also AddTabDocument.

- (void) insertTabDocument: (AVTTabDocument*) document
                   atIndex: (NSInteger) index
                 withFlags: (NSUInteger) addTypes
{
    BOOL foreground = addTypes & eAddSelected;

    // Force app tabs to be pinned.

    BOOL pin = document.isApp || addTypes & eAddPinned;
    index = [self constrainInsertionIndex: index withMiniTab: pin];

    // In tab dragging situations, if the last tab in the window was detached then the user aborted the drag, we will have the
    // |closing_all| member set (see detachTabDocumentAtIndex:) which will mess with our mojo here. We need to clear this bit.

    self.closingAll = false;

    // Have to get the selected document before we monkey with |document| otherwise we run into problems when we try to change the selected document
    // since the old document and the new document will be the same...

    NSMutableDictionary* data = [NSMutableDictionary dictionaryWithObjectsAndKeys: document, @"document", [NSNumber numberWithBool: pin], @"pinned", nil];

    AVTTabDocument* selectedDocument = [self selectedTabDocument];

    if( (addTypes & eAddInheritGroup) && selectedDocument )
    {
        if( foreground )
        {
            // Forget any existing relationships, we don't want to make things too confusing by having multiple groups active at the same time.

            [self forgetAllOpeners];
        }
    }
    else if( (addTypes & eAddInheritOpener) && selectedDocument )
    {
        if( foreground )
        {
            // Forget any existing relationships, we don't want to make things too
            // confusing by having multiple groups active at the same time.

            [self forgetAllOpeners];
        }
    }

    [self.documentData insertObject: data atIndex: index];

    if( index <= self.selectedIndex )
    {
        // If a tab is inserted before the current selected index, then |selected_index| needs to be incremented.

        self.selectedIndex += 1;
    }

    // This is listened to by (at least) the ContainerWindowController and the TabWellController, in that order.

    NSDictionary* userinfo = @{ kTabDocumentKey : document, kTabDocumentIndexKey : @(index), kTabDocumentInForegroundKey : [NSNumber numberWithBool: foreground] };
    [[NSNotificationCenter defaultCenter] postNotificationName: kDidInsertTabDocumentNotification object: nil userInfo: userinfo];
    
    if( foreground )
        [self changeSelectedDocumentFrom: selectedDocument toIndex: index];

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];
}

// Closes the AVTTabDocument at the specified index. This causes the AVTTabDocument to be destroyed, but it may not happen immediately
// (e.g. if it's a AVTTabDocument). Returns true if the AVTTabDocument was closed immediately, false if it was not
// closed (we may be waiting for a response from an onunload handler, or waiting for the user to confirm closure).

- (void) closeTabDocumentAtIndex: (NSInteger) index
{
    // We now return to our regularly scheduled shutdown procedure.

    AVTTabDocument* detachedDocument = [self tabDocumentAtIndex: index];
    [detachedDocument closingOfTabDidStart: self];    // TODO notification

    if( [self.delegate canCloseDocumentAtIndex: index] )
    {
        // Update the explicitly closed state. If the unload handlers cancel the close the state is reset in AVTContainer. We don't update the explicitly
        // closed state if already marked as explicitly closed as unload handlers call back to this if the close is allowed.

        if( ![self.delegate runUnloadListenerBeforeClosing: detachedDocument] )
        {
//            NSDictionary* userinfo = @{ kTabDocumentKey : detachedDocument, kTabDocumentIndexKey : @(index) };
//            [[NSNotificationCenter defaultCenter] postNotificationName: kDidDetachTabDocumentNotification object: nil userInfo: userinfo];
//
            [detachedDocument destroy: self];
        }
    }

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];
}

- (void) closeAllTabs
{
    for( NSUInteger tabIndex = 0; tabIndex < self.count; ++tabIndex )
    {
        [self closeTabDocumentAtIndex: tabIndex];
    }

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];
}

// Replaces the tab document at |index| with |newDocument|. |type| is passed to the observer. This deletes the AVTTabDocument currently at |index|.

- (void) replaceTabDocument: (AVTTabDocument*) newDocument
                    atIndex: (NSInteger) index
{
    NSAssert( [self containsIndex: index], @"Invalid index" );

    AVTTabDocument* oldDocument = [self tabDocumentAtIndex: index];
    NSMutableDictionary* documentDictionary = self.documentData[index];
    documentDictionary[@"document"] = newDocument;
    [self.documentData replaceObjectAtIndex: index withObject: documentDictionary];

    NSDictionary* userinfo = @{ kOldTabDocumentKey : oldDocument, kNewTabDocumentKey : newDocument };
    [[NSNotificationCenter defaultCenter] postNotificationName: kTabDocumentDidGetReplacedNotification object: nil userInfo: userinfo];

    [oldDocument destroy: self];

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];
}

// Detaches the AVTTabDocument at the specified index from this well. The AVTTabDocument is not destroyed, just removed from display.
// The caller is responsible for doing something with it (e.g. stuffing it into another well).

- (AVTTabDocument*) detachTabDocumentAtIndex: (NSInteger) index
{
    AVTTabDocument* removedDocument = nil;
    if( self.documentData.count )
    {
        NSAssert( [self containsIndex: index], @"Invalid index" );

        removedDocument = [self tabDocumentAtIndex: index];
        NSInteger nextSelectedIndex = [self.orderController determineNewSelectedIndexWithRemovingIndex: index isRemove: YES];

        [self.documentData removeObjectAtIndex: index];
        if( self.count == 0 )
            self.closingAll = YES;

        NSDictionary* userinfo = @{ kTabDocumentKey : removedDocument, kTabDocumentIndexKey : @(index) };
        [[NSNotificationCenter defaultCenter] postNotificationName: kDidDetachTabDocumentNotification object: nil userInfo: userinfo];

        if( self.count )
        {
            if( index == self.selectedIndex )
            {
                [self changeSelectedDocumentFrom: removedDocument toIndex: nextSelectedIndex];
            }
            else if( index < self.selectedIndex )
            {
                // The selected tab didn't change, but its position shifted; update our index to continue to point at it.

                self.selectedIndex = self.selectedIndex - 1;
            }
        }
    }

    [self dumpModelFromMethod: NSStringFromSelector( _cmd )];

    return removedDocument;
}

// Forget all Opener relationships that are stored (but _not_ group relationships!) This is to reduce unpredictable tab switching behavior
// in complex session states. The exact circumstances under which this method is called are left up to the implementation of the selected
// AVTTabWellModelOrderController.

- (void) forgetAllOpeners
{
    // Forget all opener memories so we don't do anything weird with tab re-selection ordering.

    [self.documentData enumerateObjectsUsingBlock: ^( id document, NSUInteger index, BOOL* stop )
    {
//        [document forgetOpener];
    }];
}

// Returns the index of the specified AVTTabDocument, or kNoTab if the AVTTabDocument is not in this TabWellModel.

- (NSInteger) indexOfTabDocument: (AVTTabDocument*) document
{
    NSInteger index = kNoTab;

    for( NSDictionary* documentDictionary in self.documentData )
    {
        index++;

        if( documentDictionary[@"document"] == document )
            break;
    }

    if( [self containsIndex: index] == NO )
        index = kNoTab;

    return index;
}

- (AVTTabDocument*) tabDocumentAtIndex: (NSInteger) index
{
    AVTTabDocument* document = nil;
    if( [self containsIndex: index] )
    {
        NSDictionary* documentDictionary = self.documentData[index];
        document = documentDictionary[@"document"];
    }
    return document;
}

- (void) changeSelectedDocumentFrom: (AVTTabDocument*) oldDocument toIndex: (NSInteger) toIndex
{
    NSAssert( [self containsIndex: toIndex], @"Invalid index" );

    AVTTabDocument* newDocument = [self tabDocumentAtIndex: toIndex];
    if( oldDocument != newDocument )
    {
        AVTTabDocument* lastSelectedDocument = oldDocument;
        if( lastSelectedDocument )
        {
            NSDictionary* userinfo = @{ kTabDocumentKey : lastSelectedDocument, kTabDocumentIndexKey : @(self.selectedIndex) };
            [[NSNotificationCenter defaultCenter] postNotificationName: kDidDeselectTabDocumentNotification object: nil userInfo: userinfo];
        }

        self.selectedIndex = toIndex;

        NSDictionary* userinfo = nil;
        if( oldDocument )
            userinfo = @{ kNewTabDocumentKey : newDocument, kOldTabDocumentKey : oldDocument, kTabDocumentIndexKey : @(self.selectedIndex) };
        else
            userinfo = @{ kNewTabDocumentKey : newDocument, kTabDocumentIndexKey : @(self.selectedIndex) };

        [[NSNotificationCenter defaultCenter] postNotificationName: kDidSelectTabDocumentNotification object: nil userInfo: userinfo];
    }
}

// Selects either the next tab (|foward| is true), or the previous tab (|forward| is false).

- (void) selectRelativeTabWithDirection: (BOOL) forward
{
    // This may happen during automated testing or if a user somehow buffers many key accelerators.

    if( self.documentData.count > 0 )
    {
        NSInteger index = self.selectedIndex;
        NSInteger delta = forward ? 1 : -1;
        do
        {
            index = (index + self.count + delta) % self.count;
        } while( index != self.selectedIndex );

        [self selectTabDocumentAtIndex: index];
    }
}

// Select the AVTTabDocument at the specified index.

- (void) selectTabDocumentAtIndex: (NSInteger) index
{
    if( [self containsIndex: index] )
    {
        [self changeSelectedDocumentFrom: self.selectedTabDocument toIndex: index];
    }
    else
    {
        NSLog( @"[TabbedWindow] internal inconsistency: !-containsIndex: in %s", __PRETTY_FUNCTION__ );
    }
}

- (AVTTabDocument*) selectedTabDocument
{
    return [self tabDocumentAtIndex: self.selectedIndex];
}

- (NSUInteger) count
{
    return self.documentData.count;
}

// Move the AVTTabDocument at the specified index to another index. This method does NOT send Detached/Attached notifications, rather it
// moves the AVTTabDocument inline and sends a Moved notification instead. If |selectAfterMove| is false, whatever tab was selected before
// the move will still be selected, but it's index may have incremented or decremented one slot.
// NOTE: this does nothing if the move would result in app tabs and non-app tabs mixing.

- (void) moveTabDocumentAtIndex: (NSInteger) index
                        toIndex: (NSInteger) toPosition
                selectAfterMove: (BOOL) selectAfterMove
{
    NSAssert( [self containsIndex: index], @"Invalid source index. " );
    if( index != toPosition )
    {
        NSInteger firstNonMiniTab = self.indexOfFirstNonMiniTab;
        if( !((index < firstNonMiniTab && toPosition >= firstNonMiniTab) || (toPosition < firstNonMiniTab && index >= firstNonMiniTab)) )
        {
            [self privateMoveTabDocumentAtIndex: index toIndex: toPosition selectAfterMove: selectAfterMove];
        }
    }
}

// Changes the pinned state of the tab at |index|. See description above class for details on this.

- (void) setTabPinnedForIndex: (NSInteger) index withState: (BOOL) pinned
{
    NSAssert( [self containsIndex: index], @"Setting Pinned state for a tab with an invalid index." );

    if( [self isTabPinnedForIndex: index] != pinned )
    {
#if 0
        if( IsAppTab( index ) )
        {
            if( !pinned )
            {
                // App tabs should always be pinned.
                NOTREACHED();
                return;
            }

            // Changing the pinned state of an app tab doesn't effect it's mini-tab status.

            self.documentData[index]->pinned = pinned;
        }
        else
        {
            // The tab is not an app tab, it's position may have to change as the  mini-tab state is changing.

            NSInteger nonMiniTabIndex = self.indexOfFirstNonMiniTab;
            self.documentData[index]->pinned = pinned;
            if( pinned && index != nonMiniTabIndex )
            {
                [self moveTabDocumentAtIndex: index toIndex: nonMiniTabIndex selectAfterMove: NO];
                return; // Don't send TabPinnedStateChanged notification.
            }
            else if( !pinned && index + 1 != nonMiniTabIndex )
            {
                [self moveTabDocumentAtIndex: index toIndex: nonMiniTabIndex - 1 selectAfterMove: NO];
                return; // Don't send TabPinnedStateChanged notification.
            }

            FOR_EACH_OBSERVER( CTTabStripModelObserver, observers_, TabMiniStateChanged( self.documentData[index]->document, index ) );
        }

        // else: the tab was at the boundary and it's position doesn't need to change.

        FOR_EACH_OBSERVER( CTTabStripModelObserver, observers_, TabPinnedStateChanged( self.documentData[index]->document, index ) );
#endif
    }
}

// Returns true if the tab at |index| is pinned. See description above class for details on pinned tabs.

- (BOOL) isTabPinnedForIndex: (NSInteger) index
{
    NSDictionary* tabDocumentData = self.documentData[index];
    return [tabDocumentData[@"pinned"] boolValue];
}

// Is the tab a mini-tab? See description above class for details on this.

- (BOOL) isMiniTabForIndex: (NSInteger) index
{
    NSDictionary* tabDocumentData = self.documentData[index];
    return [tabDocumentData[@"pinned"] boolValue] || [self isAppTabForIndex: index];
}

// Is the tab at |index| an app? See description above class for details on app tabs.

- (BOOL) isAppTabForIndex: (NSInteger) index
{
    return [self tabDocumentAtIndex: index].isApp;
}

// Returns true if the tab at |index| is blocked by a tab modal dialog.

- (BOOL) isTabBlockedForIndex: (NSInteger) index
{
    NSDictionary* tabDocumentData = self.documentData[index];
    return [tabDocumentData[@"blocked"] boolValue];
}

- (NSInteger) indexOfFirstNonMiniTab
{
    NSInteger foundIndex = self.count;
    NSInteger count = (NSInteger)self.documentData.count;
    for( NSInteger i = 0; i < count; ++i )
    {
        if( [self isMiniTabForIndex: i] == NO )
        {
            foundIndex = i;
            break;
        }
    }

    // No mini-tabs.

    return foundIndex;
}

- (NSInteger) constrainInsertionIndex: (NSInteger) index
                          withMiniTab: (BOOL) miniTab
{
    return miniTab ? MIN( MAX( 0, index ), [self indexOfFirstNonMiniTab] ) : MIN( self.count, MAX( index, [self indexOfFirstNonMiniTab] ) );
}

- (void) closeSelectedTab
{
    [self closeTabDocumentAtIndex: self.selectedIndex];
}

- (void) selectNextTab
{
    [self selectRelativeTabWithDirection: YES];
}

- (void) selectPreviousTab
{
    [self selectRelativeTabWithDirection: NO];
}

- (void) selectLastTab
{
    [self selectTabDocumentAtIndex: self.count - 1];
}

- (void) moveTabNext
{
    NSInteger newIndex = MIN( self.selectedIndex + 1, self.count - 1 );
    [self moveTabDocumentAtIndex: self.selectedIndex toIndex: newIndex selectAfterMove: YES];
}

- (void) moveTabPrevious
{
    NSInteger newIndex = MAX( self.selectedIndex - 1, 0 );
    [self moveTabDocumentAtIndex: self.selectedIndex toIndex: newIndex selectAfterMove: YES];
}

- (void) dumpModelFromMethod: (NSString*) method
{
#ifdef DEBUG
    NSLog( @"-------------------------------------------------------" );
    NSLog( @"Dumping Model from: %@", method );
    NSLog( @"  data: %@", self.documentData );
#endif
}

#pragma mark - Implementation Utilities

- (void) privateMoveTabDocumentAtIndex: (NSInteger) index
                               toIndex: (NSInteger) toPosition
                       selectAfterMove: (BOOL) selectAfterMove
{
    [self.documentData exchangeObjectAtIndex: (NSUInteger)toPosition withObjectAtIndex: (NSUInteger)index];

    // if !selectAfterMove, keep the same tab selected as was selected before.

    if( selectAfterMove || index == self.selectedIndex )
    {
        self.selectedIndex = toPosition;
    }
    else if( index < self.selectedIndex && toPosition >= self.selectedIndex )
    {
        self.selectedIndex--;
    }
    else if( index > self.selectedIndex && toPosition <= self.selectedIndex )
    {
        self.selectedIndex = self.selectedIndex + 1;
    }

    NSDictionary* userinfo = @{ kTabDocumentKey : [self tabDocumentAtIndex: index], kTabDocumentIndexKey : @(index), kTabDocumentToIndexKey : @(toPosition) };
    [[NSNotificationCenter defaultCenter] postNotificationName: kTabDocumentDidMoveNotification object: nil userInfo: userinfo];
}

@end

#pragma mark - Notifications

// Keys for data in the userInfo dictionary

NSString* const kTabDocumentKey = @"kTabDocumentKey";
NSString* const kOldTabDocumentKey = @"kOldTabDocumentKey";
NSString* const kNewTabDocumentKey = @"kNewTabDocumentKey";
NSString* const kTabDocumentIndexKey = @"kTabDocumentIndexKey";
NSString* const kTabDocumentToIndexKey = @"kTabDocumentToIndexKey";
NSString* const kTabDocumentInForegroundKey = @"kTabDocumentInForegroundKey";

NSString* const kDidInsertTabDocumentNotification = @"kDidInsertTabDocumentNotification";
NSString* const kWillCloseTabDocumentNotification = @"kWillCloseTabDocumentNotification";
NSString* const kDidDetachTabDocumentNotification = @"kDidDetachTabDocumentNotification";
NSString* const kDidDeselectTabDocumentNotification = @"kDidDeselectTabDocumentNotification";
NSString* const kDidSelectTabDocumentNotification = @"kDidSelectTabDocumentNotification";
NSString* const kTabDocumentDidMoveNotification = @"kTabDocumentDidMoveNotification";
NSString* const kTabDocumentDidChangeNotification = @"kTabDocumentDidChangeNotification";
NSString* const kTabDocumentDidGetReplacedNotification = @"kTabDocumentDidGetReplacedNotification";
NSString* const kTabDocumentDidChangeBlockedStateNotification = @"kTabDocumentDidChangeBlockedStateNotification";
NSString* const kLastTabDidClose = @"kLastTabDidClose";
NSString* const kTabWellModelWillBeDeleted = @"kTabWellModelWillBeDeleted";
