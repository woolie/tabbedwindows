//
//  AVTTabbedWindows - AVTTabWindowController.h
//
//  A view that handles the event tracking (clicking and dragging) for a tab
//  on the tab strip. Relies on an associated CTTabController to provide a
//  target/action for selecting the tab.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVTFastResizeView;
@class AVTTabView;
@class AVTTabWellView;

@interface AVTTabWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic, retain) IBOutlet AVTFastResizeView* tabContentArea;
@property (nonatomic, retain) IBOutlet AVTTabWellView* tabWellView;
@property (nonatomic, assign) BOOL didShowNewTabButtonBeforeTemporalAction;

// Used during tab dragging to turn on/off the overlay window when a tab
// is torn off. If -deferPerformClose (below) is used, -removeOverlay will
// cause the controller to be autoreleased before returning.

- (void) showOverlay;
- (void) removeOverlay;
@property (nonatomic, retain) NSWindow* overlayWindow;

// Returns YES if it is ok to constrain the window's frame to fit the screen.

- (BOOL) shouldConstrainFrameRect;

// A collection of methods, stubbed out in this base class, that provide
// the implementation of tab dragging based on whatever model is most
// appropriate.

// Layout the tabs based on the current ordering of the model.

- (void) layoutTabs;

// Creates a new window by pulling the given tab out and placing it in
// the new window. Returns the controller for the new window. The size of the
// new window will be the same size as this window.

- (AVTTabWindowController*) detachTabToNewWindow: (AVTTabView*) tabView;

// Make room in the tab strip for |tab| at the given x coordinate. Will hide the
// new tab button while there's a placeholder. Subclasses need to call the
// superclass implementation.

- (void) insertPlaceholderForTab: (AVTTabView*) tab frame: (NSRect) frame yStretchiness: (CGFloat) yStretchiness;

// Tells the tab strip to forget about this tab in preparation for it being put into a different tab strip, such as during a drop on another window.

- (void) detachTabView: (NSView*) view;

// Removes the placeholder installed by |-insertPlaceholderForTab:atLocation:| and restores the new tab button.
// Subclasses need to call the superclass implementation.

- (void) removePlaceholder;

// The follow return YES if tab dragging/tab tearing (off the tab strip)/window movement is currently allowed. Any number
// of things can choose to disable it, such as pending animations. The default implementations always return YES.
// Subclasses should override as appropriate.

- (BOOL) tabDraggingAllowed;
- (BOOL) tabTearingAllowed;
- (BOOL) windowMovementAllowed;

// Called when dragging of teared tab in an overlay window occurs

- (void) willStartTearingTab;
- (void) willEndTearingTab;
- (void) didEndTearingTab;

// Show or hide the new tab button. The button is hidden immediately, but waits until the next call to |-layoutTabs| to show it again.

@property (nonatomic, assign) BOOL showsAddTabButton;

// Returns whether or not |tab| can still be fully seen in the tab strip or if its current position would cause it be obscured by things
// such as the edge of the window or the window decorations. Returns YES only if the entire tab is visible.
// The default implementation always returns YES.

- (BOOL) isTabFullyVisible: (AVTTabView*) tab;

// Called to check if the receiver can receive dragged tabs from source.  Return YES if so.  The default implementation returns NO.

- (BOOL) canReceiveFrom: (id) controller;

// Move a given tab view to the location of the current placeholder. If there is no placeholder, it will go at the end.
// |controller| is the window controller of a tab being dropped from a different window. It will be nil if the drag is
// within the window, otherwise the tab is removed from that window before being placed into this one. The implementation
// will call |-removePlaceholder| since the drag is now complete.  This also calls |-layoutTabs| internally so clients do
// not need to call it again.

- (void) moveTabView: (NSView*) view fromController: (AVTTabWindowController*) controller;

// Number of tabs in the tab strip. Useful, for example, to know if we're dragging the only tab in the window. This includes
// pinned tabs (both live and not).

@property (nonatomic, assign) NSInteger numberOfTabs;

// YES if there are tabs in the tab strip which have content, allowing for the notion of tabs in the tab strip that are
// placeholders, or phantoms, but currently have no content.

@property (nonatomic, assign) BOOL hasLiveTabs;

// Return the view of the selected tab.

@property (nonatomic, readonly) NSView* selectedTabView;

// The title of the selected tab.

@property (nonatomic, readonly) NSString* selectedTabTitle;

// Called to check whether or not this controller's window has a tab strip (YES if it does, NO otherwise).
// The default implementation returns YES.

- (BOOL) hasTabWell;

// Get/set whether a particular tab is draggable between windows.

- (BOOL) isTabDraggable: (NSView*) tabView;
- (void) setTab: (NSView*) tabView isDraggable: (BOOL) draggable;

// Tell the window that it needs to call performClose: as soon as the current
// drag is complete. This prevents a window (and its overlay) from going away
// during a drag.

- (void) deferPerformClose;

// Called when the size of the window content area has changed. Override to position specific views.
// Base class implementation does nothing.

- (void) layoutSubviews;

@property (nonatomic, retain) NSMutableSet* lockedTabs;
@property (nonatomic, assign) NSView* cachedContentView;    // Weak: Used during dragging for identifying which view is the proper content area in the overlay

@property (nonatomic, assign) BOOL closeDeferred;  // If YES, call performClose: in removeOverlay:.

// Difference between height of window content area and height of the |tabContentArea|. Calculated when the window is loaded from the nib and
// cached in order to restore the delta when switching tab modes.

@property (nonatomic, assign) CGFloat contentAreaHeightDelta;

@end
