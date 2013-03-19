//
//  AVTTabbedWindows - AVTHoverCloseButton.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTHoverCloseButton.h"

const CGFloat kCircleRadiusPercentage = 0.415f;
const CGFloat kCircleHoverWhite = 0.565f;
const CGFloat kCircleClickWhite = 0.396f;
const CGFloat kXShadowAlpha = 0.75f;
const CGFloat kXShadowCircleAlpha = 0.1f;

static NSPoint AVTMidRect( NSRect rect );

@interface NSBezierPath( HoverButtonAdditions )

- (void) fillWithInnerShadow: (NSShadow*) shadow;

@end

@implementation AVTHoverCloseButton

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];
    if( self != nil )
    {
        [self commonInit];
    }
    return self;
}

- (void) dealloc
{
    [_xPath release];
    [_circlePath release];

    [super dealloc];
}

- (void) commonInit
{
    // Set accessibility description.

    NSString* description = @"Close";
    [self.cell accessibilitySetOverrideValue: description forAttribute: NSAccessibilityDescriptionAttribute];
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self commonInit];
}

- (void) drawRect: (NSRect) rect
{
    if( !self.circlePath || !self.xPath )
        [self setUpDrawingPaths];

    // If the user is hovering over the button, a light/dark gray circle is drawn behind the 'x'.

    if( self.hoverState != eHoverStateNone )
    {
        // Adjust the darkness of the circle depending on whether it is being
        // clicked.

        CGFloat white = (self.hoverState == eHoverStateMouseOver) ? kCircleHoverWhite : kCircleClickWhite;
        [[NSColor colorWithCalibratedWhite: white alpha: 1.0] set];
        [self.circlePath fill];
    }

    [[NSColor whiteColor] set];
    [self.xPath fill];

    // Give the 'x' an inner shadow for depth. If the button is in a hover state
    // (circle behind it), then adjust the shadow accordingly (not as harsh).

    NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
    CGFloat alpha = (self.hoverState != eHoverStateNone) ? kXShadowCircleAlpha : kXShadowAlpha;
    shadow.shadowColor = [NSColor colorWithCalibratedWhite: 0.15f alpha: alpha];
    shadow.shadowOffset = (NSSize){ 0.0, 0.0 };
    shadow.shadowBlurRadius = 2.5f;
    [self.xPath fillWithInnerShadow: shadow];
}

- (void) setUpDrawingPaths
{
    NSPoint viewCenter = AVTMidRect( self.bounds );

    self.circlePath = [NSBezierPath bezierPath];
    [self.circlePath moveToPoint: viewCenter];
    CGFloat radius = kCircleRadiusPercentage * NSWidth( self.bounds );
    [self.circlePath appendBezierPathWithArcWithCenter: viewCenter
                                                radius: radius
                                            startAngle: 0.0
                                              endAngle: 365.0];

    // Construct an 'x' by drawing two intersecting rectangles in the shape of a
    // cross and then rotating the path by 45 degrees.

    self.xPath = [NSBezierPath bezierPath];
    [self.xPath appendBezierPathWithRect: NSMakeRect( 3.5f, 7.0f, 9.0f, 2.0f )];
    [self.xPath appendBezierPathWithRect: NSMakeRect( 7.0f, 3.5f, 2.0f, 9.0f )];

    NSPoint pathCenter = AVTMidRect( self.xPath.bounds );

    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy: viewCenter.x yBy: viewCenter.y];
    [transform rotateByDegrees: 45.0f];
    [transform translateXBy: -pathCenter.x yBy: -pathCenter.y];

    [self.xPath transformUsingAffineTransform: transform];
}

@end

@implementation NSBezierPath( HoverButtonAdditions )

- (void) fillWithInnerShadow: (NSShadow*) shadow
{
    [NSGraphicsContext saveGraphicsState];
    {
        NSSize offset = shadow.shadowOffset;
        NSSize originalOffset = offset;
        CGFloat radius = shadow.shadowBlurRadius;
        NSRect bounds = NSInsetRect( self.bounds, -(ABS( offset.width ) + radius), -(ABS( offset.height ) + radius) );
        offset.height += bounds.size.height;
        shadow.shadowOffset = offset;
        NSAffineTransform* transform = [NSAffineTransform transform];
        if( [[NSGraphicsContext currentContext] isFlipped] )
            [transform translateXBy: 0 yBy: bounds.size.height];
        else
            [transform translateXBy: 0 yBy: -bounds.size.height];

        NSBezierPath* drawingPath = [NSBezierPath bezierPathWithRect: bounds];
        [drawingPath setWindingRule: NSEvenOddWindingRule];
        [drawingPath appendBezierPath: self];
        [drawingPath transformUsingAffineTransform: transform];

        [self addClip];
        [shadow set];
        [[NSColor blackColor] set];
        [drawingPath fill];

        shadow.shadowOffset = originalOffset;
    }
    [NSGraphicsContext restoreGraphicsState];
}

@end

NSPoint AVTMidRect( NSRect rect )
{
    return NSMakePoint( NSMidX( rect ), NSMidY( rect ) );
}
