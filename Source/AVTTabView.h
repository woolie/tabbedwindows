//
//  AVTTabbedWindows - AVTTabWindowController.h
//
//  A view that handles the event tracking (clicking and dragging) for a tab
//  on the tab strip. Relies on an associated CTTabController to provide a
//  target/action for selecting the tab.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTGradientView.h"

typedef enum
{
    eAlertNone,
    eAlertRising,
    eAlertHolding,
    eAlertFalling
} AlertState;

@class AVTHoverCloseButton;
@class AVTTabController;
@class AVTTabWindowController;

@interface AVTTabView : AVTGradientView

// Begin showing an "alert" glow (shown to call attention to an unselected pinned tab whose title changed).

- (void) startAlert;

// Stop showing the "alert" glow; this won't immediately wipe out any glow, but will make it fade away.

- (void) cancelAlert;

- (void) setTrackingEnabled: (BOOL) enabled;

@property (nonatomic, assign) IBOutlet AVTTabController* tabController;
@property (nonatomic, retain) IBOutlet AVTHoverCloseButton* closeButton;
@property (nonatomic, retain) NSTrackingArea* closeTrackingArea;

@property (nonatomic, assign, getter=isMouseInside) BOOL mouseInside;   // Is the mouse hovering over the tab?
@property (nonatomic, assign) NSPoint hoverPoint;                       // Current location of hover in view coords.
@property (nonatomic, assign) CGFloat hoverAlpha;                       // How strong the hover glow is.
@property (nonatomic, assign) NSTimeInterval hoverHoldEndTime;          // When the hover glow will begin dimming.

@property (nonatomic, assign) AlertState alertState;
@property (nonatomic, assign) CGFloat alertAlpha;                       // How strong the alert glow is.
@property (nonatomic, assign) NSTimeInterval alertHoldEndTime;          // When the hover glow will begin dimming.

@property (nonatomic, assign) NSTimeInterval lastGlowUpdate;            // Time either glow was last updated.

// All following variables are valid for the duration of a drag.
// These are released on mouseUp:

@property (nonatomic, assign) BOOL moveWindowOnDrag;                    // Set if the only tab of a window is dragged.
@property (nonatomic, assign) BOOL tabWasDragged;                       // Has the tab been dragged?
@property (nonatomic, assign) BOOL draggingWithinTabWell;               // Did drag stay in the current tab well?
@property (nonatomic, assign) BOOL chromeIsVisible;

@property (nonatomic, assign) NSTimeInterval tearTime;                  // Time since tear happened
@property (nonatomic, assign) NSPoint tearOrigin;                       // Origin of the tear rect
@property (nonatomic, assign) NSPoint dragOrigin;                       // Origin point of the drag
@property (nonatomic, assign) AVTTabWindowController* sourceController; // weak. controller starting the drag
@property (nonatomic, assign) NSWindow* sourceWindow;                   // weak. The window starting the drag
@property (nonatomic, assign) NSRect sourceWindowFrame;
@property (nonatomic, assign) NSRect sourceTabFrame;

@property (nonatomic, assign) AVTTabWindowController* draggedController;// weak. Controller being dragged.
@property (nonatomic, assign) NSWindow* dragWindow;                     // weak. The window being dragged
@property (nonatomic, assign) NSWindow* dragOverlay;                    // weak. The overlay being dragged

@property (nonatomic, assign) AVTTabWindowController* targetController; // weak. Controller being targeted

@property (nonatomic, assign) NSCellStateValue state;

// Determines if the tab is in the process of animating closed. It may still be visible on-screen, but should not respond to/initiate
// any events. Upon setting to NO, clears the target/action of the close button to prevent clicks inside it from sending messages.

@property (assign, nonatomic, getter=isClosing) BOOL closing;

@end
