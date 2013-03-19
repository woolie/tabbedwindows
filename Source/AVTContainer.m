//
//  AVTTabbedWindows - AVTContainer.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTContainer.h"

#import "AVTContainerCommands.h"
#import "AVTContainerWindowController.h"
#import "AVTTabDocument.h"
#import "AVTTabDocumentController.h"
#import "AVTTabWellModel.h"
#import "AVTToolbarController.h"

@implementation AVTContainer

+ (AVTContainer*) container
{
    return [[[[self class] alloc] init] autorelease];
}

- (id) init
{
    self = [super init];
    if( self != nil )
    {
        _tabWellModel = [[AVTTabWellModel alloc] initWithDelegate: self];
    }
    return self;
}

- (void) dealloc
{
    [_tabWellModel release];
    [_windowController release];

    [super dealloc];
}

// Create a new toolbar controller. The default implementation will create a controller loaded with a nib called "Toolbar".
// If the nib can't be found in the main bundle, a fallback nib will be loaded from the framework.
// Returning nil means there is no toolbar.

- (AVTToolbarController*) createToolbarController
{
	NSBundle* bundle = [NSBundle bundleForClass: [AVTContainer class]];
    if( bundle == nil )
    {
        bundle = [NSBundle mainBundle];
    }

    return [[[AVTToolbarController alloc] initWithNibName: @"Toolbar"
                                                   bundle: bundle
                                                container: self] autorelease];
}

// Create a new tab document controller. Override this to provide a custom AVTTabDocumentController subclass.

-  (AVTTabDocumentController*) createTabDocumentControllerWithDocument: (AVTTabDocument*) document
{
    AVTTabDocumentController* controller = [[[AVTTabDocumentController alloc] initWithDocument: document] autorelease];
    return controller;
}

// Create a new default/blank AVTTabDocument. |baseDocument| represents the AVTTabDocument which is currently in the
// foreground. It might be nil. Subclasses could override this to provide a custom AVTTabDocument type.

- (AVTTabDocument*) newBlankTabBasedOn: (AVTTabDocument*) baseDocument
{
    // Subclasses should override this to provide a custom AVTTabDocument type and/or initialization

    return [[AVTTabDocument alloc] initWithBaseTabDocument: baseDocument];
}

// Add blank tab

- (AVTTabDocument*) addBlankTabAtIndex: (NSInteger) index
                          inForeground: (BOOL) foreground
{
    AVTTabDocument* baseDocument = [self.tabWellModel selectedTabDocument];
    AVTTabDocument* document = [self newBlankTabBasedOn: baseDocument];
    return [self addTabDocument: document atIndex: index inForeground: foreground];
}

- (AVTTabDocument*) addBlankTabInForeground: (BOOL) foreground
{
    return [self addBlankTabAtIndex: -1 inForeground: foreground];
}

- (AVTTabDocument*) addBlankTab
{
    return [self addBlankTabInForeground: YES];
}

// Add tab with document

- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document
                           atIndex: (NSInteger) index
                      inForeground: (BOOL) foreground
{
    NSUInteger addTypes = foreground ? (eAddSelected | eAddInheritGroup) : eAddNone;
    (void)[self.tabWellModel addTabDocument: document atIndex: index withAddTypes: addTypes];

    if( (addTypes & eAddSelected ) == 0 )
    {
        // [TabWellModel addTabDocument] invokes HideContents if not foreground.

        document.isVisible = NO;
    }

    return document;
}

- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document
                      inForeground: (BOOL) foreground
{
    return [self addTabDocument: document atIndex: -1 inForeground: foreground];
}

- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document
{
    return [self addTabDocument: document atIndex: -1 inForeground: YES];
}

#pragma mark - Commands

- (void) newWindow
{
    // Create a new container & window when we start.

    Class windowControllerClass = self.windowController ? [self.windowController class] : [AVTContainerWindowController class];
    AVTContainer* container = [isa container];
    AVTContainerWindowController* windowController = [[windowControllerClass alloc] initWithContainer: container];
    [container addBlankTabInForeground: YES];
    [windowController showWindow: self];
    [windowController autorelease];
}

- (void) closeWindow
{
    [self.windowController close];
}

- (void) closeTab
{
    if( [self canCloseTab] )
    {
        [self.tabWellModel closeTabDocumentAtIndex: self.tabWellModel.selectedIndex];
    }
}

- (void) selectNextTab
{
    [self.tabWellModel selectNextTab];
}

- (void) selectPreviousTab
{
    [self.tabWellModel selectPreviousTab];
}

- (void) selectLastTab
{
    [self.tabWellModel selectLastTab];
}

- (void) moveTabNext
{
    [self.tabWellModel moveTabNext];
}

- (void) moveTabPrevious
{
    [self.tabWellModel moveTabPrevious];
}

- (void) selectTabAtIndex: (NSInteger) index
{
    if( index < self.tabWellModel.count )
    {
        [self.tabWellModel selectTabDocumentAtIndex: index];
    }
}

- (void) duplicateTab
{
    NSAssert( NO, @"Not implemented yet." );
}

#pragma mark - Convenience helpers (proxy for TabWellModel)

- (NSUInteger) tabCount
{
    return self.tabWellModel.count;
}

- (NSInteger) selectedTabIndex
{
    return self.tabWellModel.selectedIndex;
}

- (AVTTabDocument*) selectedTabDocument
{
    return [self.tabWellModel selectedTabDocument];
}

- (AVTTabDocument*) tabDocumentAtIndex: (NSInteger) index
{
    return [self.tabWellModel tabDocumentAtIndex: index];
}

- (NSArray*) allTabDocuments
{
    NSUInteger count = self.tabWellModel.count;
    NSMutableArray* documents = [NSMutableArray arrayWithCapacity: count];
    for( NSUInteger index = 0; index < count; ++index )
    {
        [documents addObject: [self.tabWellModel tabDocumentAtIndex: index]];
    }

    return documents;
}

- (NSInteger) indexOfTabDocument: (AVTTabDocument*) document
{
    return [self.tabWellModel indexOfTabDocument: document];
}

- (void) selectTabDocumentAtIndex: (NSInteger) index
                      userGesture: (BOOL) userGesture
{
    [self.tabWellModel selectTabDocumentAtIndex: index];
}

- (void) updateTabStateAtIndex: (NSInteger) index
{
    NSAssert( NO, @"Not implemented yet." );
}

- (void) updateTabStateForContent: (AVTTabDocument*) document
{
    NSAssert( NO, @"Not implemented yet." );
}

- (void) replaceTabDocumentAtIndex: (NSInteger) index
                   withTabDocument: (AVTTabDocument*) document
{
    NSAssert( NO, @"Not implemented yet." );
}

- (void) closeTabAtIndex: (NSInteger) index
             makeHistory: (BOOL) makeHistory
{
    [self.tabWellModel closeTabDocumentAtIndex: index];
}

- (void) closeAllTabs
{
    [self.tabWellModel closeAllTabs];
}

- (void) executeCommand: (NSUInteger) cmd
        withDisposition: (AVTWindowOpenDisposition) disposition
{
    // No commands are enabled if there is not yet any selected tab.
    // TODO(pkasting): It seems like we should not need this, because either
    // most/all commands should not have been enabled yet anyway or the ones that
    // are enabled should be global, or safe themselves against having no selected
    // tab.  However, Ben says he tried removing this before and got lots of
    // crashes, e.g. from Windows sending WM_COMMANDs at random times during
    // window construction.  This probably could use closer examination someday.

    if( [self selectedTabDocument] )
    {
        // The order of commands in this switch statement must match the function declaration order in AVTContainerCommands.h

        switch( cmd )
        {
            // Window management commands
            case eContainerCommandNewWindow:            [self newWindow];           break;
            case eContainerCommandCloseWindow:          [self closeWindow];         break;

            case eContainerCommandNewTab:               [self addBlankTab];         break;
            case eContainerCommandCloseTab:             [self closeTab];            break;
            case eContainerCommandSelectNextTab:        [self selectNextTab];       break;
            case eContainerCommandSelectPreviousTab:    [self selectPreviousTab];   break;

            case eContainerCommandSelectTab0:
            case eContainerCommandSelectTab1:
            case eContainerCommandSelectTab2:
            case eContainerCommandSelectTab3:
            case eContainerCommandSelectTab4:
            case eContainerCommandSelectTab5:
            case eContainerCommandSelectTab6:
            case eContainerCommandSelectTab7:
            {
                [self selectTabAtIndex: cmd - eContainerCommandSelectTab0];
                break;
            }

            case eContainerCommandSelectLastTab:        [self selectLastTab];       break;
            case eContainerCommandDuplicateTab:         [self duplicateTab];        break;
            case eContainerCommandExit:                 [NSApp terminate: self];    break;
            case eContainerCommandMoveTabNext:          [self moveTabNext];         break;
            case eContainerCommandMoveTabPrevious:      [self moveTabPrevious];     break;
        }
    }
}

- (void) executeCommand: (NSUInteger) cmd
{
    [self executeCommand: cmd withDisposition: eWindowOpenDispositionCurrentTab];
}

+ (void) executeCommand: (NSUInteger) cmd
{
    switch( cmd )
    {
        case eContainerCommandExit:
        {
            [NSApp terminate: self];
            break;
        }
    }
}

- (void) loadingStateDidChange: (AVTTabDocument*) document
{
    // TODO: Make sure the loading state is updated correctly
}

- (void) windowDidBeginToClose
{
    [self.tabWellModel closeAllTabs];
}

#pragma mark - TabWellModelDelegate

- (AVTContainer*) createNewStripWithDocument: (AVTTabDocument*) document
{
    AVTContainer* container = [isa container];
    [container.tabWellModel appendTabDocument: document inForeground: YES];
    [container loadingStateDidChange: document];
    return container;
}

// Creates a new AVTContainer object and window containing the specified |document|, and continues a drag operation that began within the source
// window's tab well. |window_bounds| are the bounds of the source window in screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates, used to place the new Tab in the new window.

- (void) continueDraggingDetachedTab: (AVTTabDocument*) contents
                        windowBounds: (NSRect) windowBounds
                           tabBounds: (NSRect) tabBounds
{
    NSAssert( NO, @"Not implemented" );
}

// Returns whether some contents can be duplicated.

- (BOOL) canDuplicateDocumentAtIndex: (NSInteger) index
{
    return NO;
}

// Duplicates the contents at the provided index and places it into its own window.

- (void) duplicateDocumentAtIndex: (NSInteger) index
{
    NSAssert( NO, @"Not implemented" );
}

// Called when a drag session has completed and the frame that initiated the the session should be closed.

- (void) closeFrameAfterDragSession
{
    NSLog( @"[TabbedWindows] closeFrameAfterDragSession" );
}

// Runs any unload listeners associated with the specified CTTabContents before it is closed. If there are unload listeners
// that need to be run, this function returns true and the TabWellModel will wait before closing the AVTTabDocument.
// If it returns false, there are no unload listeners and the TabWellModel can close the AVTTabDocument immediately.

- (BOOL) runUnloadListenerBeforeClosing: (AVTTabDocument*) document
{
    return NO;
}

// Returns true if a tab can be restored.

- (BOOL) canRestoreTab
{
    return NO;
}

// Restores the last closed tab if CanRestoreTab would return true.

- (void) restoreTab
{
}

// Returns whether some contents can be closed.

- (BOOL) canCloseDocumentAtIndex: (NSInteger) index
{
    return YES;
}

// Returns true if any of the tabs can be closed.

- (BOOL) canCloseTab
{
    return YES;
}

@end
