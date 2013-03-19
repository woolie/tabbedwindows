//
//  AVTTabbedWindows - AVTToolbarView.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AVTGradientView.h"

// A view that handles any special rendering of the toolbar bar. At this time it
// simply draws a gradient and an optional divider at the bottom.

@interface AVTToolbarView : AVTGradientView

@property(nonatomic, assign) CGFloat dividerOpacity;

@end
