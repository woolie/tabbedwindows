//
//  AVTTabbedWindows - AVTTabDocumentController.h
//
//  A class that controls the document of a tab. It manages displaying the native
//  view for a given AVTTabDocument in |documentContainer|.
//  Note that just creating the class does not display the view in
//  |documentContainer|. We defer inserting it until the box is the correct size
//  to avoid multiple resize messages to the renderer. You must call
//  |-ensureDocumentVisible| to display the render widget host view.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVTTabDocument;

@interface AVTTabDocumentController : NSViewController

// Create the contents of a tab represented by |contents| and loaded from the nib given by |name|.

- (id) initWithNibName: (NSString*) name bundle: (NSBundle*) bundle document: (AVTTabDocument*) document;

// Create the contents of a tab represented by |Document| and loaded from a nib called "TabDocument".
//
// Will first try to find a nib named "TabContents" in the main bundle. If the "TabDocument" nib could not be found in the main bulde it is loaded from the
// framework bundle.
//
// If you use a nib with another name you should override the implementation in your subclass and delegate the internal initialization to
// initWithNibName:bundle:document:

- (id) initWithDocument: (AVTTabDocument*) document;

// Returns YES if the tab represented by this controller is the front-most.

- (BOOL) isCurrentTab;

// Called when the tab contents is the currently selected tab and is about to be removed from the view hierarchy.

- (void) willResignSelectedTab;

// Called when the tab contents is about to be put into the view hierarchy as the selected tab.
// Handles things such as ensuring the toolbar is correctly enabled.

- (void) willBecomeSelectedTab;

// Call when the tab view is properly sized and the render widget host view should be put into the view hierarchy.

- (void) ensureContentsVisible;

// Called when the tab contents is updated in some non-descript way (the notification from the model isn't specific).
// |updatedDocument| could reflect an entirely new tab document object.

- (void) tabDidChange: (AVTTabDocument*) updatedDocument;

@property (nonatomic, assign) AVTTabDocument* document;
@property (nonatomic, retain) IBOutlet NSSplitView* contentsContainerView;

@end
