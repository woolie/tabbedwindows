//
//  AVTTabbedWindows - AVTGradientView.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTGradientView.h"

const CGFloat kToolbarTopOffset = 12.0f;
const CGFloat kToolbarMaxHeight = 100.0f;

static NSGradient* sGradientFaded = nil;
static NSGradient* sGradientNotFaded = nil;
static NSColor* sDefaultColorToolbarStroke = nil;
static NSColor* sDefaultColorToolbarStrokeInactive = nil;

static NSGradient* MakeGradient( BOOL faded );

@implementation AVTGradientView

@synthesize showsDivider = _showsDivider;

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];
    if( self != nil )
    {
        _showsDivider = YES;
    }

    return self;
}

- (void) dealloc
{
    [_strokeColor release];

    [super dealloc];
}

- (void) awakeFromNib
{
    self.showsDivider = YES;
}

- (void) drawBackground
{
    if( sGradientFaded == nil )
    {
        sGradientFaded = MakeGradient( YES );
        sGradientNotFaded = MakeGradient( NO );
        sDefaultColorToolbarStroke = [[NSColor colorWithCalibratedWhite: 103.0f / 255.0f alpha: 1.0f] retain];
        sDefaultColorToolbarStrokeInactive = [[NSColor colorWithCalibratedWhite: 123.0f / 255.0f alpha: 1.0f] retain];
    }

    NSGradient* gradient = self.window.isKeyWindow ? sGradientFaded : sGradientFaded;
    CGFloat winHeight = NSHeight( self.window.frame );
    NSPoint startPoint = [self convertPoint: NSMakePoint( 0, winHeight - kToolbarTopOffset ) fromView: nil];
    NSPoint endPoint = NSMakePoint( 0, winHeight - kToolbarTopOffset - kToolbarMaxHeight );
    endPoint = [self convertPoint: endPoint fromView: nil];

    [gradient drawFromPoint: startPoint
                    toPoint: endPoint
                    options: (NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation)];

    if( self.showsDivider )
    {
        // Draw bottom stroke

        [self.strokeColor set];
        NSRect borderRect, contentRect;
        NSDivideRect( self.bounds, &borderRect, &contentRect, 1, NSMinYEdge );
        NSRectFillUsingOperation( borderRect, NSCompositeSourceOver );
    }
}

- (BOOL) showsDivider
{
    return _showsDivider;
}

- (void) setShowsDivider: (BOOL) showsDivider
{
    if( showsDivider != _showsDivider )
    {
        _showsDivider = showsDivider;
        [self setNeedsDisplay: YES];
    }
}

@end

NSGradient* MakeGradient( BOOL faded )
{
    NSColor* start_color = [NSColor colorWithCalibratedRed: 0.93f green: 0.93f blue: 0.93f alpha: 1.0f];
    NSColor* mid_color   = [NSColor colorWithCalibratedRed: 0.84f green: 0.84f blue: 0.84f alpha: 1.0f];
    NSColor* end_color   = [NSColor colorWithCalibratedRed: 0.76f green: 0.76f blue: 0.76f alpha: 1.0f];
    NSColor* glow_color  = [NSColor colorWithCalibratedRed: 0.84f green: 0.84f blue: 0.84f alpha: 1.0f];
    return [[NSGradient alloc] initWithColorsAndLocations: start_color, 0.00f,
                                                           mid_color,   0.25f,
                                                           end_color,   0.50f,
                                                           glow_color,  0.75f,
                                                           nil];
}
