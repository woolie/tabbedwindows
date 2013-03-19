//
//  AVTTabbedWindows - AVTTabWellView.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabWellView.h"

#import "AVTNewTabButton.h"

static BOOL ShouldWindowsMiniaturizeOnDoubleClick();

@implementation AVTTabWellView

- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];
    if( self != nil )
    {
        // Set lastMouseUp_ = -1000.0 so that timestamp-lastMouseUp_ is big unless lastMouseUp_ has been reset.

        _lastMouseUp = -1000.0;
        _bezelColor = [[NSColor colorWithCalibratedWhite: 247.0f / 255.0f alpha: 1.0f] retain];
        _arrowStrokeColor = [[NSColor colorWithCalibratedWhite: 0.0f alpha: 0.67f] retain];
        _arrowFillColor = [[NSColor colorWithCalibratedWhite: 1.0f alpha: 0.67f] retain];
    }

    return self;
}

- (void) dealloc
{
    [_addTabButton release];
    [_bezelColor release];
    [_arrowStrokeColor release];
    [_arrowFillColor release];

    [super dealloc];
}

- (void) drawRect: (NSRect) rect
{
    NSRect boundsRect = self.bounds;
    [self drawBorder: boundsRect];

    // Draw drop-indicator arrow (if appropriate).

    if( self.dropArrowShown )
    {
        // Programmer art: an arrow parametrized by many knobs. Note that the arrow
        // points downwards (so understand "width" and "height" accordingly).

        // How many (pixels) to inset on the top/bottom.

        const CGFloat kArrowTopInset = 1.5f;
        const CGFloat kArrowBottomInset = 1.0f;

        // What proportion of the vertical space is dedicated to the arrow tip,
        // i.e., (arrow tip height)/(amount of vertical space).

        const CGFloat kArrowTipProportion = 0.5f;

        // This is a slope, i.e., (arrow tip height)/(0.5 * arrow tip width).

        const CGFloat kArrowTipSlope = 1.2f;

        // What proportion of the arrow tip width is the stem, i.e., (stem width)/(arrow tip width).

        const CGFloat kArrowStemProportion = 0.33f;

        NSPoint arrowTipPos = [self dropArrowPosition];
        arrowTipPos.y += kArrowBottomInset;  // Inset on the bottom.

        // Height we have to work with (insetting on the top).

        CGFloat availableHeight = NSMaxY( boundsRect ) - arrowTipPos.y - kArrowTopInset;
        assert( availableHeight >= 5 );

        // Based on the knobs above, calculate actual dimensions which we'll need for drawing.

        CGFloat arrowTipHeight = kArrowTipProportion * availableHeight;
        CGFloat arrowTipWidth = 2 * arrowTipHeight / kArrowTipSlope;
        CGFloat arrowStemHeight = availableHeight - arrowTipHeight;
        CGFloat arrowStemWidth = kArrowStemProportion * arrowTipWidth;
        CGFloat arrowStemInset = (arrowTipWidth - arrowStemWidth) / 2;

        // The line width is arbitrary, but our path really should be mitered.

        NSBezierPath* arrow = [NSBezierPath bezierPath];
        [arrow setLineJoinStyle: NSMiterLineJoinStyle];
        [arrow setLineWidth: 1];

        // Define the arrow's shape! We start from the tip and go clockwise.

        [arrow moveToPoint: arrowTipPos];
        [arrow relativeLineToPoint: NSMakePoint( -arrowTipWidth / 2, arrowTipHeight )];
        [arrow relativeLineToPoint: NSMakePoint( arrowStemInset, 0 )];
        [arrow relativeLineToPoint: NSMakePoint( 0, arrowStemHeight )];
        [arrow relativeLineToPoint: NSMakePoint( arrowStemWidth, 0 )];
        [arrow relativeLineToPoint: NSMakePoint( 0, -arrowStemHeight )];
        [arrow relativeLineToPoint: NSMakePoint( arrowStemInset, 0 )];
        [arrow closePath];

        // Draw and fill the arrow.

        [self.arrowStrokeColor set];
        [arrow stroke];
        [self.arrowFillColor setFill];
        [arrow fill];
    }
}

// Draw bottom border (a dark border and light highlight). Each tab is responsible for mimicking this bottom border, unless it's the selected tab.

- (void) drawBorder: (NSRect) bounds
{
    NSRect borderRect = bounds;
    borderRect.origin.y = 1.0f;
    borderRect.size.height = 1.0f;

    [[NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f] set];
    NSRectFillUsingOperation( borderRect, NSCompositeSourceOver );

    NSRect contentRect;
    NSDivideRect( bounds, &borderRect, &contentRect, 1, NSMinYEdge );
    [self.bezelColor set];

    NSRectFill( borderRect );
    NSRectFillUsingOperation( borderRect, NSCompositeSourceOver );
}

// YES if a double-click in the background of the tab strip minimizes the window.

- (BOOL) doubleClickMinimizesWindow
{
    return YES;
}

// We accept first mouse so clicks onto close/zoom/miniaturize buttons and title bar double-clicks are properly detected even
// when the window is in the background.

- (BOOL) acceptsFirstMouse: (NSEvent*) event
{
    return YES;
}

// Trap double-clicks and make them miniaturize the container window.

- (void) mouseUp: (NSEvent*) event
{
    // Bail early if double-clicks are disabled.

    if( ![self doubleClickMinimizesWindow] )
    {
        [super mouseUp: event];
    }
    else
    {
        NSInteger clickCount = [event clickCount];
        NSTimeInterval timestamp = [event timestamp];

        // Double-clicks on Zoom/Close/Mininiaturize buttons shouldn't cause miniaturization. For those, we miss the first click but get the
        // second (with clickCount == 2!). We thus check that we got a first click shortly before (measured up-to-up) a double-click.
        // Cocoa doesn't have a documented way of getting the proper interval (= (double-click-threshold) + (drag-threshold);
        // the former is Carbon GetDblTime()/60.0 or  com.apple.mouse.doubleClickThreshold [undocumented]). So we hard-code
        // "short" as 0.8 seconds. (Measuring up-to-up isn't enough to properly  detect double-clicks, but we're actually using Cocoa for that.)

        if( clickCount == 2 && (timestamp - self.lastMouseUp) < 0.8 )
        {
            if( ShouldWindowsMiniaturizeOnDoubleClick() )
                [[self window] performMiniaturize: self];
        }
        else
        {
            [super mouseUp: event];
        }

        // If clickCount is 0, the drag threshold was passed.

        self.lastMouseUp = (clickCount == 1) ? timestamp : -1000.0;
    }
}

- (BOOL) accessibilityIsIgnored
{
    return NO;
}

- (id) accessibilityAttributeValue: (NSString*) attribute
{
    id attributeValue;

    if( [attribute isEqual: NSAccessibilityRoleAttribute] )
        attributeValue = NSAccessibilityGroupRole;
    else
        attributeValue = [super accessibilityAttributeValue: attribute];

    return attributeValue;
}

@end

BOOL ShouldWindowsMiniaturizeOnDoubleClick()
{
    // We use an undocumented method in Cocoa; if it doesn't exist, default to |YES|. If it ever goes away, we can do
    // (using an undocumented pref key):
    //   NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    //   return ![defaults objectForKey: @"AppleMiniaturizeOnDoubleClick"] || [defaults boolForKey: @"AppleMiniaturizeOnDoubleClick"];

    BOOL methodImplemented = [NSWindow respondsToSelector: @selector( _shouldMiniaturizeOnDoubleClick )];
    NSCAssert( methodImplemented, @"if this happens, see discussion above" );
    return !methodImplemented || [NSWindow performSelector: @selector( _shouldMiniaturizeOnDoubleClick )];
}
