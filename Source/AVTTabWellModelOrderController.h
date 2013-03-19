//
//  AVTTabbedWindows - AVTTabWellModelOrderController.h
//
//  An object that allows different types of ordering and reselection to be
//  heuristics plugged into a TabWellModel
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 02/04/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTTabWellModel.h"

@class AVTTabDocument;

@interface AVTTabWellModelOrderController : NSObject

- (id) initWithTabWellModel: (AVTTabWellModel*) model;

// Determine where to place a newly opened tab by using the supplied transition and foreground flag to figure out how it was opened.

- (NSInteger) determineInsertionIndexForTabDocument: (AVTTabDocument*) newDocument inForeground: (BOOL) foreground;

// Returns the index to append tabs at.

- (NSInteger) determineInsertionIndexForAppending;

// Determine where to shift selection after a tab is closed is made phantom. If |is_remove| is false, the tab is not being removed but rather made
// phantom (see description of phantom tabs in TabWellModel).

- (NSInteger) determineNewSelectedIndexWithRemovingIndex: (NSInteger) removingIndex isRemove: (BOOL) isRemove;

@property (nonatomic, retain) AVTTabWellModel* model;
@property (nonatomic, assign) AVTInsertionPolicy insertionPolicy;

@end
