//
//  AVTTabbedWindows - AVTToolbarView.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTToolbarView.h"

#import "NSWindow+AVTTheme.h"

@implementation AVTToolbarView

// Prevent mouse down events from moving the parent window around.

- (BOOL) mouseDownCanMoveWindow
{
    return NO;
}

- (void) drawRect: (NSRect) rect
{
    // The toolbar's background pattern is phased relative to the tab strip view's
    // background pattern.

    NSPoint phase = [self.window themePatternPhase];
    [[NSGraphicsContext currentContext] setPatternPhase: phase];
    [self drawBackground];
}

// Override of |-[BackgroundGradientView strokeColor]|; make it respect opacity.

- (NSColor*) strokeColor
{
    return [super.strokeColor colorWithAlphaComponent: self.dividerOpacity];
}

- (BOOL) accessibilityIsIgnored
{
    return NO;
}

- (id) accessibilityAttributeValue: (NSString*) attribute
{
    id attributeValue = nil;

    if( [attribute isEqual: NSAccessibilityRoleAttribute] )
        attributeValue = NSAccessibilityToolbarRole;
    else
        attributeValue = [super accessibilityAttributeValue: attribute];

    return attributeValue;
}

@end
