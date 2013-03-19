//
//  AVTTabbedWindows - AVTContainer.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTTabWellModelDelegate.h"

typedef enum
{
    eWindowOpenDispositionCurrentTab,
    eWindowOpenDispositionNewForegroundTab,
    eWindowOpenDispositionNewBackgroundTab

} AVTWindowOpenDisposition;

@class AVTContainerWindowController;
@class AVTTabDocument;
@class AVTTabWellModel;
@class AVTToolbarController;
@class AVTTabDocumentController;

// There is one AVTContainer instance per perceived window.
// A AVTContainer instance has one TabWellModel.

@interface AVTContainer : NSObject<AVTTabWellModelDelegate>

+ (AVTContainer*) container;

// Create a new toolbar controller. The default implementation will create a controller loaded with a nib called "Toolbar".
// If the nib can't be found in the main bundle, a fallback nib will be loaded from the framework.
// Returning nil means there is no toolbar.

- (AVTToolbarController*) createToolbarController;

// Create a new tab document controller. Override this to provide a custom
// AVTTabDocumentController subclass.

-  (AVTTabDocumentController*) createTabDocumentControllerWithDocument: (AVTTabDocument*) document;

// Create a new default/blank AVTTabDocument.
// |baseDocument| represents the AVTTabDocument which is currently in the foreground. It might be nil.
// Subclasses could override this to provide a custom AVTTabDocument type.

- (AVTTabDocument*) newBlankTabBasedOn: (AVTTabDocument*) baseDocument;

// Add blank tab

- (AVTTabDocument*) addBlankTabAtIndex: (NSInteger) index inForeground: (BOOL) foreground;
- (AVTTabDocument*) addBlankTabInForeground: (BOOL) foreground;
- (AVTTabDocument*) addBlankTab;

// Add tab with document

- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document atIndex: (NSInteger) index inForeground: (BOOL) foreground;
- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document inForeground: (BOOL) foreground;
- (AVTTabDocument*) addTabDocument: (AVTTabDocument*) document;

// Commands

- (void) newWindow;
- (void) closeWindow;
- (void) closeTab;
- (void) selectNextTab;
- (void) selectPreviousTab;
- (void) moveTabNext;
- (void) moveTabPrevious;
- (void) selectTabAtIndex: (NSInteger) index;
- (void) selectLastTab;
- (void) duplicateTab;

- (void) executeCommand: (NSUInteger) cmd withDisposition: (AVTWindowOpenDisposition) disposition;
- (void) executeCommand: (NSUInteger) cmd;

// Execute a command which does not need to have a valid container. This can be used in application delegates or other
// document tab windows which are first responders. Like this:
//
// - (void) commandDispatch: (id) sender
// {
//     [MyContainer executeCommand: [sender tag]];
// }

+ (void) executeCommand: (NSUInteger) cmd;

- (void) loadingStateDidChange: (AVTTabDocument*) document;
- (void) windowDidBeginToClose;

// Convenience helpers (proxy for TabWellModel)

- (NSUInteger) tabCount;
- (NSInteger) selectedTabIndex;
- (AVTTabDocument*) selectedTabDocument;
- (AVTTabDocument*) tabDocumentAtIndex: (NSInteger) index;
- (NSArray*) allTabDocuments;
- (NSInteger) indexOfTabDocument: (AVTTabDocument*) document; // -1 if not found
- (void) selectTabDocumentAtIndex: (NSInteger) index userGesture: (BOOL) userGesture;
- (void) updateTabStateAtIndex: (NSInteger) index;
- (void) updateTabStateForContent: (AVTTabDocument*) document;
- (void) replaceTabDocumentAtIndex: (NSInteger) index withTabDocument: (AVTTabDocument*) document;
- (void) closeTabAtIndex: (NSInteger) index makeHistory: (BOOL) makeHistory;
- (void) closeAllTabs;

@property (nonatomic, readonly) AVTTabWellModel* tabWellModel;
@property (nonatomic, retain) AVTContainerWindowController* windowController;
@property (nonatomic, readonly) NSWindow* window;

@end
