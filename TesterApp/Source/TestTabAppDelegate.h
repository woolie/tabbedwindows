//
//  TabbedWindowTester - TestTabAppDelegate.h
//
//  Created by Steven Woolgar on 02/05/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AVTContainerWindowController;

@interface TestTabAppDelegate : NSObject <NSApplicationDelegate>

- (void) commandDispatch: (id) sender;

@property (nonatomic, retain) AVTContainerWindowController* windowController;

@end
