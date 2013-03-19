// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import <Cocoa/Cocoa.h>

@protocol AVTThrobberDataDelegate;

// A class that knows how to draw an animated state to indicate progress.
// Creating the class starts the animation, destroying it stops it. There are
// two types:
//
// - Filmstrip: Draws via a sequence of frames in an image. There is no state
//   where the class is frozen on an image and not animating. The image needs to
//   be made of squares such that the height divides evenly into the width.
//
// - Toast: Draws an image animating down to the bottom and then another image
//   animating up from the bottom. Stops once the animation is complete.

@interface AVTThrobberView : NSView

// Creates a filmstrip view with |frame| and image |image|.

+ (id) filmstripThrobberViewWithFrame: (NSRect) frame image: (NSImage*) image;

// Creates a toast view with |frame| and specified images.

+ (id) toastThrobberViewWithFrame: (NSRect) frame beforeImage: (NSImage*) beforeImage afterImage: (NSImage*) afterImage;

@property (nonatomic, retain) id<AVTThrobberDataDelegate> dataDelegate;

@end
