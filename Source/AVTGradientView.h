//
//  AVTTabbedWindows - AVTGradientView.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVTGradientView : NSView

// Draws the background for this view. Make sure that your patternphase
// is set up correctly in your graphics context before calling.

- (void) drawBackground;

// The color used for the bottom stroke. Public so subclasses can use.

@property (nonatomic, retain) NSColor* strokeColor;

// Controls whether the bar draws a dividing line at the bottom.

@property (nonatomic, assign) BOOL showsDivider;

@end
