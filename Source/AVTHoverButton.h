//
//  AVTTabbedWindows - AVTHoverButton.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/30/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVTHoverButton.h"

typedef enum
{
    eHoverStateNone,
    eHoverStateMouseOver,
    eHoverStateMouseDown

} AVTHoverState;

@interface AVTHoverButton : NSButton

@property (nonatomic, assign) AVTHoverState hoverState;
@property (nonatomic, retain) NSTrackingArea* hoverTrackingArea;
@property (nonatomic, assign, getter=isTrackingEnabled) BOOL trackingEnabled;

@end
