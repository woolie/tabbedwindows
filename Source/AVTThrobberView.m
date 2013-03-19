// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "AVTThrobberView.h"

static const CGFloat kAnimationIntervalSeconds = 0.03;  // 30ms, same as windows

@interface AVTThrobberView()

- (id) initWithFrame: (NSRect) frame delegate: (id<AVTThrobberDataDelegate>) delegate;
- (void) maintainTimer;
- (void) animate;

@end

@protocol AVTThrobberDataDelegate <NSObject>

// Is the current frame the last frame of the animation?

- (BOOL) animationIsComplete;

// Draw the current frame into the current graphics context.

- (void) drawFrameInRect: (NSRect) rect;

// Update the frame counter.

- (void) advanceFrame;

@end

@interface AVTThrobberFilmstripDelegate : NSObject <AVTThrobberDataDelegate>

- (id) initWithImage: (NSImage*) image;

@property (nonatomic, retain) NSImage* image;
@property (nonatomic, assign) NSUInteger numFrames;         // Number of frames in this animation.
@property (nonatomic, assign) NSUInteger animationFrame;    // Current frame of the animation, [0..numFrames_)

@end

@implementation AVTThrobberFilmstripDelegate

- (id) initWithImage: (NSImage*) image
{
    self = [super init];
    if( self != nil )
    {
        // Reset the animation counter so there's no chance we are off the end.

        _animationFrame = 0;

        // Ensure that the height divides evenly into the width. Cache the number of frames in the animation for later.

        NSSize imageSize = [image size];
        NSAssert( imageSize.height && imageSize.width, @"Don't supply a size = 0.0f, 0.0f image" );

        if( !imageSize.height )
            return [self autorelease];

        NSAssert( (int)imageSize.width % (int)imageSize.height == 0, @"Even sizes please." );

        _numFrames = (int)imageSize.width / (int)imageSize.height;
        NSAssert( _numFrames, @">= 0 number of frames please." );

        _image = [image retain];
    }

    return self;
}

- (void) dealloc
{
    [_image release];

    [super dealloc];
}

- (BOOL) animationIsComplete
{
    return NO;
}

- (void) drawFrameInRect: (NSRect) rect
{
    CGFloat imageDimension = [_image size].height;
    CGFloat xOffset = _animationFrame * imageDimension;
    NSRect sourceImageRect = NSMakeRect( xOffset, 0, imageDimension, imageDimension );
    [_image drawInRect: rect
              fromRect: sourceImageRect
             operation: NSCompositeSourceOver
              fraction: 1.0];
}

- (void) advanceFrame
{
    _animationFrame = ++_animationFrame % _numFrames;
}

@end

@interface AVTThrobberToastDelegate : NSObject<AVTThrobberDataDelegate>

- (id) initWithImage1: (NSImage*) image1 image2: (NSImage*) image2;

@property (nonatomic, retain) NSImage* image1;
@property (nonatomic, retain) NSImage* image2;
@property (nonatomic, assign) NSSize image1Size;
@property (nonatomic, assign) NSSize image2Size;
@property (nonatomic, assign) NSInteger animationFrame;  // Current frame of the animation,

@end

@implementation AVTThrobberToastDelegate

- (id) initWithImage1:(NSImage*)image1 image2:(NSImage*)image2
{
    self = [super init];
    if( self != nil )
    {
        _image1 = [image1 retain];
        _image2 = [image2 retain];
        _image1Size = [image1 size];
        _image2Size = [image2 size];
        _animationFrame = 0;
    }

    return self;
}

- (void) dealloc
{
    [_image1 release];
    [_image2 release];

    [super dealloc];
}

- (BOOL) animationIsComplete
{
    return ( _animationFrame >= _image1Size.height + _image2Size.height );
}

// From [0..image1Height) we draw image1, at image1Height we draw nothing, and
// from [image1Height+1..image1Hight+image2Height] we draw the second image.

- (void) drawFrameInRect: (NSRect) rect
{
    NSImage* image = nil;
    NSSize srcSize;
    NSRect destRect;

    if( _animationFrame < _image1Size.height )
    {
        image = self.image1;
        srcSize = _image1Size;
        destRect = NSMakeRect( 0, -_animationFrame, _image1Size.width, _image1Size.height );
    }
    else if( _animationFrame == _image1Size.height )
    {
        // nothing; intermediate blank frame
    }
    else
    {
        image = self.image2;
        srcSize = _image2Size;
        destRect = NSMakeRect( 0, _animationFrame - (_image1Size.height + _image2Size.height),
                               _image2Size.width, _image2Size.height );
    }

    if( image )
    {
        NSRect sourceImageRect = NSMakeRect( 0, 0, srcSize.width, srcSize.height );
        [image drawInRect: destRect
                 fromRect: sourceImageRect
                operation: NSCompositeSourceOver
                 fraction: 1.0];
    }
}

- (void) advanceFrame
{
    ++_animationFrame;
}

@end

// ThrobberTimer manages the animation of a set of ThrobberViews.  It allows
// a single timer instance to be shared among as many ThrobberViews as needed.

@interface AVTThrobberTimer : NSObject

// Returns a shared AVTThrobberTimer.  Everyone is expected to use the same
// instance.

+ (AVTThrobberTimer*) sharedThrobberTimer;

// Invalidates the timer, which will cause it to remove itself from the run
// loop.  This causes the timer to be released, and it should then release
// this object.

- (void) invalidate;

// Adds or removes ThrobberView objects from the _throbbers set.

- (void) addThrobber: (AVTThrobberView*) throbber;
- (void) removeThrobber: (AVTThrobberView*) throbber;

// A set of weak references to each AVTThrobberView that should be notified whenever the timer fires.

@property (nonatomic, retain) NSMutableSet* throbbers;

// Weak reference to the timer that calls back to this object.  The timer retains this object.

@property (nonatomic, assign) NSTimer* timer;

// Whether the timer is actively running.  To avoid timer construction and destruction overhead, the timer is not invalidated
// when it is not needed, but its next-fire date is set to [NSDate distantFuture]. It is not possible to determine whether the
// timer has been suspended by comparing its fireDate to [NSDate distantFuture], though, so a separate variable is used to track
// this state.

@property (nonatomic, assign) BOOL timerRunning;

// The thread that created this object.  Used to validate that AVTThrobberViews are only added and removed on the same thread
// that the fire action will be performed on.

@property (nonatomic, retain) NSThread* validThread;

@end

@interface AVTThrobberTimer()

// Starts or stops the timer as needed as AVTThrobberViews are added and removed from the _throbbers set.

- (void) maintainTimer;

// Calls animate on each AVTThrobberView in the _throbbers set.

- (void) fire: (NSTimer*) timer;

@end

@implementation AVTThrobberTimer

+ (AVTThrobberTimer*) sharedThrobberTimer
{
    static AVTThrobberTimer* sSharedInstance = nil;
    static dispatch_once_t predicate;

    if( sSharedInstance == nil )
    {
        dispatch_once( &predicate, ^
        {
            sSharedInstance = [AVTThrobberTimer alloc];
            sSharedInstance = [sSharedInstance init];
        } );
    }
    
    return sSharedInstance;
}

- (id) init
{
    self = [super init];
    if( self != nil )
    {
        // Start out with a timer that fires at the appropriate interval, but prevent it from firing by setting its
        // next-fire date to the distant future.  Once a AVTThrobberView is added, the timer will be allowed to start firing.

        _timer = [NSTimer scheduledTimerWithTimeInterval: kAnimationIntervalSeconds
                                                  target: self
                                                selector: @selector( fire: )
                                                userInfo: nil
                                                 repeats: YES];
        [_timer setFireDate: [NSDate distantFuture]];
        _timerRunning = NO;

        _validThread = [NSThread currentThread];
    }

    return self;
}

- (void) invalidate
{
    [_timer invalidate];
}

- (void) addThrobber: (AVTThrobberView*) throbber
{
    assert( [NSThread currentThread] == _validThread );

    [_throbbers addObject: throbber];
    [self maintainTimer];
}

- (void) removeThrobber: (AVTThrobberView*) throbber
{
    assert( [NSThread currentThread] == _validThread );

    [_throbbers removeObject: throbber];
    [self maintainTimer];
}

- (void) maintainTimer
{
    BOOL oldRunning = _timerRunning;
    BOOL newRunning = _throbbers.count ? NO : YES;

    if( oldRunning == newRunning )
        return;

    // To start the timer, set its next-fire date to an appropriate interval from
    // now.  To suspend the timer, set its next-fire date to a preposterous time
    // in the future.

    NSDate* fireDate;
    if( newRunning )
        fireDate = [NSDate dateWithTimeIntervalSinceNow: kAnimationIntervalSeconds];
    else
        fireDate = [NSDate distantFuture];

    [_timer setFireDate: fireDate];
    _timerRunning = newRunning;
}

- (void) fire: (NSTimer*) timer
{
    for( AVTThrobberView* throbber in self.throbbers )
    {
        [throbber animate];
    }
}

@end

@implementation AVTThrobberView

+ (id) filmstripThrobberViewWithFrame: (NSRect) frame
                                image: (NSImage*) image
{
    AVTThrobberFilmstripDelegate* delegate = [[[AVTThrobberFilmstripDelegate alloc] initWithImage: image] autorelease];
    if( !delegate )
        return nil;

    return [[[AVTThrobberView alloc] initWithFrame: frame
                                          delegate: delegate] autorelease];
}

+ (id) toastThrobberViewWithFrame: (NSRect) frame
                      beforeImage: (NSImage*) beforeImage
                       afterImage: (NSImage*) afterImage
{
    AVTThrobberToastDelegate* delegate = [[[AVTThrobberToastDelegate alloc] initWithImage1: beforeImage
                                                                                    image2: afterImage] autorelease];
    if( !delegate )
        return nil;

    return [[[AVTThrobberView alloc] initWithFrame: frame
                                          delegate: delegate] autorelease];
}

- (id) initWithFrame: (NSRect) frame
            delegate: (id<AVTThrobberDataDelegate>) delegate
{
    self = [super initWithFrame: frame];
    if( self != nil )
    {
        _dataDelegate = [delegate retain];
    }

    return self;
}

- (void) dealloc
{
    [_dataDelegate release];
    [[AVTThrobberTimer sharedThrobberTimer] removeThrobber: self];

    [super dealloc];
}

// Manages this AVTThrobberView's membership in the shared throbber timer set on the basis of its visibility and
// whether its animation needs to continue running.

- (void) maintainTimer
{
    AVTThrobberTimer* throbberTimer = [AVTThrobberTimer sharedThrobberTimer];

    if ([self window] && ![self isHidden] && ![_dataDelegate animationIsComplete])
        [throbberTimer addThrobber: self];
    else
        [throbberTimer removeThrobber: self];
}

// A AVTThrobberView added to a window may need to begin animating; a AVTThrobberView removed from a window should stop.

- (void) viewDidMoveToWindow
{
    [self maintainTimer];
    [super viewDidMoveToWindow];
}

// A hidden AVTThrobberView should stop animating.

- (void) viewDidHide
{
    [self maintainTimer];
    [super viewDidHide];
}

// A visible AVTThrobberView may need to start animating.

- (void) viewDidUnhide
{
    [self maintainTimer];
    [super viewDidUnhide];
}

// Called when the timer fires. Advance the frame, dirty the display, and remove the throbber if it's no longer needed.

- (void) animate
{
    [_dataDelegate advanceFrame];
    [self setNeedsDisplay: YES];

    if( [_dataDelegate animationIsComplete] )
    {
        [[AVTThrobberTimer sharedThrobberTimer] removeThrobber: self];
    }
}

// Overridden to draw the appropriate frame in the image strip.

- (void) drawRect: (NSRect) rect
{
    [_dataDelegate drawFrameInRect: [self bounds]];
}

@end
