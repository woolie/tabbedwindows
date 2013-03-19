//
//  AVTTabbedWindows - NSAnimationContext+Duration.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
//  Modified by Steven Woolgar on 01/31/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "NSAnimationContext+Duration.h"

static NSTimeInterval AVTModifyDurationBasedOnCurrentState( NSTimeInterval duration, NSUInteger eventMask );

@implementation NSAnimationContext( AVTDuration )

- (void) avt_setDuration: (NSTimeInterval) duration eventMask: (NSUInteger) eventMask
{
    [self setDuration: AVTModifyDurationBasedOnCurrentState( duration, eventMask )];
}

@end

NSTimeInterval AVTModifyDurationBasedOnCurrentState( NSTimeInterval duration,
                                                     NSUInteger eventMask )
{
    NSEvent* currentEvent = [NSApp currentEvent];
    NSUInteger currentEventMask = NSEventMaskFromType( currentEvent.type );
    if( eventMask & currentEventMask )
    {
        NSUInteger modifiers = [currentEvent modifierFlags];
        if( !(modifiers & (NSAlternateKeyMask | NSCommandKeyMask) ) )
        {
            if( modifiers & NSShiftKeyMask )
            {
                // 25 is the ascii code generated for a shift-tab (End-of-message)
                // The shift modifier is ignored if it is applied to a Tab key down/up.
                // Tab and shift-tab are often used for navigating around UI elements,
                // and in the majority of cases slowing down the animations while
                // navigating around UI elements is not desired.

                if( (currentEventMask & (NSKeyDownMask | NSKeyUpMask) ) &&
                    !(modifiers & NSControlKeyMask) &&
                    ([[currentEvent characters] length] == 1) &&
                    ([[currentEvent characters] characterAtIndex: 0] == 25) )
                {
                    duration = duration;
                }
                else
                {
                    duration *= 5.0;
                }
            }

            // These are additive, so shift+control returns 10 * duration.

            if( modifiers & NSControlKeyMask )
            {
                duration *= 2.0;
            }
        }
    }

    return duration;
}

