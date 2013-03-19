//
//  AVTTabbedWindows - AVTHoverButton.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTHoverButton.h"

@implementation AVTHoverButton

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];
    if( self != nil )
    {
        self.trackingEnabled = YES;
        _hoverState = eHoverStateNone;

        [self updateTrackingAreas];
    }

    return self;
}

- (void) dealloc
{
    self.trackingEnabled = NO;

    [super dealloc];
}

- (void) awakeFromNib
{
    self.trackingEnabled = YES;
    self.hoverState = eHoverStateNone;
    [self updateTrackingAreas];
}

- (void) mouseEntered: (NSEvent*) theEvent
{
    self.hoverState = eHoverStateMouseOver;
    [self setNeedsDisplay: YES];
}

- (void) mouseExited: (NSEvent*) theEvent
{
    self.hoverState = eHoverStateNone;
    [self setNeedsDisplay: YES];
}

- (void) mouseDown: (NSEvent*) theEvent
{
    self.hoverState = eHoverStateMouseDown;
    [self setNeedsDisplay: YES];

    // The hover button needs to hold onto itself here for a bit.  Otherwise,
    // it can be freed while |super mouseDown:| is in it's loop, and the
    // |checkImageState| call will crash.

    [self retain];

    [super mouseDown: theEvent];

    // We need to check the image state after the mouseDown event loop finishes.
    // It's possible that we won't get a mouseExited event if the button was
    // moved under the mouse during tab resize, instead of the mouse moving over
    // the button.

    [self checkImageState];
    [self release];
}

- (void) setTrackingEnabled: (BOOL) enabled
{
    if( enabled )
    {
        self.hoverTrackingArea = [[[NSTrackingArea alloc] initWithRect: self.bounds
                                                               options: NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                                                 owner: self
                                                              userInfo: nil] autorelease];
        [self addTrackingArea: self.hoverTrackingArea];

        // If you have a separate window that overlaps the close button, and you
        // move the mouse directly over the close button without entering another
        // part of the tab strip, we don't get any mouseEntered event since the
        // tracking area was disabled when we entered.

        [self checkImageState];
    }
    else
    {
        if( self.hoverTrackingArea )
        {
            [self removeTrackingArea: self.hoverTrackingArea];
            self.hoverTrackingArea = nil;
        }
    }
}

- (void) updateTrackingAreas
{
    [super updateTrackingAreas];
    [self checkImageState];
}

- (void) checkImageState
{
    if( self.hoverTrackingArea == nil )
    {
        // Update the button's state if the button has moved.

        NSPoint mouseLoc = [[self window] mouseLocationOutsideOfEventStream];
        mouseLoc = [self convertPoint: mouseLoc fromView: nil];
        self.hoverState = NSPointInRect( mouseLoc, self.bounds ) ? eHoverStateMouseOver : eHoverStateNone;
        [self setNeedsDisplay: YES];
    }
}

@end
