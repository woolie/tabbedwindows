//
//  TabbedWindowTester - TestTabContainer.m
//
//  Created by Steven Woolgar on 02/05/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "TestTabContainer.h"

#import "AVTTabDocument.h"
#import "TestTabDocument.h"

@implementation TestTabContainer

// This method is called when a new tab is being created. We need to return a new AVTTabDocument object which will represent the contents of the new tab.

- (AVTTabDocument*) newBlankTabBasedOn: (AVTTabDocument*) baseDocument
{
    // Create a new instance of our tab type

    return [[TestTabDocument alloc] initWithBaseTabDocument: baseDocument];
}

@end
