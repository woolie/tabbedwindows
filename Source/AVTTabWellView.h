//
//  AVTTabbedWindows - AVTTabWellView.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVTNewTabButton;

@interface AVTTabWellView : NSView

@property (nonatomic, assign) NSTimeInterval lastMouseUp;
@property (nonatomic, retain) IBOutlet AVTNewTabButton* addTabButton;
@property (nonatomic, assign) BOOL dropArrowShown;
@property (nonatomic, assign) NSPoint dropArrowPosition;
@property (nonatomic, retain) NSColor* bezelColor;
@property (nonatomic, retain) NSColor* arrowStrokeColor;
@property (nonatomic, retain) NSColor* arrowFillColor;

@end
