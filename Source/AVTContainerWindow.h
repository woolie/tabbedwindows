//
//  AVTTabbedWindows - AVTContainerWindow.h
//
//  Copyright (c) 2011 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/11/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Offset from the top of the window frame to the top of the window controls
// (zoom, close, miniaturize) for a window with a tabwell.

static const CGFloat kWindowButtonsWithTabWellOffsetFromTop = 11.0f;

// Offset from the top of the window frame to the top of the window controls
// (zoom, close, miniaturize) for a window without a tabwell.

static const CGFloat kWindowButtonsWithoutTabWellOffsetFromTop = 4.0f;

// Offset from the left of the window frame to the top of the window controls
// (zoom, close, miniaturize).

static const CGFloat kWindowButtonsWithTabOffsetFromLeft = 11.0f;
static const CGFloat kWindowButtonsWithoutTabOffsetFromLeft = 8.0f;

// Offset between the window controls (zoom, close, miniaturize).

static const CGFloat kWindowButtonsInterButtonSpacing = 7.0f;

@interface AVTContainerWindow : NSWindow

@property (nonatomic, assign) NSButton* closeButton;
@property (nonatomic, assign) NSButton* miniaturizeButton;
@property (nonatomic, assign) NSButton* zoomButton;
@property (nonatomic, assign) BOOL enteredControl;
@property (nonatomic, assign, getter=isTitleHidden) BOOL shouldHideTitle;
@property (nonatomic, assign) BOOL hasTabWell;
@property (nonatomic, assign) CGFloat windowButtonsInterButtonSpacing;

@end
