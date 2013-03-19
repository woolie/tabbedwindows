//
//  AVTTabbedWindows - NSAnimationContext+Duration.h
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
//  Modified by Steven Woolgar on 01/31/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAnimationContext( AVTDuration )

- (void) avt_setDuration: (NSTimeInterval) duration eventMask: (NSUInteger) eventMask;

@end
