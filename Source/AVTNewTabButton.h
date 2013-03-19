//
//  AVTTabbedWindows - AVTNewTabButton.h
//
//  Copyright (c) 2010 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Overrides hit-test behavior to only accept clicks inside the image of the button, not just inside the bounding box.
// This could be abstracted to general use, but no other buttons are so irregularly shaped with respect to their bounding box.

@interface AVTNewTabButton : NSButton

// Returns YES if the given point is over the button.  |point| is in the superview's coordinate system.

- (BOOL) pointIsOverButton: (NSPoint) point;

@property (nonatomic, retain) NSBezierPath* imagePath;

@end
