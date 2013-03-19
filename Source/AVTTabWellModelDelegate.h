//
//  AVTTabbedWindows - AVTTabWellModelDelegate.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

@class AVTContainer;
@class AVTTabDocument;

// Chromium-comment:
//
// A delegate interface that the AVTTabWellModel uses to perform work that it can't do itself, such as obtain a container for creating
// new AVTTabDocument, creating new TabWellModels for detached tabs, etc.
//
// This interface is typically implemented by the controller that instantiates the AVTTabWellModel (the AVTContainer object).

@protocol AVTTabWellModelDelegate

@optional
// Adds what the delegate considers to be a blank tab to the model.

- (AVTTabDocument*) addBlankTabInForeground: (BOOL) foreground;
- (AVTTabDocument*) addBlankTabAtIndex: (NSInteger) index inForeground: (BOOL) foreground;

// Asks for a new TabWellModel to be created and the given tab document to be added to it. Its size and position are reflected in |window_bounds|.
// If |dock_info|'s type is other than NONE, the newly created window should be docked as identified by |dock_info|. Returns the AVTContainer object
// representing the newly created window and tab strip. This does not show the window, it's up to the caller to do so.

- (AVTContainer*) createNewStripWithDocument: (AVTTabDocument*) document;

// Creates a new AVTContainer object and window containing the specified |document|, and continues a drag operation that began within the source
// window's tab strip. |window_bounds| are the bounds of the source window in screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates, used to place the new Tab in the new window.

- (void) continueDraggingDetachedTab: (AVTTabDocument*) document windowBounds: (NSRect) windowBounds tabBounds: (NSRect) tabBounds;

// Returns whether some document can be duplicated.

- (BOOL) canDuplicateDocumentAtIndex: (NSInteger) index;

// Duplicates the document at the provided index and places it into its own window.

- (void) duplicateDocumentAtIndex: (NSInteger) index;

// Called when a drag session has completed and the frame that initiated the the session should be closed.

- (void) closeFrameAfterDragSession;

// Runs any unload listeners associated with the specified AVTTabDocument before it is closed. If there are unload listeners that need to be run,
// this function returns true and the TabWellModel will wait before closing the AVTTabDocument. If it returns false, there are no unload listeners
// and the TabWellModel can close the AVTTabDocument immediately.

- (BOOL) runUnloadListenerBeforeClosing: (AVTTabDocument*) document;

// Returns true if a tab can be restored.

- (BOOL) canRestoreTab;

// Restores the last closed tab if CanRestoreTab would return true.

- (void) restoreTab;

// Returns whether some document can be closed.

- (BOOL) canCloseDocumentAtIndex: (NSInteger) index;

// Returns true if any of the tabs can be closed.

- (BOOL) canCloseTab;

@end
