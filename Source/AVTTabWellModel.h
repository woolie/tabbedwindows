//
//  AVTTabbedWindows - AVTTabWellModel.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    eTabChangeTypeLoadingOnly,      // Only the loading state changed.
    eTabChangeTypeTitleNotLoading,  // Only the title changed and page isn't loading.
    eTabChangeTypeAll               // Change not characterized by CTTabChangeTypeLoadingOnly or CTTabChangeTypeTitleNotLoading.

} AVTTabChangeType;

// Constants used when adding tabs.

typedef enum
{
    eAddNone          = 0,          // Used to indicate nothing special should happen to the newly inserted tab.
    eAddSelected      = 1 << 0,     // The tab should be selected.
    eAddPinned        = 1 << 1,     // The tab should be pinned.
    eAddForceIndex    = 1 << 2,     // If not set the insertion index of the AVTTabDocument is left up to the Order Controller associated
                                    // so the final insertion index may differ from the specified index. Otherwise the index supplied is used.
    eAddInheritGroup  = 1 << 3,     // If set the newly inserted tab inherits the group of the currently selected tab.
                                    // If not set the tab may still inherit the group under certain situations.
    eAddInheritOpener = 1 << 4,     // If set the newly inserted tab's opener is set to the currently selected tab.
                                    // If not set the tab may still inherit the group/opener under certain
                                    // situations. NOTE: this is ignored if eAddInheritGroup is set.

} AVTAddTabTypes;

typedef enum
{
    eInsertAfter,                   // Newly created tabs are created after the selection. This is the default.
    eInsertBefore                   // Newly created tabs are inserted before the selection.

} AVTInsertionPolicy;

// Context menu functions.

typedef enum
{
    eCommandFirst = 0,
    eCommandNewTab,
    eCommandReload,
    eCommandDuplicate,
    eCommandCloseTab,
    eCommandCloseOtherTabs,
    eCommandCloseTabsToRight,
    eCommandRestoreTab,
    eCommandTogglePinned,
    eCommandBookmarkAllTabs,
    eCommandLast

} AVTContextMenuCommand;

static const NSInteger kNoTab = -1;

#pragma mark - Notifications

// Keys for data in the userInfo dictionary

extern NSString* const kTabDocumentKey;
extern NSString* const kOldTabDocumentKey;
extern NSString* const kNewTabDocumentKey;
extern NSString* const kTabDocumentIndexKey;
extern NSString* const kTabDocumentToIndexKey;
extern NSString* const kTabDocumentInForegroundKey;

// A new AVTTabDocument was inserted into the TabWellModel at the specified index.
//|foreground| is whether or not it was opened in the foreground (selected).

extern NSString* const kDidInsertTabDocumentNotification;       // TabDocument, index inForeground

// The specified AVTTabDocument at |index| is being closed (and eventually destroyed).

extern NSString* const kWillCloseTabDocumentNotification;       // TabDocument, Index

// The specified AVTTabDocument at |index| is being detached, perhaps to be inserted in another TabWellModel.
// The implementer should take whatever action is necessary to deal with the AVTTabDocument no longer being present.

extern NSString* const kDidDetachTabDocumentNotification;       // TabDocument, Index

// The selected AVTTabDocument is about to change from |old_contents| at |index|. This gives observers a chance to prepare for an
// impending switch before it happens.

extern NSString* const kDidDeselectTabDocumentNotification;     // TabDocument, Index

// The selected AVTTabDocument changed from |old_contents| to |new_contents| at |index|.

//- (void) didSelectTabDocument: (AVTTabDocument*) newDocument atIndex: (NSInteger) index userInfo: (NSDictionary*) userInfo;

extern NSString* const kDidSelectTabDocumentNotification;       // new TabDocument, old TabDocument, index

// The specified AVTTabDocument at |from_index| was moved to |to_index|.

extern NSString* const kTabDocumentDidMoveNotification;         // TabDocument, fromIndex, toIndex

// The specified AVTTabDocument at |index| changed in some way. |contents| may be an entirely different object and the old value is no
// longer available by the time this message is delivered.
//
// See TabChangeType for a description of |change_type|.

extern NSString* const kTabDocumentDidChangeNotification;       // TabDocument, index, changeType

// The tab contents was replaced at the specified index. This is invoked when a tab becomes phantom. See description of phantom tabs in class description
// of TabWellModel for details.

extern NSString* const kTabDocumentDidGetReplacedNotification;  // oldDocument, newDocument;

// Invoked when the blocked state of a tab changes. NOTE: This is invoked when a tab becomes blocked/unblocked by a tab modal window.

extern NSString* const kTabDocumentDidChangeBlockedStateNotification;   // document, index;

// The implementer may use this as a trigger to try and close the window containing the TabWellModel, for example...

extern NSString* const kLastTabDidClose;

// Sent when the tabwell model is about to be deleted and any reference held must be dropped.

extern NSString* const kTabWellModelWillBeDeleted;

@class AVTTabDocument;
@class AVTTabWellModelOrderController;
@protocol AVTTabWellModelDelegate;

#pragma mark - AVTTabWellModel

@interface AVTTabWellModel : NSObject

- (id) initWithDelegate: (NSObject<AVTTabWellModelDelegate>*) delegate;
- (BOOL) isContextMenuCommand: (AVTContextMenuCommand) command enabledForContextIndex: (NSInteger) contextIndex;

// Determines if the specified index is contained within the TabWellModel.

- (BOOL) containsIndex: (NSInteger) index;

- (void) tabDocumentWasDestroyed: (AVTTabDocument*) document;

- (NSInteger) addTabDocument: (AVTTabDocument*) document atIndex: (NSInteger) index withAddTypes: (NSUInteger) add_types;

// Adds the specified AVTTabDocument at the specified location. |flags| is a bitmask of AVTAddTabTypes; see it for details.
//
// All append/insert methods end up in this method.
//
// NOTE: adding a tab using this method does NOT query the order controller, as such the eAddForceIndex AddType is meaningless here.
// The only time the |index| is changed is if using the index would result in breaking the constraint that all mini-tabs occur before non-mini-tabs.
// See also AddTabDocument.

- (void) insertTabDocument: (AVTTabDocument*) document atIndex: (NSInteger) index withFlags: (NSUInteger) flags;

// Adds the specified AVTTabDocument in the default location. Tabs opened in the foreground inherit the group of the previously selected tab.

- (void) appendTabDocument: (AVTTabDocument*) document inForeground: (BOOL) foreground;

// Closes the AVTTabDocument at the specified index. This causes the AVTTabDocument to be destroyed, but it may not happen immediately
// (e.g. if it's a AVTTabDocument). Returns true if the AVTTabDocument was closed immediately, false if it was not
// closed (we may be waiting for a response from an onunload handler, or waiting for the user to confirm closure).

- (void) closeTabDocumentAtIndex: (NSInteger) index;

- (void) closeAllTabs;

// Replaces the tab contents at |index| with |newDocument|. |type| is passed to the observer. This deletes the AVTTabDocument currently at |index|.

- (void) replaceTabDocument: (AVTTabDocument*) newDocument atIndex: (NSInteger) index;

// Detaches the AVTTabDocument at the specified index from this strip. The AVTTabDocument is not destroyed, just removed from display.
// The caller is responsible for doing something with it (e.g. stuffing it into another well).

- (AVTTabDocument*) detachTabDocumentAtIndex: (NSInteger) index;

// Forget all Opener relationships that are stored (but _not_ group relationships!) This is to reduce unpredictable tab switching behavior
// in complex session states. The exact circumstances under which this method is called are left up to the implementation of the selected
// AVTTabWellModelOrderController.

- (void) forgetAllOpeners;

// Returns the index of the specified AVTTabDocument, or kNoTab if the AVTTabDocument is not in this TabWellModel.

- (NSInteger) indexOfTabDocument: (AVTTabDocument*) document;
- (AVTTabDocument*) tabDocumentAtIndex: (NSInteger) index;

// Selects either the next tab (|foward| is true), or the previous tab (|forward| is false).

- (void) selectRelativeTabWithDirection: (BOOL) forward;

// Select the AVTTabDocument at the specified index.

- (void) selectTabDocumentAtIndex: (NSInteger) index;

// Move the AVTTabDocument at the specified index to another index. This method does NOT send Detached/Attached notifications, rather it
// moves the AVTTabDocument inline and sends a Moved notification instead. If |select_after_move| is false, whatever tab was selected before
// the move will still be selected, but it's index may have incremented or decremented one slot.
// NOTE: this does nothing if the move would result in app tabs and non-app tabs mixing.

- (void) closeSelectedTab;

// Select adjacent tabs

- (void) selectNextTab;
- (void) selectPreviousTab;

// Selects the last tab in the tab strip.

- (void) selectLastTab;

- (void) moveTabNext;
- (void) moveTabPrevious;

- (void) moveTabDocumentAtIndex: (NSInteger) index toIndex: (NSInteger) to_position selectAfterMove: (BOOL) select_after_move;

// Changes the pinned state of the tab at |index|. See description above class for details on this.

- (void) setTabPinnedForIndex: (NSInteger) index withState: (BOOL) pinned;

// Returns true if the tab at |index| is pinned. See description above class for details on pinned tabs.

- (BOOL) isTabPinnedForIndex: (NSInteger) index;

// Is the tab a mini-tab? See description above class for details on this.

- (BOOL) isMiniTabForIndex: (NSInteger) index;

// Is the tab at |index| an app? See description above class for details on app tabs.

- (BOOL) isAppTabForIndex: (NSInteger) index;

// Returns true if the tab at |index| is blocked by a tab modal dialog.

- (BOOL) isTabBlockedForIndex: (NSInteger) index;

- (NSInteger) constrainInsertionIndex: (NSInteger) index withMiniTab: (BOOL) mini_tab;

@property (nonatomic, assign) NSObject<AVTTabWellModelDelegate>* delegate;      // weak
@property (nonatomic, assign) AVTTabDocument* document;                         // weak
@property (nonatomic, assign) BOOL pinned;
@property (nonatomic, assign) BOOL modallyBlocked;

// The AVTTabDocument data currently hosted within this TabWellModel.

@property (nonatomic, retain) NSMutableArray* documentData;                     // Dictionary of document data. document, pinned, blocked are the keys

// The index of the AVTTabDocument in |document| that is currently selected.

@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, readonly) AVTTabDocument* selectedTabDocument;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSInteger indexOfFirstNonMiniTab;

// True if all tabs are currently being closed via CloseAllTabs.

@property (nonatomic, assign) BOOL closingAll;

// An object that determines where new Tabs should be inserted and where
// selection should move when a Tab is closed.

@property (nonatomic, retain) AVTTabWellModelOrderController* orderController;

// Our observers.

@property (nonatomic, retain) NSMutableArray* observers;

@end
