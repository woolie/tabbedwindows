//
//  AVTTabbedWindows - AVTTabDocument.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const AVTTabDocumentDidCloseNotification;

@class AVTContainer;
@class AVTTabDocument;
@class AVTTabWellModel;

@protocol AVTTabDocumentDelegate

- (BOOL) canReloadDocument: (AVTTabDocument*) document;
- (BOOL) reload; // should set contents.isLoading = YES

@end

@interface AVTTabDocument : NSDocument

// Initialize a new CTTabDocument object.
// The default implementation does nothing with |baseDocument| but subclasses
// can use |baseDocument| (the selected AVTTabDocument, if any) to perform
// customized initialization.

- (id) initWithBaseTabDocument: (AVTTabDocument*) baseDocument;

// Called when the tab should be destroyed (involves some finalization).

- (void) destroy: (AVTTabWellModel*) sender;

#pragma mark Actions

// Selects the tab in it's window and brings the window to front

- (IBAction) makeKeyAndOrderFront: (id) sender;

// Give first-responder status to self.view if isVisible

- (BOOL) becomeFirstResponder;

#pragma mark - Callbacks

// Called when this tab may be closing (unless AVTContainer respond no to canCloseTab).

- (void) closingOfTabDidStart: (AVTTabWellModel*) model;

// The following three callbacks are meant to be implemented by subclasses:
// Called when this tab was inserted into a container

- (void) tabDidInsertIntoContainer: (AVTContainer*) container atIndex: (NSInteger) index inForeground: (BOOL) foreground;

// Called when this tab replaced another tab

- (void) tabReplaced: (AVTTabDocument*) oldDocument inContainer: (AVTContainer*) container atIndex: (NSInteger) index;

// Called when this tab is about to close

- (void) tabWillCloseInContainer: (AVTContainer*) container atIndex: (NSInteger) index;

// Called when this tab was removed from a container

- (void) tabDidDetachFromContainer: (AVTContainer*) container atIndex: (NSInteger) index;

// The following callbacks called when the tab's visible state changes. If you
// override, be sure and invoke super's implementation. See "Visibility states"
// in the header of this file for details.

// Called when this tab become visible on screen. This is a good place to resume animations.

- (void) tabDidBecomeVisible;

// Called when this tab is no longer visible on screen. This is a good place to pause animations.

- (void) tabDidResignVisible;

// Called when this tab is about to become the selected tab. Followed by a call to |tabDidBecomeSelected|

- (void) tabWillBecomeSelected;

// Called when this tab is about to resign as the selected tab. Followed by a call to |tabDidResignSelected|

- (void) tabWillResignSelected;

// Called when this tab became the selected tab in its window. This does neccessarily not mean it's visible
// (app might be hidden or window might be minimized). The default implementation makes our view the first responder, if visible.

- (void) tabDidBecomeSelected;

// Called when another tab in our window "stole" the selection.

- (void) tabDidResignSelected;

// Called when this tab is about to being "teared" (when dragging a tab from one window to another).

- (void) tabWillBecomeTeared;

// Called when this tab is teared and is about to "land" into a window.

- (void) tabWillResignTeared;

// Called when this tab was teared and just landed in a window. The default implementation makes our view the first responder, restoring focus.

- (void) tabDidResignTeared;

// Called when the frame has changed, which isn't too often. There are at least two cases when it's called:
// - When the tab's view is first inserted into the view hiearchy
// - When a torn off tab is moves into a window with other dimensions than the initial window.

- (void) viewFrameDidChange: (NSRect) newFrame;

@property (nonatomic, assign) BOOL isApp;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isCrashed;
@property (nonatomic, assign) BOOL isWaitingForResponse;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, assign) BOOL isTeared;
@property (nonatomic, retain) NSObject<AVTTabDocumentDelegate>* delegate;
@property (nonatomic, assign) unsigned int closedByUserGesture;
@property (nonatomic, retain) IBOutlet NSView* view;
@property (nonatomic, retain) NSString* title;
@property (nonatomic, retain) NSImage* icon;
@property (nonatomic, assign) AVTContainer* container;
@property (nonatomic, assign) AVTTabDocument* parentOpener;

// If this returns true, special icons like throbbers and "crashed" is
// displayed, even if |icon| is nil. By default this returns true.

@property (nonatomic, readonly) BOOL hasIcon;

@end
