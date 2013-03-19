//
//  AVTTabbedWindows - AVTContainerWindow.m
//
//  Copyright (c) 2011 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/11/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTContainerWindow.h"

#import "AVTContainerWindowController.h"
#import "AVTTabWellController.h"
#import "AVTTabWindowController.h"

static NSString* const kBrowserThemeDidChangeNotification = @"BrowserThemeDidChangeNotification";

// Chrome-comment:
//
// Our contqainer window does some interesting things to get the behaviors that we want. We replace the standard window controls
// (zoom, close, miniaturize) with our own versions, so that we can position them slightly differently than the default window has
// them. To do this, we hide the ones that Apple provides us with, and create our own. This requires us to handle tracking for the
// buttons (so that they highlight and activate correctly) as well as implement the private method _mouseInGroup in our frame view
// class which is required to get the rollover highlight drawing to draw correctly.

const CGFloat kWindowGradientHeight = 24.0f;

@interface NSButton( NSThemeCloseWidget_PrivateAPI )
- (void) setDocumentEdited: (BOOL) edited;
@end

@interface AVTContainerWindow()
- (NSView*) frameView;
@end

@implementation AVTContainerWindow

- (id) initWithContentRect: (NSRect) contentRect
                 styleMask: (NSUInteger) aStyle
                   backing: (NSBackingStoreType) bufferingType
                     defer: (BOOL) flag
{
    self = [super initWithContentRect: contentRect
                            styleMask: aStyle
                              backing: bufferingType
                                defer: flag];
    if( self != nil )
    {
        if( aStyle & NSTexturedBackgroundWindowMask )
        {
            // The following two calls fix http://www.crbug.com/25684 by preventing
            // the window from recalculating the border thickness as the window is
            // resized.
            // This was causing the window tint to change for the default system theme
            // when the window was being resized.

            [self setAutorecalculatesContentBorderThickness: NO forEdge: NSMaxYEdge];
            [self setContentBorderThickness: kWindowGradientHeight forEdge: NSMaxYEdge];
        }

        _closeButton = [self standardWindowButton: NSWindowCloseButton];
        _miniaturizeButton = [self standardWindowButton: NSWindowMiniaturizeButton];
        _zoomButton = [self standardWindowButton: NSWindowZoomButton];

        [_closeButton setPostsFrameChangedNotifications: YES];
        [_miniaturizeButton setPostsFrameChangedNotifications: YES];
        [_zoomButton setPostsFrameChangedNotifications: YES];

        _windowButtonsInterButtonSpacing = NSMinX( _miniaturizeButton.frame ) - NSMaxX( _closeButton.frame );

        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver: self
                   selector: @selector( adjustCloseButton: )
                       name: NSViewFrameDidChangeNotification
                     object: _closeButton];
        [center addObserver: self
                   selector: @selector( adjustMiniaturizeButton: )
                       name: NSViewFrameDidChangeNotification
                     object: _miniaturizeButton];
        [center addObserver: self
                   selector: @selector( adjustZoomButton: )
                       name: NSViewFrameDidChangeNotification
                     object: _zoomButton];
        [center addObserver: self
                   selector: @selector( themeDidChangeNotification: )
                       name: kBrowserThemeDidChangeNotification
                     object: nil];
    }

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [super dealloc];
}

- (void) setWindowController: (NSWindowController*) controller
{
    if( controller != [self windowController])
    {
        // Clean up our old stuff.

        [[NSNotificationCenter defaultCenter] removeObserver: self];

        [super setWindowController: controller];

        self.hasTabWell = NO;
        AVTContainerWindowController* containerController = (AVTContainerWindowController*)controller;
        if( [containerController isKindOfClass: [AVTContainerWindowController class]] )
        {
            self.hasTabWell = [containerController hasTabWell];
        }

        // Force re-layout of the window buttons by wiggling the size of the frame view.

        NSView* frameView = [self.contentView superview];
        BOOL frameViewDidAutoresizeSubviews = [frameView autoresizesSubviews];
        [frameView setAutoresizesSubviews: NO];
        NSRect oldFrame = frameView.frame;
        [frameView setFrame: NSZeroRect];
        [frameView setFrame: oldFrame];
        [frameView setAutoresizesSubviews: frameViewDidAutoresizeSubviews];
    }
}

- (void) adjustCloseButton: (NSNotification*) notification
{
    [self adjustButton: notification.object ofKind: NSWindowCloseButton];
}

- (void) adjustMiniaturizeButton: (NSNotification*) notification
{
    [self adjustButton: notification.object ofKind: NSWindowMiniaturizeButton];
}

- (void) adjustZoomButton: (NSNotification*) notification
{
    [self adjustButton: notification.object ofKind: NSWindowZoomButton];
}

- (void) adjustButton: (NSButton*) button
               ofKind: (NSWindowButton) kind
{
    NSRect buttonFrame = button.frame;
    NSRect frameViewBounds = self.frameView.bounds;

    CGFloat xOffset = self.hasTabWell ? kWindowButtonsWithTabOffsetFromLeft : kWindowButtonsWithoutTabOffsetFromLeft;
    CGFloat yOffset = self.hasTabWell ? kWindowButtonsWithTabWellOffsetFromTop : kWindowButtonsWithoutTabWellOffsetFromTop;

    buttonFrame.origin = (NSPoint){ xOffset, (NSHeight( frameViewBounds ) - NSHeight( buttonFrame ) - yOffset) };

    switch( kind )
    {
        case NSWindowZoomButton:
            buttonFrame.origin.x += NSWidth( self.miniaturizeButton.frame );
            buttonFrame.origin.x += self.windowButtonsInterButtonSpacing;

        // fallthrough
        case NSWindowMiniaturizeButton:
            buttonFrame.origin.x += NSWidth( self.closeButton.frame );
            buttonFrame.origin.x += self.windowButtonsInterButtonSpacing;

        // fallthrough
        default:
            break;
    }

    BOOL didPost = [button postsBoundsChangedNotifications];
    [button setPostsFrameChangedNotifications: NO];
    [button setFrame: buttonFrame];
    [button setPostsFrameChangedNotifications: didPost];
}

- (NSView*) frameView
{
    return [self.contentView superview];
}

// The tab strip view covers our window buttons. So we add hit testing here
// to find them properly and return them to the accessibility system.

- (id) accessibilityHitTest: (NSPoint) point
{
    NSPoint windowPoint = [self convertScreenToBase: point];
    NSArray* controls = @[self.closeButton, self.zoomButton, self.miniaturizeButton];
    id value = nil;

    for( NSControl* control in controls )
    {
        if( NSPointInRect( windowPoint, control.frame ) )
        {
            value = [control accessibilityHitTest: point];
            break;
        }
    }

    if( !value )
    {
        value = [super accessibilityHitTest: point];
    }

    return value;
}

// Map our custom buttons into the accessibility hierarchy correctly.

- (id) accessibilityAttributeValue: (NSString*) attribute
{
    static NSDictionary* controlAttributes = nil;
    if( controlAttributes == nil )
    {
        NSAssert( self.closeButton.cell, @"closeButton's cell is nil." );
        NSAssert( self.closeButton.cell, @"zoomButton's cell is nil." );
        NSAssert( self.closeButton.cell, @"miniaturizeButton's cell is nil." );

        controlAttributes = [@{ NSAccessibilityCloseButtonAttribute : self.closeButton.cell,
                                NSAccessibilityZoomButtonAttribute : self.zoomButton.cell,
                                NSAccessibilityMinimizeButtonAttribute : self.miniaturizeButton.cell } retain];
    }

    id value = controlAttributes[attribute];
    if( value == nil )
    {
        value = [super accessibilityAttributeValue: attribute];
    }

    return value;
}

- (void) windowMainStatusChanged
{
    [self.closeButton setNeedsDisplay];
    [self.zoomButton setNeedsDisplay];
    [self.miniaturizeButton setNeedsDisplay];

    NSView* frameView = self.frameView;
    NSView* contentView = self.contentView;
    NSRect updateRect = frameView.frame;
    NSRect contentRect = contentView.frame;

    CGFloat tabWellHeight = [AVTTabWellController defaultTabHeight];
    updateRect.size.height -= NSHeight( contentRect ) - tabWellHeight;
    updateRect.origin.y = NSMaxY( contentRect ) - tabWellHeight;
    [self.frameView setNeedsDisplayInRect: updateRect];
}

- (void) becomeMainWindow
{
    [self windowMainStatusChanged];
    [super becomeMainWindow];
}

- (void) resignMainWindow
{
    [self windowMainStatusChanged];
    [super resignMainWindow];
}

// Called after the current theme has changed.

- (void) themeDidChangeNotification: (NSNotification*) aNotification
{
    [self.frameView setNeedsDisplay: YES];
}

- (void) systemThemeDidChangeNotification: (NSNotification*) aNotification
{
    [self.closeButton setNeedsDisplay];
    [self.zoomButton setNeedsDisplay];
    [self.miniaturizeButton setNeedsDisplay];
}

- (void) sendEvent: (NSEvent*) event
{
    // For cocoa windows, clicking on the close and the miniaturize (but not the
    // zoom buttons) while a window is in the background does NOT bring that
    // window to the front. We don't get that behavior for free, so we handle
    // it here. Zoom buttons do bring the window to the front. Note that
    // Finder windows (in Leopard) behave differently in this regard in that
    // zoom buttons don't bring the window to the foreground.

    BOOL eventHandled = NO;
    if( !self.isMainWindow )
    {
        if( event.type == NSLeftMouseDown )
        {
            NSView* frameView = self.frameView;
            NSPoint mouse = [frameView convertPoint: event.locationInWindow fromView: nil];
            if( NSPointInRect( mouse, self.closeButton.frame ) )
            {
                [self.closeButton mouseDown: event];
                eventHandled = YES;
            }
            else if( NSPointInRect( mouse, self.miniaturizeButton.frame ) )
            {
                [self.miniaturizeButton mouseDown: event];
                eventHandled = YES;
            }
        }
    }

    if( !eventHandled )
    {
        [super sendEvent: event];
    }
}

// This method is called whenever a window is moved in order to ensure it fits
// on the screen.  We cannot always handle resizes without breaking, so we
// prevent frame constraining in those cases.

- (NSRect) constrainFrameRect: (NSRect) frame
                     toScreen: (NSScreen*) screen
{
    // Do not constrain the frame rect if our delegate says no.  In this case, return the original (unconstrained) frame.

    id delegate = self.delegate;
    if( [delegate respondsToSelector: @selector( shouldConstrainFrameRect )] && ![delegate shouldConstrainFrameRect] )
        return frame;

    return [super constrainFrameRect: frame toScreen: screen];
}

- (NSPoint) themePatternPhase
{
    id delegate = self.delegate;
    if( ![delegate respondsToSelector: @selector( themePatternPhase )] )
        return NSMakePoint( 0.0f, 0.0f );

    return [delegate themePatternPhase];
}

- (void) setDocumentEdited: (BOOL) documentEdited
{
    [super setDocumentEdited: documentEdited];
    [self.closeButton setDocumentEdited: documentEdited];
}

@end
