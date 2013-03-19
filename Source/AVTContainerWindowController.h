//
//  AVTTabbedWindows - AVTContainerWindowController.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/11/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AVTTabWindowController.h"

@interface NSDocumentController (CTBrowserWindowControllerAdditions)
- (id) openUntitledDocumentWithWindowController: (NSWindowController*) windowController
                                        display: (BOOL) display
                                          error: (NSError**) outError;
@end

@class AVTContainer;
@class AVTTabWellController;
@class AVTToolbarController;

@interface AVTContainerWindowController : AVTTabWindowController

+ (AVTContainerWindowController*) containerWindowController;
+ (AVTContainerWindowController*) mainContainerWindowController;
+ (AVTContainerWindowController*) containerWindowControllerForWindow: (NSWindow*) window;
+ (AVTContainerWindowController*) containerWindowControllerForView: (NSView*) view;

- (id) initWithWindowNibPath: (NSString*) windowNibPath container: (AVTContainer*) container;
- (id) initWithContainer: (AVTContainer*) container;

@property (nonatomic, readonly) AVTContainer* container;
@property (nonatomic, readonly) AVTTabWellController* tabWellController;
@property (nonatomic, readonly) AVTToolbarController* toolbarController;

@property (nonatomic, readonly) BOOL isFullscreen; // fullscreen or not

// Called to check whether or not this window has a toolbar. By default returns YES if toolbarController is not nil.

@property (nonatomic, readonly) BOOL hasToolbar;

@property (nonatomic, readonly) NSPoint themePatternPhase;
@property (nonatomic, readonly) BOOL hasTabWell;

// Returns YES if the user is allowed to drag tabs on the strip at this moment. For example, this returns NO if there are any pending tab close animtations.

@property (nonatomic, readonly) BOOL tabDraggingAllowed;

@end
