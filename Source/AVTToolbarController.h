//
//  AVTTabbedWindows - AVTTabDocument.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <AppKit/AppKit.h>

@class AVTContainer;
@class AVTTabDocument;

// A controller for the toolbar in the container window.
//
// This class is meant to be subclassed -- the default implementation will load
// a placeholder/dummy nib. You need to do two things:
//
// 1. Create a new subclass of CTToolbarController.
//
// 2. Copy the Toolbar.xib into your project (or create a new) and modify it as
//    needed (add buttons etc). Make sure the "files owner" type matches your
//    CTToolbarController subclass.
//
// 3. Implement createToolbarController in your AVTContainer subclass to initialize
//    and return a CTToolbarController based on your nib.

@interface AVTToolbarController : NSViewController

- (id) initWithNibName: (NSString*) nibName bundle: (NSBundle*) bundle container: (AVTContainer*) container;

// Set the opacity of the divider (the line at the bottom) *if* we have a
// |ToolbarView| (0 means don't show it); no-op otherwise.

- (void) setDividerOpacity: (CGFloat) opacity;

// Called when the current tab is changing. Subclasses should implement this to
// update the toolbar's state.

- (void) updateToolbarWithDocument: (AVTTabDocument*) document shouldRestoreState: (BOOL) shouldRestore;

// Called by the Window delegate so we can provide a custom field editor if needed.
// Note that this may be called for objects unrelated to the toolbar.
// returns nil if we don't want to override the custom field editor for |obj|.
// The default implementation returns nil

- (id) customFieldEditorForObject: (id) obj;

@property (nonatomic, assign) AVTContainer* container;
@property (nonatomic, retain) NSTrackingArea* trackingArea;

@end
