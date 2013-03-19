//
//  TabbedWindowTester - TestTabAppDelegate.m
//
//  Created by Steven Woolgar on 02/05/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "TestTabAppDelegate.h"

#import "AVTContainerWindowController.h"
#import "TestTabContainer.h"

@implementation TestTabAppDelegate

- (void) dealloc
{
    [_windowController release];

    [super dealloc];
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification
{
    // Create a new container & window when we start

    self.windowController = [[[AVTContainerWindowController alloc] initWithContainer: [TestTabContainer container]] autorelease];
    [self.windowController.container addBlankTabInForeground: YES];
    [self.windowController showWindow: self];
}

// When there are no windows in our application, this class (AppDelegate) will become the first responder.
// We forward the command to the container class.

- (void) commandDispatch: (id) sender
{
    NSLog( @"commandDispatch %d", (int)[sender tag] );
    [TestTabContainer executeCommand: [sender tag]];
}

@end
