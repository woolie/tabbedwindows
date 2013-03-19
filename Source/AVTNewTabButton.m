//
//  AVTTabbedWindows - AVTNewTabButton.m
//
//  Copyright (c) 2010 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTNewTabButton.h"

@implementation AVTNewTabButton

// Approximate the shape. It doesn't need to be perfect. This will need to be updated if the size or shape of the icon ever changes.
// TODO(pinkerton): use a click mask image instead of hard-coding points.

- (NSBezierPath*) pathForButton
{
    if( self.imagePath == nil )
    {
        // Cache the path as it doesn't change (the coordinates are local to this view). There's not much point making constants for these,
        // as they are custom.

        self.imagePath = [NSBezierPath bezierPath];

        [self.imagePath moveToPoint: NSMakePoint(  9.0f,  7.0f )];
        [self.imagePath lineToPoint: NSMakePoint( 26.0f,  7.0f )];
        [self.imagePath lineToPoint: NSMakePoint( 33.0f, 23.0f )];
        [self.imagePath lineToPoint: NSMakePoint( 14.0f, 23.0f )];
        [self.imagePath lineToPoint: NSMakePoint(  9.0f,  7.0f )];
    }
    return self.imagePath;
}

- (BOOL) pointIsOverButton: (NSPoint) point
{
    NSPoint localPoint = [self convertPoint: point fromView: self.superview];
    return [self.pathForButton containsPoint: localPoint];
}

// Override to only accept clicks within the bounds of the defined path, not
// the entire bounding box. |aPoint| is in the superview's coordinate system.

- (NSView*) hitTest: (NSPoint) aPoint
{
    NSView* hitView = nil;

    if( [self pointIsOverButton: aPoint] )
        hitView = [super hitTest: aPoint];

    return hitView;
}

@end
