//
//  AVTTabbedWindows - AVTFastResizeView.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTFastResizeView.h"

@interface AVTFastResizeView()
- (void) layoutSubviews;
@end

@implementation AVTFastResizeView

- (void) setFastResizeMode: (BOOL) fastResizeMode
{
    if( _fastResizeMode != fastResizeMode )
    {
        _fastResizeMode = fastResizeMode;

        // Force a relayout when coming out of fast resize mode.

        if( !_fastResizeMode )
            [self layoutSubviews];
    }
}

- (void) resizeSubviewsWithOldSize: (NSSize) oldSize
{
    [self layoutSubviews];
}

- (void) drawRect: (NSRect) dirtyRect
{
    // If we are in fast resize mode, our subviews may not completely cover our
    // bounds, so we fill with white.  If we are not in fast resize mode, we do
    // not need to draw anything.

    if( self.fastResizeMode )
    {
        [[NSColor whiteColor] set];
        NSRectFill( dirtyRect );
    }
}

- (void) layoutSubviews
{
    // There should never be more than one subview.  There can be zero, if we are
    // in the process of switching tabs or closing the window.  In those cases, no
    // layout is needed.

    NSArray* subviews = self.subviews;
    NSAssert( subviews.count <= 1, @"There should never be more than one subview." );

    if( [subviews count] >= 1)
    {
        NSView* subview = subviews[0];
        NSRect bounds = self.bounds;

        if( self.fastResizeMode )
        {
            NSRect frame = subview.frame;
            frame.origin.x = 0;
            frame.origin.y = NSHeight( bounds ) - NSHeight( frame );
            [subview setFrame: frame];
        }
        else
        {
            [subview setFrame: bounds];
        }
    }
}

@end
