//
//  AVTTabbedWindows - AVTHoverCloseButton.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTHoverButton.h"

@interface AVTHoverCloseButton : AVTHoverButton

// Bezier path for drawing the 'x' within the button.

@property (nonatomic, retain) NSBezierPath* xPath;

// Bezier path for drawing the hover state circle behind the 'x'.

@property (nonatomic, retain) NSBezierPath* circlePath;

@end
