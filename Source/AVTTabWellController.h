//
//  AVTTabbedWindows - AVTTabWellController.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTWindowSheetController.h"

#pragma mark - Constants

// A value to indicate tab layout should use the full available width of the view.

static const CGFloat kUseFullAvailableWidth = -1.0f;

// The amount by which tabs overlap.

static const CGFloat kTabOverlap = 20.0f;

// The width and height for a tab's icon.

static const CGFloat kIconWidthAndHeight = 16.0f;

// The amount by which the new tab button is offset (from the tabs).

static const CGFloat kAddTabButtonOffset = 8.0f;

// Time (in seconds) in which tabs animate to their final position.

static const NSTimeInterval kAnimationDuration = 0.125;

#pragma mark -

@class AVTContainer;
@class AVTFastResizeView;
@class AVTNewTabButton;
@class AVTTabDocument;
@class AVTTabView;
@class AVTTabWellModel;
@class AVTTabWellView;

#pragma mark -

@interface AVTTabWellController : NSObject<AVTWindowSheetControllerDelegate>

+ (CGFloat) defaultTabHeight;

// Default indentation for tabs (see |indentForControls|).

+ (CGFloat) defaultIndentForControls;

- (id) initWithView: (AVTTabWellView*) tabWellView switchView: (AVTFastResizeView*) switchView container: (AVTContainer*) container;

// Return the view for the currently selected tab.

- (NSView*) selectedTabView;

// Set the frame of the selected tab, also updates the internal frame dict.

- (void) setFrameOfSelectedTab: (NSRect) frame;

// Move the given tab at index |from| in this window to the location of the current placeholder.

- (void) moveTabFromIndex: (NSInteger) from;

// Drop a given AVTTabDocument at the location of the current placeholder. If there is no placeholder, it will go at the end.
// Used when dragging from another window when we don't have access to the AVTTabDocument as part of our strip.
// |frame| is in the coordinate system of the tab strip view and represents where the user dropped the new tab so it can be
// animated into its correct location when the tab is added to the model. If the tab was pinned in its previous window,
// setting |pinned| to YES will propagate that state to the new window. Mini-tabs are either app or pinned tabs; the app
// state is stored by the |document|, but the |pinned| state is the caller's responsibility.

- (void) dropTabDocument: (AVTTabDocument*) contents withFrame: (NSRect) frame asPinnedTab: (BOOL) pinned;

// Returns the index of the subview |view|. Returns -1 if not present. Takes closing tabs into account such that this index will
// correctly match the tab model. If |view| is in the process of closing, returns -1, as closing tabs are no longer in the model.

- (NSInteger) modelIndexForTabView: (NSView*) view;

// Return the view at a given index.

- (NSView*) viewAtIndex: (NSInteger) index;

// Set the placeholder for a dragged tab, allowing the |frame| and |strechiness| to be specified. This causes this tab to be rendered in an arbitrary position

- (void) insertPlaceholderForTab: (AVTTabView*) tab frame: (NSRect) frame yStretchiness: (CGFloat) yStretchiness;

// Are we in rapid (tab) closure mode? I.e., is a full layout deferred (while the user closes tabs)? Needed to overcome missing
// clicks during rapid tab closure.

- (BOOL) inRapidClosureMode;

// Returns YES if the user is allowed to drag tabs on the strip at this moment. For example, this returns NO if there are any pending tab close animtations.

@property (nonatomic, readonly) BOOL tabDraggingAllowed;

// When we're told to layout from the public API we usually want to animate, except when it's the first time.

- (void) layoutTabs;

@property (nonatomic, assign) AVTTabWellView* tabWellView;          // Weak
@property (nonatomic, assign) AVTFastResizeView* switchView;        // Weak
@property (nonatomic, assign) AVTContainer* container;              // Weak
@property (nonatomic, assign) AVTTabWellModel* tabWellModel;        // Weak

// YES if the new tab button is currently displaying the hover image (if the mouse is currently over the button).

@property (nonatomic, assign) BOOL addTabButtonShowingHoverImage;

@property (nonatomic, retain) NSView* dragBlockingView;             // Avoid bad window server drags.

// Access to the TabContentsControllers (which own the parent view for the toolbar and associated tab contents) given an index.
// Call |indexFromModelIndex:| to convert a |tabWellModel| index to a |tabDocumentArray| index. Do NOT assume that the indices of
// |tabWellModel| and this array are identical, this is e.g. not true while tabs are animating closed (closed tabs are removed
// from |tabWellModel| immediately, but from |tabDocumentArray| only after their close animation has completed).

@property (nonatomic, retain) NSMutableArray* tabDocumentArray;

// An array of TabControllers which manage the actual tab views. See note above |tabDocumentArray|. |tabDocumentArray| and
// |tabArray| always contain objects belonging to the same tabs at the same indices.

@property (nonatomic, retain) NSMutableArray* tabArray;

// Set of TabControllers that are currently animating closed.

@property (nonatomic, retain) NSMutableSet* closingControllers;

@property (nonatomic, retain) AVTNewTabButton* addTabButton;
@property (nonatomic, retain) NSTrackingArea* addTabTrackingArea;

@property (nonatomic, assign) AVTTabView* placeholderTab;           // Weak. Tab being dragged
@property (nonatomic, assign) NSRect placeholderFrame;              // Frame to use
@property (nonatomic, assign) CGFloat placeholderStretchiness;      // Vertical force shown by stretching tab.
@property (nonatomic, assign) NSRect droppedTabFrame;               // Initial frame of a dropped tab, for animation.

// Show or hide the new tab button. The button is hidden immediately, but waits until the next call to |-layoutTabs| to show it again.

@property (nonatomic, assign) BOOL showsAddTabButton;

// Width available for resizing the tabs (doesn't include the new tab button). Used to restrict the available width when
// closing many tabs at once to prevent them from resizing to fit the full width. If the entire width should be used,
// this will have a value of |kUseFullAvailableWidth|.

@property (nonatomic, assign) CGFloat availableResizeWidth;

// A tracking area that's the size of the tab strip used to be notified when the mouse moves in the tab strip

@property (nonatomic, retain) NSTrackingArea* trackingArea;
@property (nonatomic, assign) AVTTabView* hoveredTab;               // Weak. Tab that the mouse is hovering over

// Array of subviews which are permanent (and which should never be removed),
// such as the new-tab button, but *not* the tabs themselves.

@property (nonatomic, retain) NSMutableArray* permanentSubviews;

// The amount by which to indent the tabs on the left (to make room for the red/yellow/green buttons).

@property (nonatomic, assign) CGFloat indentForControls;

// Is the mouse currently inside the well;

@property (nonatomic, assign) BOOL mouseInside;

// The default favicon, so we can use one copy for all buttons.

@property (nonatomic, retain) NSImage* defaultIcon;

// Manages per-tab sheets.

@property (nonatomic, retain) AVTWindowSheetController* sheetController;

@end
