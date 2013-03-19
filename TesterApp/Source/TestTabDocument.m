//
//  TestTabDocument.m
//  TabbedWindowTester
//
//  Created by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "TestTabDocument.h"

@implementation TestTabDocument

- (id) initWithBaseTabDocument: (AVTTabDocument*) baseDocument
{
    self = [super initWithBaseTabDocument: baseDocument];
    if( self != nil )
    {
        // Setup our contents -- a scrolling text view

        // Create a simple NSTextView

        NSTextView* textView = [[NSTextView alloc] initWithFrame: NSZeroRect];
        textView.font = [NSFont userFixedPitchFontOfSize: 13.0f];
        textView.autoresizingMask = NSViewMaxYMargin | NSViewMinXMargin | NSViewWidthSizable | NSViewMaxXMargin | NSViewHeightSizable | NSViewMinYMargin;

        // Create a NSScrollView to which we add the NSTextView

        NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame: NSZeroRect];
        scrollView.documentView = textView;
        scrollView.hasVerticalScroller = YES;

        // Set the NSScrollView as our view

        self.view = scrollView;

        [scrollView release];
        [textView release];
    }

    return self;
}

- (void) viewFrameDidChange: (NSRect) newFrame
{
    // We need to recalculate the frame of the NSTextView when the frame changes.
    // This happens when a tab is created and when it's moved between windows.

    [super viewFrameDidChange: newFrame];

    NSClipView* clipView = [[self.view subviews] objectAtIndex: 0];
    NSTextView* textView = [[clipView subviews] objectAtIndex: 0];
    NSRect frame = (NSRect){ NSZeroPoint, [(NSScrollView*)self.view contentSize] };
    textView.frame = frame;
}

@end
