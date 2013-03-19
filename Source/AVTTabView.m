//
//  AVTTabbedWindows - AVTTabView.m
//
//  A view that handles the event tracking (clicking and dragging) for a tab
//  on the tab strip. Relies on an associated CTTabController to provide a
//  target/action for selecting the tab.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabView.h"

#import "AVTHoverCloseButton.h"
#import "AVTTabController.h"
#import "AVTTabWindowController.h"
#import "AVTTabWellView.h"
#import "NSWindow+AVTTheme.h"

#pragma mark - Constants

// Constants for inset and control points for tab shape.

const CGFloat kInsetMultiplier = 2.0f / 3.0f;
const CGFloat kControlPoint1Multiplier = 1.0f / 3.0f;
const CGFloat kControlPoint2Multiplier = 3.0f / 8.0f;

// The amount of time in seconds during which each type of glow increases, holds
// steady, and decreases, respectively.

const NSTimeInterval kHoverShowDuration = 0.20;
const NSTimeInterval kHoverHoldDuration = 0.02;
const NSTimeInterval kHoverHideDuration = 0.40;
const NSTimeInterval kAlertShowDuration = 0.40;
const NSTimeInterval kAlertHoldDuration = 0.40;
const NSTimeInterval kAlertHideDuration = 0.40;

// The default time interval in seconds between glow updates (when
// increasing/decreasing).

const NSTimeInterval kGlowUpdateInterval = 0.025;

const CGFloat kTearDistance = 36.0f;
const NSTimeInterval kTearDuration = 0.333;

// This is used to judge whether the mouse has moved during rapid closure; if it
// has moved less than the threshold, we want to close the tab.

const CGFloat kRapidCloseDistance = 2.5f;

#pragma mark - Private

@interface AVTTabView()

- (void) resetLastGlowUpdateTime;
- (NSTimeInterval) timeElapsedSinceLastGlowUpdate;
- (void) adjustGlowValue;
- (NSBezierPath*) bezierPathForRect: (NSRect) rect;

@end

#pragma mark - Implementation

@implementation AVTTabView

- (id) initWithFrame: (NSRect) frame
{
//    NSLog( @"-[AVTTabView initWithFrame: %@]", NSStringFromRect( frame ) );

    self = [super initWithFrame: frame];
    if( self != nil )
    {
        self.showsDivider = NO;
    }

    return self;
}

- (void) dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self];

    [_closeTrackingArea release];

    [super dealloc];
}

- (void) awakeFromNib
{
    self.showsDivider = NO;
}

// Overridden so that mouse clicks come to this view (the parent of the hierarchy) first.
// We want to handle clicks and drags in this class and leave the background button for display purposes only.

- (BOOL) acceptsFirstMouse: (NSEvent*) theEvent
{
    return YES;
}

// Called to obtain the context menu for when the user hits the right mouse button (or control-clicks). (Note that -rightMouseDown:
// is *not* called for control-click.)

- (NSMenu*) menu
{
    NSMenu* foundMenu = nil;

    if( ![self isClosing] )
    {
        // Sheets, being window-modal, should block contextual menus. For some reason
        // they do not. Disallow them ourselves.

        if( ![self.window attachedSheet] )
            foundMenu = [self.tabController menu];
    }

    return foundMenu;
}

- (void) mouseEntered: (NSEvent*) theEvent
{
    self.mouseInside = YES;
    [self resetLastGlowUpdateTime];
    [self adjustGlowValue];
}

- (void) mouseMoved: (NSEvent*) theEvent
{
    self.hoverPoint = [self convertPoint: theEvent.locationInWindow fromView: nil];
    [self setNeedsDisplay: YES];
}

- (void) mouseExited: (NSEvent*) theEvent
{
    self.mouseInside = NO;
    self.hoverHoldEndTime = [NSDate timeIntervalSinceReferenceDate] + kHoverHoldDuration;
    [self resetLastGlowUpdateTime];
    [self adjustGlowValue];
}

// Determines which view a click in our frame actually hit. It's either this view or our child close button.

- (NSView*) hitTest: (NSPoint) aPoint
{
    NSPoint viewPoint = [self convertPoint: aPoint fromView: self.superview];
    NSRect frame = self.frame;

    // Reduce the width of the hit rect slightly to remove the overlap between adjacent tabs.  The drawing code in TabCell has the top
    // corners of the tab inset by height*2/3, so we inset by half of that here.  This doesn't completely eliminate the overlap, but it
    // works well enough.

    NSView* hitView = nil;
    NSRect hitRect = NSInsetRect( frame, frame.size.height / 3.0f, 0 );
    if( ![self.closeButton isHidden] )
    {
        if( NSPointInRect( viewPoint, self.closeButton.frame ) )
            hitView = self.closeButton;
    }

    if( hitView == nil && NSPointInRect( aPoint, hitRect ) )
        hitView = self;

    return hitView;
}

// Returns |YES| if this tab can be torn away into a new window.

- (BOOL) canBeDragged
{
    BOOL canBe = NO;

    if( ![self isClosing] )
    {
        NSWindowController* controller = [self.sourceWindow windowController];
        if( [controller isKindOfClass: [AVTTabWindowController class]] )
        {
            AVTTabWindowController* realController = (AVTTabWindowController*)controller;
            canBe = [realController isTabDraggable: self];
        }
        else
        {
            canBe = YES;
        }
    }

    return canBe;
}

// Returns an array of controllers that could be a drop target, ordered front to back. It has to be of the appropriate class,
// and visible (obviously). Note that the window cannot be a target for itself.

- (NSArray*) dropTargetsForController: (AVTTabWindowController*) dragController
{
    NSMutableArray* targets = [NSMutableArray array];
    NSWindow* dragWindow = [dragController window];
    for( NSWindow* window in [NSApp orderedWindows] )
    {
        if( window == dragWindow )
            continue;
        if( ![window isVisible] )
            continue;

        // Skip windows on the wrong space.

        if( [window respondsToSelector: @selector( isOnActiveSpace )] )
        {
            if( ![window performSelector: @selector( isOnActiveSpace )] )
                continue;
        }

        NSWindowController* controller = [window windowController];
        if( [controller isKindOfClass: [AVTTabWindowController class]] )
        {
            AVTTabWindowController* realController = (AVTTabWindowController*)controller;
            if( [realController canReceiveFrom: dragController] )
                [targets addObject: controller];
        }
    }
    return targets;
}

// Call to clear out transient weak references we hold during drags.

- (void) resetDragControllers
{
    self.draggedController = nil;
    self.dragWindow = nil;
    self.dragOverlay = nil;
    self.sourceController = nil;
    self.sourceWindow = nil;
    self.targetController = nil;
}

// Sets whether the window background should be visible or invisible when dragging a tab. The background should be invisible when the mouse is over a
// potential drop target for the tab (the tab strip). It should be visible when there's no drop target so the window looks more fully realized and ready to
// become a stand-alone window.

- (void) setWindowBackgroundVisibility: (BOOL) shouldBeVisible
{
    if( self.chromeIsVisible != shouldBeVisible )
    {
        // There appears to be a race-condition in CoreAnimation where if we use animators to set the alpha values, we can't guarantee that we cancel them.
        // This has the side effect of sometimes leaving the dragged window translucent or invisible. As a result, don't animate the alpha change.

        [[self.draggedController overlayWindow] setAlphaValue: 1.0];
        if( self.targetController )
        {
            [self.dragWindow setAlphaValue: 0.0];
            [[self.draggedController overlayWindow] setHasShadow: YES];
            [[self.targetController window] makeMainWindow];
        }
        else
        {
            [self.dragWindow setAlphaValue: 0.5];
            [[self.draggedController overlayWindow] setHasShadow: NO];
            [[self.draggedController window] makeMainWindow];
        }
        self.chromeIsVisible = shouldBeVisible;
    }
}

// Handle clicks and drags in this button. We get here because we have overridden acceptsFirstMouse: and the click is within our bounds.

- (void) mouseDown: (NSEvent*) theEvent
{
    if( [self isClosing] )
        return;

    NSPoint downLocation = [theEvent locationInWindow];

    // Record the state of the close button here, because selecting the tab will unhide it.

    BOOL closeButtonActive = [self.closeButton isHidden] ? NO : YES;

    // During the tab closure animation (in particular, during rapid tab closure), we may get incorrectly hit with a mouse down.
    // If it should have gone to the close button, we send it there -- it should then track the mouse, so we
    // don't have to worry about mouse ups.

    if( closeButtonActive && [self.tabController inRapidClosureMode] )
    {
        NSPoint hitLocation = [[self superview] convertPoint: downLocation
                                                    fromView: nil];
        if( [self hitTest: hitLocation] == self.closeButton )
        {
            [self.closeButton mouseDown: theEvent];
            return;
        }
    }

    // Fire the action to select the tab.

    if( [[self.tabController target] respondsToSelector: [self.tabController action]] )
        [[self.tabController target] performSelector: [self.tabController action] withObject: self];

    [self resetDragControllers];

    // Resolve overlay back to original window.

    self.sourceWindow = self.window;
    if( [self.sourceWindow isKindOfClass: [NSPanel class]] )
    {
        self.sourceWindow = [self.sourceWindow parentWindow];
    }

    self.sourceWindowFrame = self.sourceWindow.frame;
    self.sourceTabFrame = self.frame;
    self.sourceController = self.sourceWindow.windowController;
    self.tabWasDragged = NO;
    self.tearTime = 0.0;
    self.draggingWithinTabWell = YES;
    self.chromeIsVisible = NO;

    // If there's more than one potential window to be a drop target, we want to treat a drag of a tab just like dragging around a tab that's already
    // detached. Note that unit tests might have |-numberOfTabs| reporting zero since the model won't be fully hooked up. We need to be prepared for that
    // and not send them into the "magnetic" codepath.

    NSArray* targets = [self dropTargetsForController: self.sourceController];
    self.moveWindowOnDrag = (self.sourceController.numberOfTabs < 2 && ![targets count]) || ![self canBeDragged] || ![self.sourceController tabDraggingAllowed];

    // If we are dragging a tab, a window with a single tab should immediately snap off and not drag within the tab strip.

    if( !self.moveWindowOnDrag )
        self.draggingWithinTabWell = self.sourceController.numberOfTabs > 1;

    if( !self.draggingWithinTabWell )
    {
        [self.sourceController willStartTearingTab];
    }

    self.dragOrigin = [NSEvent mouseLocation];

    // If the tab gets torn off, the tab controller will be removed from the tab strip and then deallocated. This will also result in *us* being
    // deallocated. Both these are bad, so we prevent this by retaining the controller.

    NSArray* retainedArray = [[NSArray alloc] initWithObjects: self.tabController, nil];    // Retain self.tabController in a way Clang is OK with.
    {
        // Because we move views between windows, we need to handle the event loop ourselves. Ideally we should use the standard event loop.

        while( 1 )
        {
            theEvent = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                                          untilDate: [NSDate distantFuture]
                                             inMode: NSDefaultRunLoopMode dequeue: YES];
            NSEventType type = theEvent.type;
            if( type == NSLeftMouseDragged )
            {
                [self mouseDragged: theEvent];
            }
            else if( type == NSLeftMouseUp )
            {
                NSPoint upLocation = [theEvent locationInWindow];
                CGFloat dx = upLocation.x - downLocation.x;
                CGFloat dy = upLocation.y - downLocation.y;

                // During rapid tab closure (mashing tab close buttons), we may get hit with a mouse down. As long as the mouse up is over the close button,
                // and the mouse hasn't moved too much, we close the tab.

                if( closeButtonActive && (dx * dx + dy * dy) <= kRapidCloseDistance * kRapidCloseDistance && [self.tabController inRapidClosureMode] )
                {
                    NSPoint hitLocation = [self.superview convertPoint: theEvent.locationInWindow fromView: nil];
                    if( [self hitTest: hitLocation] == self.closeButton )
                    {
                        [self.tabController closeTab: self];
                        break;
                    }
                }

                [self mouseUp: theEvent];
                break;
            }
            else
            {
                // TODO(viettrungluu): [crbug.com/23830] We can receive right-mouse-ups (and maybe even others?) for reasons I don't understand. So we
                // explicitly check for both events we're expecting, and log others. We should figure out what's going on.

                NSLog( @"Spurious event received of type %d", (int)type );
            }
        }
    }
    [retainedArray release];
}

- (void) mouseDragged: (NSEvent*) theEvent
{
    // Special-case this to keep the logic below simpler.

    if( self.moveWindowOnDrag )
    {
        if( [self.sourceController windowMovementAllowed] )
        {
            NSPoint thisPoint = [NSEvent mouseLocation];
            NSPoint origin = self.sourceWindowFrame.origin;
            origin.x += (thisPoint.x - self.dragOrigin.x);
            origin.y += (thisPoint.y - self.dragOrigin.y);
            self.sourceWindow.frameOrigin = NSMakePoint( origin.x, origin.y );
        }  // else do nothing.

        return;
    }

    // First, go through the magnetic drag cycle. We break out of this if
    // "stretchiness" ever exceeds a set amount.

    self.tabWasDragged = YES;

    if( self.draggingWithinTabWell )
    {
        NSPoint thisPoint = [NSEvent mouseLocation];
        CGFloat stretchiness = thisPoint.y - self.dragOrigin.y;
        stretchiness = copysign( sqrtf( fabs( stretchiness ) ) / sqrtf( kTearDistance ),
                                 stretchiness ) / 2.0;
        CGFloat offset = thisPoint.x - self.dragOrigin.x;
        if( fabsf( offset ) > 100 )
            stretchiness = 0;
        [self.sourceController insertPlaceholderForTab: self
                                                 frame: NSOffsetRect( self.sourceTabFrame, offset, 0 )
                                         yStretchiness: stretchiness];

        // Check that we haven't pulled the tab too far to start a drag. This can include either pulling it too far down, or off the side of the tab
        // strip that would cause it to no longer be fully visible.

        BOOL stillVisible = [self.sourceController isTabFullyVisible: self];
        CGFloat tearForce = fabs( thisPoint.y - self.dragOrigin.y );
        if( [self.sourceController tabTearingAllowed] && (tearForce > kTearDistance || !stillVisible) )
        {
            self.draggingWithinTabWell = NO;
            [self.sourceController willStartTearingTab];

            // When you finally leave the strip, we treat that as the origin.

            self.dragOrigin = (NSPoint){ thisPoint.x, self.dragOrigin.y };
        }
        else
        {
            // Still dragging within the tab strip, wait for the next drag event.

            return;
        }
    }

    // Do not start dragging until the user has "torn" the tab off by moving more than 3 pixels.

    NSPoint thisPoint = [NSEvent mouseLocation];

    // Iterate over possible targets checking for the one the mouse is in. If the tab is just in the frame, bring the window forward to make it
    // easier to drop something there. If it's in the tab strip, set the new target so that it pops into that window. We can't cache this because we
    // need the z-order to be correct.

    NSArray* targets = [self dropTargetsForController: self.draggedController];
    AVTTabWindowController* newTarget = nil;
    for( AVTTabWindowController* target in targets )
    {
        NSRect windowFrame = target.window.frame;
        if( NSPointInRect( thisPoint, windowFrame ) )
        {
            [[target window] orderFront: self];
            NSRect tabWellFrame = target.tabWellView.frame;
            tabWellFrame.origin = [target.window convertBaseToScreen: tabWellFrame.origin];
            if( NSPointInRect( thisPoint, tabWellFrame ) )
            {
                newTarget = target;
            }
            break;
        }
    }

    // If we're now targeting a new window, re-layout the tabs in the old target and reset how long we've been hovering over this new one.

    if( self.targetController != newTarget )
    {
        [self.targetController removePlaceholder];
        self.targetController = newTarget;
        if( !newTarget )
        {
            self.tearTime = [NSDate timeIntervalSinceReferenceDate];
            self.tearOrigin = [self.dragWindow frame].origin;
        }
    }

    // Create or identify the dragged controller.

    if( !self.draggedController )
    {
        // Get rid of any placeholder remaining in the original source window.

        [self.sourceController removePlaceholder];

        // Detach from the current window and put it in a new window. If there are no more tabs remaining after detaching, the source window is about to
        // go away (it's been autoreleased) so we need to ensure we don't reference it any more. In that case the new controller becomes our source
        // controller.

        self.draggedController = [self.sourceController detachTabToNewWindow: self];
        self.dragWindow = [self.draggedController window];
        [self.dragWindow setAlphaValue: 0.0];
        if( ![self.sourceController hasLiveTabs] )
        {
            self.sourceController = self.draggedController;
            self.sourceWindow = self.dragWindow;
        }

        // If dragging the tab only moves the current window, do not show overlay so that sheets stay on top of the window.
        // Bring the target window to the front and make sure it has a border.

        [self.dragWindow setLevel: NSFloatingWindowLevel];
        [self.dragWindow setHasShadow: YES];
        [self.dragWindow orderFront: nil];
        [self.dragWindow makeMainWindow];
        [self.draggedController showOverlay];
        self.dragOverlay = [self.draggedController overlayWindow];

        // Force the new tab button to be hidden. We'll reset it on mouse up.

        self.draggedController.didShowNewTabButtonBeforeTemporalAction = self.draggedController.showsAddTabButton;
        self.draggedController.showsAddTabButton = NO;
        self.tearTime = [NSDate timeIntervalSinceReferenceDate];
        self.tearOrigin = self.sourceWindowFrame.origin;
    }

    // TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by
    // some weird circumstance that doesn't first go through mouseDown:. We
    // really shouldn't go any farther.

    if( self.draggedController && self.sourceController )
    {
        // When the user first tears off the window, we want slide the window to the current mouse location (to reduce the jarring appearance).
        // We do this by calling ourselves back with additional mouseDragged calls (not actual events). |tearProgress| is a normalized measure of
        // how far through this  tear "animation" (of length kTearDuration) we are and has values [0..1].
        // We use sqrt() so the animation is non-linear (slow down near the end point).

        NSTimeInterval tearProgress = [NSDate timeIntervalSinceReferenceDate] - self.tearTime;
        tearProgress /= kTearDuration;  // Normalize.
        tearProgress = sqrtf( MAX( MIN( tearProgress, 1.0 ), 0.0 ) );

        // Move the dragged window to the right place on the screen.

        NSPoint origin = self.sourceWindowFrame.origin;
        origin.x += (thisPoint.x - self.dragOrigin.x);
        origin.y += (thisPoint.y - self.dragOrigin.y);

        if( tearProgress < 1 )
        {
            // If the tear animation is not complete, call back to ourself with the same event to animate even if the mouse isn't moving. We need to make
            // sure these get cancelled in mouseUp:.

            [NSObject cancelPreviousPerformRequestsWithTarget: self];
            [self performSelector: @selector( mouseDragged: )
                       withObject: theEvent
                       afterDelay: 1.0f / 30.0f];

            // Set the current window origin based on how far we've progressed through the tear animation.

            origin.x = (1 - tearProgress) * self.tearOrigin.x + tearProgress * origin.x;
            origin.y = (1 - tearProgress) * self.tearOrigin.y + tearProgress * origin.y;
        }

        if( self.targetController )
        {
            // In order to "snap" two windows of different sizes together at their toolbar, we can't just use the origin of the target frame.
            // We also have  to take into consideration the difference in height.

            NSRect targetFrame = self.targetController.window.frame;
            NSRect sourceFrame = self.dragWindow.frame;
            origin.y = NSMinY( targetFrame ) + (NSHeight( targetFrame ) - NSHeight( sourceFrame ) );
        }
        [self.dragWindow setFrameOrigin: NSMakePoint( origin.x, origin.y )];

        // If we're not hovering over any window, make the window fully opaque. Otherwise, find where the tab might be dropped and insert
        // a placeholder so it appears like it's part of that window.

        if( self.targetController )
        {
            if( ![self.targetController.window isKeyWindow] )
            {
                [self.targetController.window orderFront: nil];
            }

            // Compute where placeholder should go and insert it into the destination tab strip.

            AVTTabView* draggedTabView = (AVTTabView*)[self.draggedController selectedTabView];
            NSRect tabFrame = draggedTabView.frame;
            tabFrame.origin = [self.dragWindow convertBaseToScreen: tabFrame.origin];
            tabFrame.origin = [self.targetController.window convertScreenToBase: tabFrame.origin];
            tabFrame = [self.targetController.tabWellView  convertRect: tabFrame fromView: nil];
            [self.targetController insertPlaceholderForTab: self frame: tabFrame yStretchiness: 0];
            [self.targetController layoutTabs];
        }
        else
        {
            [self.dragWindow makeKeyAndOrderFront: nil];
        }

        // Adjust the visibility of the window background. If there is a drop target, we want to hide the window background so the tab stands out for
        // positioning. If not, we want to show it so it looks like a new window will be realized.

        BOOL chromeShouldBeVisible = self.targetController == nil;
        [self setWindowBackgroundVisibility: chromeShouldBeVisible];
    }
}

- (void) mouseUp: (NSEvent*) theEvent
{
    // The drag/click is done. If the user dragged the mouse, finalize the drag and clean up.
    // Special-case this to keep the logic below simpler.

    if( !self.moveWindowOnDrag )
    {
        // Cancel any delayed -mouseDragged: requests that may still be pending.

        [NSObject cancelPreviousPerformRequestsWithTarget: self];

        // TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by some weird circumstance that doesn't first go
        // through mouseDown:. We really shouldn't go any farther.

        if( self.sourceController )
        {
            // We are now free to re-display the new tab button in the window we're dragging. It will show when the next call to
            // -layoutTabs (which happens indirectly by several of the calls below, such as removing the placeholder).

            self.draggedController.showsAddTabButton = self.draggedController.didShowNewTabButtonBeforeTemporalAction;

            if( self.draggingWithinTabWell )
            {
                if( self.tabWasDragged )
                {
                    // Move tab to new location.

                    NSAssert( self.sourceController.numberOfTabs, @"Hey, you don't have any tabs!" );
                    [self.sourceController moveTabView: [self.sourceController selectedTabView] fromController: nil];
                }
            }
            else
            {
                // call willEndTearingTab before potentially moving the tab so the same controller which got willStartTearingTab can reference the tab.

                [self.draggedController willEndTearingTab];
                if( self.targetController )
                {
                    // Move between windows. If |targetController| is nil, we're not dropping into any existing window.

                    NSView* draggedTabView = [self.draggedController selectedTabView];
                    [self.targetController moveTabView: draggedTabView fromController: self.draggedController];

                    // Force redraw to avoid flashes of old content before returning to event loop.

                    [self.targetController.window display];
                    [self.targetController showWindow: nil];
                    [self.targetController didEndTearingTab];
                }
                else
                {
                    // Only move the window around on screen. Make sure it's set back to normal state (fully opaque, has shadow, has key, etc).

                    [self.draggedController removeOverlay];

                    // Don't want to re-show the window if it was closed during the drag.

                    if( [self.dragWindow isVisible] )
                    {
                        [self.dragWindow setAlphaValue: 1.0];
                        [self.dragOverlay setHasShadow: NO];
                        [self.dragWindow setHasShadow: YES];
                        [self.dragWindow makeKeyAndOrderFront: nil];
                    }
                    [[self.draggedController window] setLevel: NSNormalWindowLevel];
                    [self.draggedController removePlaceholder];
                    [self.draggedController didEndTearingTab];
                }
            }
            [self.sourceController removePlaceholder];
            self.chromeIsVisible = YES;

            [self resetDragControllers];
        }
    }
}

- (void) otherMouseUp: (NSEvent*) theEvent
{
    if( [self isClosing] == NO )
    {
        // Support middle-click-to-close.

        if( [theEvent buttonNumber] == 2 )
        {
            // |-hitTest:| takes a location in the superview's coordinates.

            NSPoint upLocation = [self.superview convertPoint: theEvent.locationInWindow fromView: nil];

            // If the mouse up occurred in our view or over the close button, then close.

            if( [self hitTest: upLocation] )
                [self.tabController closeTab: self];
        }
    }
}

- (void) drawRect: (NSRect) dirtyRect
{
    // If this tab is phantom, do not draw the tab background itself. The only UI
    // element that will represent this tab is the favicon.

    NSGraphicsContext* context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    [context setPatternPhase: [self.window themePatternPhase]];

    NSRect rect = self.bounds;
    NSBezierPath* path = [self bezierPathForRect: rect];

    BOOL selected = self.state;

    // Don't draw the window/tab bar background when selected, since the tab background overlay drawn over it (see below) will be fully opaque.

    if( !selected )
    {
        // Use the window's background color rather than |[NSColor windowBackgroundColor]|, which gets confused by the fullscreen
        // window. (The result is the same for normal, non-fullscreen windows.)

        [[self.window backgroundColor] set];
        [path fill];
        [[NSColor colorWithCalibratedWhite: 1.0 alpha: 0.3] set];
        [path fill];
    }

    [context saveGraphicsState];
    [path addClip];

    // Use the same overlay for the selected state and for hover and alert glows; for the selected state, it's fully opaque.

    if( selected || self.hoverAlpha > 0 || self.alertAlpha > 0 )
    {
        // Draw the selected background / glow overlay.

        [context saveGraphicsState];
        CGContextRef cgContext = [context graphicsPort];
        CGContextBeginTransparencyLayer( cgContext, 0 );

        if( !selected )
        {
            // The alert glow overlay is like the selected state but at most at most 80% opaque. The hover glow brings up the overlay's opacity at most 50%.

            CGFloat backgroundAlpha = 0.8 * self.alertAlpha;
            backgroundAlpha += (1 - backgroundAlpha) * 0.5 * self.hoverAlpha;
            CGContextSetAlpha( cgContext, backgroundAlpha );
        }
        [path addClip];
        [context saveGraphicsState];
        [super drawBackground];
        [context restoreGraphicsState];

        // Draw a mouse hover gradient for the default themes.

        if( !selected && self.hoverAlpha > 0 )
        {
            NSGradient* glow =  [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0 alpha: 1.0 * self.hoverAlpha]
                                                              endingColor: [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.0]];

            NSPoint point = self.hoverPoint;
            point.y = NSHeight( rect );
            [glow drawFromCenter: point
                          radius: 0.0
                        toCenter: point
                          radius: NSWidth( rect ) / 3.0
                         options: NSGradientDrawsBeforeStartingLocation];

            [glow drawInBezierPath: path relativeCenterPosition: self.hoverPoint];
            [glow release];
        }

        CGContextEndTransparencyLayer( cgContext );
        [context restoreGraphicsState];
    }

    BOOL active = [self.window isKeyWindow] || [self.window isMainWindow];
    CGFloat borderAlpha = selected ? (active ? 0.3 : 0.2) : 0.2;

    // TODO: cache colors

    NSColor* borderColor = [NSColor colorWithDeviceWhite: 0.0 alpha: borderAlpha];
    NSColor* highlightColor = [NSColor colorWithCalibratedWhite: 0xf7 / 255.0 alpha: 1.0];

    // Draw the top inner highlight within the currently selected tab if using
    // the default theme.

    if( selected )
    {
        NSAffineTransform* highlightTransform = [NSAffineTransform transform];
        [highlightTransform translateXBy: 1.0 yBy: -1.0];
        NSBezierPath* highlightPath = [path copy];
        [highlightPath transformUsingAffineTransform: highlightTransform];
        [highlightColor setStroke];
        [highlightPath setLineWidth: 1.0];
        [highlightPath stroke];
        highlightTransform = [NSAffineTransform transform];
        [highlightTransform translateXBy: -2.0 yBy: 0.0];
        [highlightPath transformUsingAffineTransform: highlightTransform];
        [highlightPath stroke];
        [highlightPath release];
    }

    [context restoreGraphicsState];

    // Draw the top stroke.

    [context saveGraphicsState];
    [borderColor set];
    path.lineWidth = 1.0f;
    [path stroke];
    [context restoreGraphicsState];

    // Mimic the tab strip's bottom border, which consists of a dark border
    // and light highlight.

    if( !selected )
    {
        [path addClip];
        NSRect borderRect = rect;
        borderRect.origin.y = 1;
        borderRect.size.height = 1;
        [borderColor set];
        NSRectFillUsingOperation( borderRect, NSCompositeSourceOver );

        borderRect.origin.y = 0;
        [highlightColor set];
        NSRectFillUsingOperation( borderRect, NSCompositeSourceOver );
    }

    [context restoreGraphicsState];
}

- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    if( self.window )
    {
        [self.tabController updateTitleColor];
    }
}

- (void) setClosing: (BOOL) closing
{
    _closing = closing;  // Safe because the property is nonatomic.

    // When closing, ensure clicks to the close button go nowhere.

    if( closing )
    {
        [self.closeButton setTarget: nil];
        [self.closeButton setAction: nil];
    }
}

- (void) startAlert
{
    // Do not start a new alert while already alerting or while in a decay cycle.

    if( self.alertState == eAlertNone )
    {
        self.alertState = eAlertRising;
        [self resetLastGlowUpdateTime];
        [self adjustGlowValue];
    }
}

- (void) cancelAlert
{
    if( self.alertState != eAlertNone )
    {
        self.alertState = eAlertFalling;
        self.alertHoldEndTime = [NSDate timeIntervalSinceReferenceDate] + kGlowUpdateInterval;
        [self resetLastGlowUpdateTime];
        [self adjustGlowValue];
    }
}

- (void) setTrackingEnabled: (BOOL) enabled
{
    [self.closeButton setTrackingEnabled: enabled];
}

- (BOOL) accessibilityIsIgnored
{
    return NO;
}

- (NSArray*) accessibilityActionNames
{
    NSArray* parentActions = [super accessibilityActionNames];

    return [parentActions arrayByAddingObject: NSAccessibilityPressAction];
}

- (NSArray*) accessibilityAttributeNames
{
    NSMutableArray* attributes = [[super accessibilityAttributeNames] mutableCopy];
    [attributes addObject: NSAccessibilityTitleAttribute];
    [attributes addObject: NSAccessibilityEnabledAttribute];

    return [attributes autorelease];
}

- (BOOL) accessibilityIsAttributeSettable: (NSString*) attribute
{
    if( [attribute isEqual: NSAccessibilityTitleAttribute] )
        return NO;

    if( [attribute isEqual: NSAccessibilityEnabledAttribute] )
        return NO;

    return [super accessibilityIsAttributeSettable: attribute];
}

- (id) accessibilityAttributeValue: (NSString*) attribute
{
    if( [attribute isEqual: NSAccessibilityRoleAttribute] )
        return NSAccessibilityButtonRole;

    if( [attribute isEqual: NSAccessibilityTitleAttribute] )
        return [self.tabController title];

    if( [attribute isEqual: NSAccessibilityEnabledAttribute] )
        return [NSNumber numberWithBool: YES];

    if( [attribute isEqual: NSAccessibilityChildrenAttribute] )
    {
        // The subviews (icon and text) are clutter; filter out everything but
        // useful controls.
        NSArray* children = [super accessibilityAttributeValue: attribute];
        NSMutableArray* okChildren = [NSMutableArray array];
        for( id child in children )
        {
            if( [child isKindOfClass: [NSButtonCell class]] )
                [okChildren addObject: child];
        }

        return okChildren;
    }

    return [super accessibilityAttributeValue: attribute];
}

- (void) resetLastGlowUpdateTime
{
    self.lastGlowUpdate = [NSDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval) timeElapsedSinceLastGlowUpdate
{
    return [NSDate timeIntervalSinceReferenceDate] - self.lastGlowUpdate;
}

- (void) adjustGlowValue
{
    // A time interval long enough to represent no update.
    const NSTimeInterval kNoUpdate = 1000000;

    // Time until next update for either glow.
    NSTimeInterval nextUpdate = kNoUpdate;

    NSTimeInterval elapsed = [self timeElapsedSinceLastGlowUpdate];
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

    // TODO(viettrungluu): <http://crbug.com/30617> -- split off the stuff below
    // into a pure function and add a unit test.

    if( self.isMouseInside )
    {
        // Increase hover glow until it's 1.
        if( self.hoverAlpha < 1 )
        {
            self.hoverAlpha = MIN( self.hoverAlpha + elapsed / kHoverShowDuration, 1 );
            nextUpdate = MIN( kGlowUpdateInterval, nextUpdate );
        }  // Else already 1 (no update needed).
    }
    else
    {
        if( currentTime >= self.hoverHoldEndTime )
        {
            // No longer holding, so decrease hover glow until it's 0.
            if( self.hoverAlpha > 0 )
            {
                self.hoverAlpha = MAX( self.hoverAlpha - elapsed / kHoverHideDuration, 0 );
                nextUpdate = MIN( kGlowUpdateInterval, nextUpdate );
            }  // Else already 0 (no update needed).
        }
        else
        {
            // Schedule update for end of hold time.
            nextUpdate = MIN( self.hoverHoldEndTime - currentTime, nextUpdate );
        }
    }

    if( self.alertState == eAlertRising )
    {
        // Increase alert glow until it's 1 ...

        self.alertAlpha = MIN( self.alertAlpha + elapsed / kAlertShowDuration, 1 );

        // ... and having reached 1, switch to holding.

        if( self.alertAlpha >= 1 )
        {
            self.alertState = eAlertHolding;
            self.alertHoldEndTime = currentTime + kAlertHoldDuration;
            nextUpdate = MIN( kAlertHoldDuration, nextUpdate );
        }
        else
        {
            nextUpdate = MIN( kGlowUpdateInterval, nextUpdate );
        }
    }
    else if( self.alertState != eAlertNone )
    {
        if( self.alertAlpha > 0 )
        {
            if( currentTime >= self.alertHoldEndTime )
            {
                // Stop holding, then decrease alert glow (until it's 0).
                if( self.alertState == eAlertHolding )
                {
                    self.alertState = eAlertFalling;
                    nextUpdate = MIN( kGlowUpdateInterval, nextUpdate );
                }
                else
                {
                    self.alertAlpha = MAX( self.alertAlpha - elapsed / kAlertHideDuration, 0 );
                    nextUpdate = MIN( kGlowUpdateInterval, nextUpdate );
                }
            }
            else
            {
                // Schedule update for end of hold time.

                nextUpdate = MIN( self.alertHoldEndTime - currentTime, nextUpdate );
            }
        }
        else
        {
            // Done the alert decay cycle.

            self.alertState = eAlertNone;
        }
    }

    if( nextUpdate < kNoUpdate )
        [self performSelector: _cmd withObject: nil afterDelay: nextUpdate];

    [self resetLastGlowUpdateTime];
    [self setNeedsDisplay: YES];
}

// Returns the bezier path used to draw the tab given the bounds to draw it in.

- (NSBezierPath*) bezierPathForRect: (NSRect) rect
{
    // Outset by 0.5 in order to draw on pixels rather than on borders (which
    // would cause blurry pixels). Subtract 1px of height to compensate, otherwise
    // clipping will occur.

    rect = NSInsetRect( rect, -0.5, -0.5 );
    rect.size.height -= 1.0;

    NSPoint bottomLeft = NSMakePoint( NSMinX( rect ), NSMinY( rect ) + 2 );
    NSPoint bottomRight = NSMakePoint( NSMaxX( rect ), NSMinY( rect ) + 2 );
    NSPoint topRight = NSMakePoint( NSMaxX( rect ) - kInsetMultiplier * NSHeight( rect ), NSMaxY( rect ) );
    NSPoint topLeft = NSMakePoint( NSMinX( rect )  + kInsetMultiplier * NSHeight( rect ), NSMaxY( rect ) );

    CGFloat baseControlPointOutset = NSHeight( rect ) * kControlPoint1Multiplier;
    CGFloat bottomControlPointInset = NSHeight( rect ) * kControlPoint2Multiplier;

    // Outset many of these values by 1 to cause the fill to bleed outside the
    // clip area.

    NSBezierPath* path = [NSBezierPath bezierPath];
    [path moveToPoint: NSMakePoint( bottomLeft.x - 1, bottomLeft.y - 2 )];
    [path lineToPoint: NSMakePoint( bottomLeft.x - 1, bottomLeft.y )];
    [path lineToPoint: bottomLeft];
    [path curveToPoint: topLeft
         controlPoint1: NSMakePoint( bottomLeft.x + baseControlPointOutset, bottomLeft.y )
         controlPoint2: NSMakePoint( topLeft.x - bottomControlPointInset, topLeft.y )];
    [path lineToPoint: topRight];
    [path curveToPoint: bottomRight
         controlPoint1: NSMakePoint( topRight.x + bottomControlPointInset, topRight.y )
         controlPoint2: NSMakePoint( bottomRight.x - baseControlPointOutset, bottomRight.y )];
    [path lineToPoint: NSMakePoint( bottomRight.x + 1, bottomRight.y )];
    [path lineToPoint: NSMakePoint( bottomRight.x + 1, bottomRight.y - 2 )];
    
    return path;
}

@end
