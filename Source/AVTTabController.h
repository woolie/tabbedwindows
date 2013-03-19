//
//  AVTTabbedWindows - AVTTabController.h
//
//  A class that manages a single tab in the tab strip. Set its target/action
//  to be sent a message when the tab is selected by the user clicking. Setting
//  the |loading| property to YES visually indicates that this tab is currently
//  loading content via a spinner.
//
//  The tab has the notion of an "icon view" which can be used to display
//  identifying characteristics such as a favicon, or since it's a full-fledged
//  view, something with state and animation such as a throbber for illustrating
//  progress. The default in the nib is an image view so nothing special is
//  required if that's all you need.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// The loading/waiting state of the tab.

typedef enum
{
    eTabLoadingStateDone,
    eTabLoadingStateLoading,
    eTabLoadingStateWaiting,
    eTabLoadingStateCrashed,

} AVTTabLoadingState;

@class AVTHoverCloseButton;
@class AVTTabView;

@interface AVTTabController : NSViewController

// Minimum and maximum allowable tab width. The minimum width does not show
// the icon or the close button. The selected tab always has at least a close
// button so it has a different minimum width.

+ (CGFloat) minTabWidth;
+ (CGFloat) maxTabWidth;
+ (CGFloat) minSelectedTabWidth;
+ (CGFloat) miniTabWidth;
+ (CGFloat) appTabWidth;

// Initialize a new controller. The default implementation will locate a nib
// called "TabView" in the app bundle and if not found there, will use the
// default nib from the framework bundle. If you need to rename the nib or load
// if from somepleace else, you should override this method and then call
// initWithNibName:bundle:.

// The view associated with this controller, pre-casted as a AVTTabView

@property (nonatomic, readonly) AVTTabView* tabView;

// Closes the associated AVTTabView by relaying the message to |target_| to
// perform the close.

- (IBAction) closeTab: (id) sender;

// Called by the tabs to determine whether we are in rapid (tab) closure mode.
// In this mode, we handle clicks slightly differently due to animation.
// Ideally, tabs would know about their own animation and wouldn't need this.

- (BOOL) inRapidClosureMode;

// Updates the visibility of certain subviews, such as the icon and close
// button, based on criteria such as the tab's selected state and its current
// width.

- (void) updateVisibility;

// Update the title color to match the tabs current state.

- (void) updateTitleColor;

// Replace the current icon view with the given view. |iconView| will be resized to the size of the current icon view.

@property (nonatomic, retain) NSView* iconView;
@property (nonatomic, retain) IBOutlet NSTextField* titleView;
@property (nonatomic, retain) IBOutlet AVTHoverCloseButton* closeButton;
@property (nonatomic, assign, getter=isIconShowing) BOOL iconShowing;
@property (nonatomic, assign) AVTTabLoadingState loadingState;

@property (nonatomic, assign) NSRect originalIconFrame;             // frame of iconView_ as loaded from nib
@property (nonatomic, assign) CGFloat iconTitleXOffset;             // between left edges of icon and title
@property (nonatomic, assign) CGFloat titleCloseWidthOffset;        // between right edges of icon and close button.

@property (nonatomic, assign) SEL action;
@property (nonatomic, assign) BOOL app;
@property (nonatomic, assign) BOOL mini;
@property (nonatomic, assign) BOOL phantom;
@property (nonatomic, assign) BOOL pinned;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) id target;

@end
