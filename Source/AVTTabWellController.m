//
//  AVTTabbedWindows - AVTTabWellController.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabWellController.h"

#import "AVTContainer.h"
#import "AVTContainerCommands.h"
#import "AVTFastResizeView.h"
#import "AVTNewTabButton.h"
#import "AVTTabController.h"
#import "AVTTabDocument.h"
#import "AVTTabDocumentController.h"
#import "AVTTabView.h"
#import "AVTTabWellModel.h"
#import "AVTTabWellView.h"
#import "AVTThrobberView.h"
#import "NSAnimationContext+Duration.h"

// The images names used for different states of the new tab button.

NSImage* sAddTabHoverImage = nil;
NSImage* sAddTabImage = nil;
NSImage* sAddTabPressedImage = nil;

// Image used to display default icon (when document.hasIcon && !document.icon)

NSImage* sDefaultIconImage = nil;

static NSString* const kTabWellNumberOfTabsChanged = @"kTabWellNumberOfTabsChanged";

// A delegate, owned by the CAAnimation system, that is alerted when the animation to close a tab is completed. Calls back to the given tab well
// to let it know that |controller| is ready to be removed from the model. Since we only maintain weak references, the tab well must call -invalidate:
// to prevent the use of dangling pointers.

@interface TabCloseAnimationDelegate : NSObject

// Will tell |well| when the animation for |controller|'s view has completed. These should not be nil, and will not be retained.

- (id) initWithTabWell: (AVTTabWellController*) well tabController: (AVTTabController*) controller;

// Invalidates this object so that no further calls will be made to |well|.  This should be called when |well| is released, to
// prevent attempts to call into the released object.

- (void) invalidate;

// CAAnimation delegate method

- (void) animationDidStop: (CAAnimation*) animation finished: (BOOL) finished;

@property (nonatomic, assign) AVTTabWellController* well;
@property (nonatomic, assign) AVTTabController* controller;

@end

// A simple view class that prevents the Window Server from dragging the area behind tabs. Sometimes core animation confuses it.
// Unfortunately, it can also falsely pick up clicks during rapid tab closure, so we have to account for that.

@interface AVTTabWellControllerDragBlockingView : NSView

- (id) initWithFrame: (NSRect) frameRect controller: (AVTTabWellController*) controller;

@property (nonatomic, assign) AVTTabWellController* controller;

@end

// In general, there is a one-to-one correspondence between TabControllers, TabViews, TabDocumentControllers, and the
// AVTTabDocument in the TabWellModel. In the steady-state, the indices line up so an index coming from the model is
// directly mapped to the same index in the parallel arrays holding our views and controllers. This is also true when new
// tabs are created (even though there is a small period of animation) because the tab is present in the model while the
// AVTTabView is animating into place. As a result, nothing special need be done to handle "new tab" animation.
//
// This all goes out the window with the "close tab" animation. The animation kicks off in|-tabDetachedWithDocument:atIndex:|
// with the notification that the tab has been removed from the model. The simplest solution at this point would be to remove
// the views and controllers as well, however once the AVTTabView is removed from the view list, the tab z-order code takes
// care of removing it from the tab well and we'll get no animation. That means if there is to be any visible animation, the
// AVTTabView needs to stay around until its animation is complete. In order to maintain consistency among the internal parallel
// arrays, this means all structures are kept around until the animation completes. At this point, though, the model and our
// internal structures are out of sync: the indices no longer line up. As a result, there is a concept of a "model index" which
// represents an index valid in the TabWellModel. During steady-state, the "model index" is just the same index as our parallel
// arrays (as above), but during tab close animations, it is different, offset by the number of tabs preceding the index which
// are undergoing tab closing animation. As a result, the caller needs to be careful to use the available conversion routines
// when accessing the internal parallel arrays (e.g., -indexFromModelIndex:). Care also needs to be taken during tab layout to
// ignore closing tabs in the total width calculations and in individual tab positioning (to avoid moving them right back to
/// where they were).
//
// In order to prevent actions being taken on tabs which are closing, the tab itself gets marked as such so it no longer
// will send back its select action or allow itself to be dragged. In addition, drags on the tab well as a whole are
// disabled while there are tabs closing.

@interface AVTTabWellController()

- (void) layoutTabsWithAnimation: (BOOL) animate regenerateSubviews: (BOOL) doUpdate;
- (void) regenerateSubviewList;

- (NSInteger) numberOfOpenTabs;
- (NSInteger) numberOfOpenMiniTabs;
- (NSInteger) numberOfOpenNonMiniTabs;

- (void) setAddTabButtonHoverState: (BOOL) showHover;
- (void) setTabTrackingAreasEnabled: (BOOL) enabled;

@property (nonatomic, assign) BOOL initialLayoutComplete;

// If YES, do not show the new tab button during layout.

@property (nonatomic, assign) BOOL forceAddTabButtonHidden;

// Frame targets for all the current views. target frames are used because repeated requests to [NSView animator].
// aren't coalesced, so we store frames to avoid redundant calls.

@property (nonatomic, retain) NSMutableDictionary* targetFrames;
@property (nonatomic, assign) NSRect addTabTargetFrame;

@end

@implementation AVTTabWellController

+ (void) initialize
{
    if( [self class] == [AVTTabWellController class] )
    {
        @autoreleasepool
        {
            NSBundle* frameworkBundle = [[NSBundle bundleForClass: [self class]] retain];
            NSString* addTabHoverImagePath = [frameworkBundle pathForImageResource: @"newtab-hover"];
            NSString* addTabImagePath = [frameworkBundle pathForImageResource: @"newtab-normal"];
            NSString* addTabPressedImagePath = [frameworkBundle pathForImageResource: @"newtab-pressed"];
            NSString* defaultIconImagePath = [frameworkBundle pathForImageResource: @"default-icon"];

            sAddTabHoverImage = [[NSImage alloc] initWithContentsOfFile: addTabHoverImagePath];
            sAddTabImage = [[NSImage alloc] initWithContentsOfFile: addTabImagePath];
            sAddTabPressedImage = [[NSImage alloc] initWithContentsOfFile: addTabPressedImagePath];
            sDefaultIconImage = [[NSImage alloc] initWithContentsOfFile: defaultIconImagePath];
            [frameworkBundle release];
        }
    }
}

+ (CGFloat) defaultTabHeight
{
    return 25.0f;
}

+ (CGFloat) defaultIndentForControls
{
    // Default indentation leaves enough room so tabs don't overlap with the window controls.

    return 64.0f;
}

- (id) initWithView: (AVTTabWellView*) tabWellView
         switchView: (AVTFastResizeView*) switchView
          container: (AVTContainer*) container
{
    self = [super init];
    if( self != nil )
    {
        _tabWellView = tabWellView;
        _switchView = switchView;
        _container = container;

        _tabWellModel = [_container tabWellModel];

        // Important note: any non-tab subviews not added to |permanentSubviews| (see |-addSubviewToPermanentList:|) will be wiped out.

        _permanentSubviews = [[NSMutableArray alloc] init];

        _defaultIcon = [sDefaultIconImage retain];

        _tabDocumentArray = [[NSMutableArray alloc] init];
        _tabArray = [[NSMutableArray alloc] init];

        _closingControllers = [[NSMutableSet alloc] init];

        _targetFrames = [[NSMutableDictionary alloc] init];

        _availableResizeWidth = kUseFullAvailableWidth;
        _indentForControls = [[self class] defaultIndentForControls];

        // TODO(viettrungluu): WTF? "For some reason, if the view is present in the
        // nib a priori, it draws correctly. If we create it in code and add it to
        // the tab view, it draws with all sorts of crazy artifacts."

        _addTabButton = [tabWellView.addTabButton retain];
        [self addSubviewToPermanentList: _addTabButton];
        [_addTabButton setTarget: nil];
        [_addTabButton setAction: @selector( commandDispatch: )];
        [_addTabButton setTag: eContainerCommandNewTab];

        // Set the images from code because Cocoa fails to find them in our sub bundle during tests.

        [_addTabButton setImage: sAddTabImage];
        [_addTabButton setAlternateImage: sAddTabPressedImage];
        _addTabButtonShowingHoverImage = NO;
        _addTabTrackingArea = [[NSTrackingArea alloc] initWithRect: _addTabButton.bounds
                                                           options: (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                                                             owner: self
                                                          userInfo: nil];
        [_addTabButton addTrackingArea: _addTabTrackingArea];

        _dragBlockingView = [[AVTTabWellControllerDragBlockingView alloc] initWithFrame: NSZeroRect controller: self];
        [self addSubviewToPermanentList: _dragBlockingView];

        _addTabTargetFrame = NSZeroRect;

        // Install the permanent subviews.

        [self regenerateSubviewList];

        // Watch for notifications that the tab strip view has changed size so we can tell it to layout for the new size.

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabViewFrameChanged: )
                                                     name: NSViewFrameDidChangeNotification
                                                   object: _tabWellView];

        _trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect // Ignored by NSTrackingInVisibleRect
                                                     options: NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                       owner: self
                                                    userInfo: nil];
        [_tabWellView addTrackingArea: _trackingArea];

        // Check to see if the mouse is currently in our bounds so we can enable the tracking areas.  Otherwise we won't get hover states
        // or tab gradients if we load the window up under the mouse.

        NSPoint mouseLoc = [tabWellView.window mouseLocationOutsideOfEventStream];
        mouseLoc = [tabWellView convertPoint: mouseLoc fromView: nil];
        if( NSPointInRect( mouseLoc, tabWellView.bounds ) )
        {
            [self setTabTrackingAreasEnabled: YES];
            _mouseInside = YES;
        }

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabInserted: )
                                                     name: kDidInsertTabDocumentNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabSelected: )
                                                     name: kDidSelectTabDocumentNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabDetached: )
                                                     name: kDidDetachTabDocumentNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabMoved: )
                                                     name: kTabDocumentDidMoveNotification
                                                   object: nil];
    }

    return self;
}

- (void) dealloc
{
    _switchView = nil;
    _placeholderTab = nil;
    _tabWellModel = nil;
    _hoveredTab = nil;

    [_permanentSubviews release];
    [_defaultIcon release];
    [_dragBlockingView release];
    [_tabDocumentArray release];
    [_tabArray release];
    [_closingControllers release];
    [_addTabButton release];
    [_addTabTrackingArea release];
    [_targetFrames release];
    [_trackingArea release];

    [super dealloc];
}

- (NSView*) selectedTabView
{
    NSInteger selectedIndex = [self.tabWellModel selectedIndex];

    // Take closing tabs into account. They can't ever be selected.

    selectedIndex = [self indexFromModelIndex: selectedIndex];
    return [self viewAtIndex: selectedIndex];
}

// Find the model index based on the x coordinate of the placeholder. If there is no placeholder, this returns the end of the
// tab strip. Closing tabs are not considered in computing the index.

- (int) indexOfPlaceholder
{
    double placeholderX = self.placeholderFrame.origin.x;
    int index = 0;
    int location = 0;

    // Use |tabArray| here instead of the tab strip count in order to get the
    // correct index when there are closing tabs to the left of the placeholder.

    const NSUInteger count = self.tabArray.count;
    while( index < count )
    {
        // Ignore closing tabs for simplicity. The only drawback of this is that
        // if the placeholder is placed right before one or several contiguous
        // currently closing tabs, the associated CTTabController will start at the
        // end of the closing tabs.

        if( [self.closingControllers containsObject: [self.tabArray objectAtIndex: index]] )
        {
            index++;
            continue;
        }
        NSView* curr = [self viewAtIndex: index];

        // The placeholder tab works by changing the frame of the tab being dragged to be the bounds of the placeholder,
        // so we need to skip it while we're iterating, otherwise we'll end up off by one.  Note This only effects
        // dragging to the right, not to the left.

        if( curr == self.placeholderTab )
        {
            index++;
            continue;
        }

        if( placeholderX <= NSMinX( [curr frame] ) )
            break;
        index++;
        location++;
    }

    return location;
}

- (void) setFrameOfSelectedTab: (NSRect) frame
{
    NSView* view = [self selectedTabView];
    NSValue* identifier = [NSValue valueWithPointer: view];
    [self.targetFrames setObject: [NSValue valueWithRect: frame] forKey: identifier];
    [view setFrame: frame];
}

// (Private) Returns the number of open tabs in the tab well. This is the number of TabControllers we know about
// (as there's a 1-to-1 mapping from these controllers to a tab) less the number of closing tabs.

- (NSInteger) numberOfOpenTabs
{
    return self.tabWellModel.count;
}

// (Private) Returns the number of open, mini-tabs.

- (NSInteger) numberOfOpenMiniTabs
{
    // Ask the model for the number of mini tabs. Note that tabs which are in the process of closing (i.e., whose controllers are in
    // |closingControllers|) have already been removed from the model.

    return [self.tabWellModel indexOfFirstNonMiniTab];
}

- (NSInteger) numberOfOpenNonMiniTabs
{
    NSInteger number = [self numberOfOpenTabs] - [self numberOfOpenMiniTabs];
    NSAssert( number >= 0, @"" );

    return number;
}

#pragma mark - Mouse Tracking

- (void) mouseEntered: (NSEvent*) event
{
    NSTrackingArea* area = event.trackingArea;
    if( [area isEqual: self.trackingArea] )
    {
        self.mouseInside = YES;
        [self setTabTrackingAreasEnabled: YES];
        [self mouseMoved: event];
    }
}

- (void) mouseMoved: (NSEvent*) event
{
    // Use hit test to figure out what view we are hovering over.

    NSView* targetView = [self.tabWellView hitTest: event.locationInWindow];

    // Set the new tab button hover state iff the mouse is over the button.

    BOOL shouldShowHoverImage = [targetView isKindOfClass: [AVTNewTabButton class]];
    [self setAddTabButtonHoverState: shouldShowHoverImage];

    AVTTabView* tabView = (AVTTabView*)targetView;
    if( ![tabView isKindOfClass: [AVTTabView class]] )
    {
        if( [[tabView superview] isKindOfClass: [AVTTabView class]] )
        {
            tabView = (AVTTabView*)[targetView superview];
        }
        else
        {
            tabView = nil;
        }
    }

    if( self.hoveredTab != tabView )
    {
        [self.hoveredTab mouseExited: nil];  // We don't pass event because moved events
        [tabView mouseEntered: nil];  // don't have valid tracking areas
        self.hoveredTab = tabView;
    }
    else
    {
        [self.hoveredTab mouseMoved: event];
    }
}

// Called when the tracking area is in effect which means we're tracking to see if the user leaves the tab well with their mouse.
// When they do, reset layout to use all available width.

- (void) mouseExited: (NSEvent*) event
{
    NSTrackingArea* area = [event trackingArea];
    if( [area isEqual: self.trackingArea] )
    {
        self.mouseInside = NO;
        [self setTabTrackingAreasEnabled: NO];
        self.availableResizeWidth = kUseFullAvailableWidth;
        [self.hoveredTab mouseExited: event];
        self.hoveredTab = nil;
        [self layoutTabs];
    }
    else if( [area isEqual: self.addTabTrackingArea] )
    {
        // If the mouse is moved quickly enough, it is possible for the mouse to leave the tabwell without sending any
        // mouseMoved: messages at all. Since this would result in the new tab button incorrectly staying in the
        // hover state, disable the hover image on every mouse exit.

        [self setAddTabButtonHoverState: NO];
    }
}

// Enable/Disable the tracking areas for the tabs. They are only enabled when the mouse is in the tabwell.

- (void) setTabTrackingAreasEnabled: (BOOL) enabled
{
    NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
    for( AVTTabController* controller in self.tabArray )
    {
        AVTTabView* tabView = controller.tabView;
        if( enabled )
        {
            // Set self up to observe tabs so hover states will be correct.

            [defaultCenter addObserver: self
                              selector: @selector( tabUpdateTracking: )
                                  name: NSViewDidUpdateTrackingAreasNotification
                                object: tabView];
        }
        else
        {
            [defaultCenter removeObserver: self
                                     name: NSViewDidUpdateTrackingAreasNotification
                                   object: tabView];
        }
        [tabView setTrackingEnabled: enabled];
    }
}

// Sets the new tab button's image based on the current hover state.  Does
// nothing if the hover state is already correct.

- (void) setAddTabButtonHoverState: (BOOL) shouldShowHover
{
    if( shouldShowHover && ! self.addTabButtonShowingHoverImage )
    {
        self.addTabButtonShowingHoverImage = YES;
        [self.addTabButton setImage: sAddTabHoverImage];
    }
    else if( !shouldShowHover && self.addTabButtonShowingHoverImage )
    {
        self.addTabButtonShowingHoverImage = NO;
        [self.addTabButton setImage: sAddTabImage];
    }
}

// Adds the given subview to (the end of) the list of permanent subviews (specified from bottom up). These subviews will always be
// below the transitory subviews (tabs). |-regenerateSubviewList| must be called to effectuate the addition.

- (void) addSubviewToPermanentList: (NSView*) aView
{
    if( aView )
        [self.permanentSubviews addObject: aView];
}

#pragma mark - Layout

// When we're told to layout from the public API we usually want to animate, except when it's the first time.

- (void) layoutTabs
{
    [self layoutTabsWithAnimation: self.initialLayoutComplete regenerateSubviews: YES];
}

// Lay out all tabs in the order of their TabDocumentControllers, which matches the ordering in the TabWellModel.
// This call isn't that expensive, though it is O(n) in the number of tabs. Tabs will animate to their new position
// if the window is visible and |animate| is YES.
//
// TODO(pinkerton): Note this doesn't do too well when the number of min-sized
// tabs would cause an overflow. http://crbug.com/188

- (void) layoutTabsWithAnimation: (BOOL) animate
              regenerateSubviews: (BOOL) doUpdate
{
    NSAssert( [NSThread isMainThread], @"Must be done on main thread." );
    if( self.tabArray.count > 0 )
    {
        const CGFloat kMaxTabWidth = [AVTTabController maxTabWidth];
        const CGFloat kMinTabWidth = [AVTTabController minTabWidth];
        const CGFloat kMinSelectedTabWidth = [AVTTabController minSelectedTabWidth];
        const CGFloat kMiniTabWidth = [AVTTabController miniTabWidth];
        const CGFloat kAppTabWidth = [AVTTabController appTabWidth];

        NSRect enclosingRect = NSZeroRect;
        if( animate )
        {
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] avt_setDuration: kAnimationDuration eventMask: NSLeftMouseUpMask];
        }

        // Update the current subviews and their z-order if requested.

        if( doUpdate )
            [self regenerateSubviewList];

        // Compute the base width of tabs given how much room we're allowed. Note that
        // mini-tabs have a fixed width. We may not be able to use the entire width
        // if the user is quickly closing tabs. This may be negative, but that's okay
        // (taken care of by |MAX()| when calculating tab sizes).

        CGFloat availableSpace = 0;
        if( [self inRapidClosureMode] )
        {
            availableSpace = self.availableResizeWidth;
        }
        else
        {
            availableSpace = NSWidth( self.tabWellView.frame );

            // Account for the new tab button and the incognito badge.

            if( self.forceAddTabButtonHidden )
            {
                availableSpace -= 5.0;     // margin
            }
            else
            {
                availableSpace -= NSWidth( self.addTabButton.frame ) + kAddTabButtonOffset;
            }
        }
        availableSpace -= [self indentForControls];

        // This may be negative, but that's okay (taken care of by |MAX()| when calculating tab sizes). "mini" tabs in horizontal
        // mode just get a special section, they don't change size.

        CGFloat availableSpaceForNonMini = availableSpace;
        availableSpaceForNonMini -= [self numberOfOpenMiniTabs] * (kMiniTabWidth - kTabOverlap);

        // Initialize |nonMiniTabWidth| in case there aren't any non-mini-tabs; this value shouldn't actually be used.

        CGFloat nonMiniTabWidth = kMaxTabWidth;
        const NSInteger numberOfOpenNonMiniTabs = [self numberOfOpenNonMiniTabs];
        if( numberOfOpenNonMiniTabs )
        {
            // Find the width of a non-mini-tab. This only applies to horizontal mode. Add in the amount we "get back" from the tabs overlapping.

            availableSpaceForNonMini += (numberOfOpenNonMiniTabs - 1) * kTabOverlap;

            // Divide up the space between the non-mini-tabs.

            nonMiniTabWidth = availableSpaceForNonMini / numberOfOpenNonMiniTabs;

            // Clamp the width between the max and min.

            nonMiniTabWidth = MAX( MIN( nonMiniTabWidth, kMaxTabWidth ), kMinTabWidth );
        }

        BOOL visible = [[self.tabWellView window] isVisible];

        CGFloat offset = [self indentForControls];
        NSUInteger i = 0;
        bool hasPlaceholderGap = false;
        for( AVTTabController* tab in self.tabArray )
        {
            // Ignore a tab that is going through a close animation.

            if( [self.closingControllers containsObject: tab] )
                continue;

            BOOL isPlaceholder = [tab.view isEqual: self.placeholderTab];
            NSRect tabFrame = tab.view.frame;
            tabFrame.size.height = [[self class] defaultTabHeight] + 1;
            tabFrame.origin.y = 0;
            tabFrame.origin.x = offset;

            // If the tab is hidden, we consider it a new tab. We make it visible
            // and animate it in.

            BOOL newTab = [tab.view isHidden];
            if( newTab )
            {
                [tab.view setHidden: NO];
            }

            if( isPlaceholder )
            {
                // Move the current tab to the correct location instantly.
                // We need a duration or else it doesn't cancel an inflight animation.

                if( animate )
                {
                    [NSAnimationContext beginGrouping];
                    [[NSAnimationContext currentContext] setDuration: 0.00001];
                }

                tabFrame.origin.x = self.placeholderFrame.origin.x;

                // TODO(alcor): reenable this
                // tabFrame.size.height += 10.0 * placeholderStretchiness_;

                id target = animate ?[tab.view animator] : tab.view;
                [target setFrame: tabFrame];

                // Store the frame by identifier to aviod redundant calls to animator.

                NSValue* identifier = [NSValue valueWithPointer: tab.view];
                [self.targetFrames setObject: [NSValue valueWithRect: tabFrame] forKey: identifier];

                if( animate )
                    [NSAnimationContext endGrouping];

                continue;
            }

            if( self.placeholderTab && !hasPlaceholderGap )
            {
                const CGFloat placeholderMin = NSMinX( self.placeholderFrame );

                // If the left edge is to the left of the placeholder's left, but the mid is to the right of it slide over to make space for it.

                if( NSMidX( tabFrame ) > placeholderMin )
                {
                    hasPlaceholderGap = true;
                    offset += NSWidth( self.placeholderFrame );
                    offset -= kTabOverlap;
                    tabFrame.origin.x = offset;
                }
            }

            // Set the width. Selected tabs are slightly wider when things get really
            // small and thus we enforce a different minimum width.

            tabFrame.size.width = [tab mini] ? ([tab app] ? kAppTabWidth : kMiniTabWidth) : nonMiniTabWidth;
            if( [tab selected] )
                tabFrame.size.width = MAX( tabFrame.size.width, kMinSelectedTabWidth );

            // Animate a new tab in by putting it below the horizon unless told to put
            // it in a specific location (i.e., from a drop).

            if( newTab && visible && animate )
            {
                if( NSEqualRects( self.droppedTabFrame, NSZeroRect ) )
                {
                    [tab.view setFrame: NSOffsetRect( tabFrame, 0, -NSHeight( tabFrame ) )];
                }
                else
                {
                    [tab.view setFrame: self.droppedTabFrame];
                    self.droppedTabFrame = NSZeroRect;
                }
            }

            // Check the frame by identifier to avoid redundant calls to animator.

            id frameTarget = visible && animate ?[tab.view animator] : tab.view;
            NSValue* identifier = [NSValue valueWithPointer: tab.view];
            NSValue* oldTargetValue = [self.targetFrames objectForKey: identifier];
            if( !oldTargetValue ||
                !NSEqualRects( [oldTargetValue rectValue], tabFrame ) )
            {
                [frameTarget setFrame: tabFrame];
                [self.targetFrames setObject: [NSValue valueWithRect: tabFrame] forKey: identifier];
            }

            enclosingRect = NSUnionRect( tabFrame, enclosingRect );

            offset += NSWidth( tabFrame );
            offset -= kTabOverlap;
            i++;
        }

        // Hide the new tab button if we're explicitly told to. It may already be hidden, doing it again doesn't hurt.
        // Otherwise position it appropriately, showing it if necessary.

        if( self.forceAddTabButtonHidden )
        {
            [self.addTabButton setHidden: YES];
        }
        else
        {
            NSRect newTabNewFrame = self.addTabButton.frame;

            // We've already ensured there's enough space for the new tab button so we don't have to check it against the available space.
            // We do need  to make sure we put it after any placeholder.

            newTabNewFrame.origin = NSMakePoint( offset, 0 );
            newTabNewFrame.origin.x = MAX( newTabNewFrame.origin.x, NSMaxX( self.placeholderFrame ) ) + kAddTabButtonOffset;
            if( self.tabDocumentArray.count )
                [self.addTabButton setHidden: NO];

            if( !NSEqualRects( self.addTabTargetFrame, newTabNewFrame ) )
            {
                // Set the new tab button image correctly based on where the cursor is.

                NSWindow* window = [self.tabWellView window];
                NSPoint currentMouse = [window mouseLocationOutsideOfEventStream];
                currentMouse = [self.tabWellView convertPoint: currentMouse fromView: nil];

                BOOL shouldShowHover = [self.addTabButton pointIsOverButton: currentMouse];
                [self setAddTabButtonHoverState: shouldShowHover];

                // Move the new tab button into place. We want to animate the new tab  button if it's moving to the left (closing a tab),
                // but not when it's moving to the right (inserting a new tab). If moving right, we need to use a very small duration to
                // make sure we cancel any in-flight  animation to the left.

                if( visible && animate )
                {
                    [NSAnimationContext beginGrouping];
                    {
                        BOOL movingLeft = NSMinX( newTabNewFrame ) < NSMinX( self.addTabTargetFrame );
                        if( !movingLeft && animate )
                        {
                            [[NSAnimationContext currentContext] setDuration: 0.00001];
                        }
                        [[self.addTabButton animator] setFrame: newTabNewFrame];
                        self.addTabTargetFrame = newTabNewFrame;
                    }
                    [NSAnimationContext endGrouping];
                }
                else
                {
                    [self.addTabButton setFrame: newTabNewFrame];
                    self.addTabTargetFrame = newTabNewFrame;
                }
            }
        }

        [self.dragBlockingView setFrame: enclosingRect];

        // Mark that we've successfully completed layout of at least one tab.

        self.initialLayoutComplete = YES;

        if( animate )
            [NSAnimationContext endGrouping];
    }
}

// Update the subviews, keeping the permanent ones (or, more correctly, putting in the ones listed in permanentSubviews),
// and putting in the current tabs in the correct z-order. Any current subviews which is neither in the permanent
// list nor a (current) tab will be removed. So if you add such a subview, you should call |-addSubviewToPermanentList:|
// (or better yet, call that and then |-regenerateSubviewList| to actually add it).

- (void) regenerateSubviewList
{
    // Remove self as an observer from all the old tabs before a new set of potentially different tabs is put in place.

    [self setTabTrackingAreasEnabled: NO];

    // Subviews to put in (in bottom-to-top order), beginning with the permanent ones.

    NSMutableArray* subviews = [NSMutableArray arrayWithArray: self.permanentSubviews];

    NSView* selectedTabView = nil;

    // Go through tabs in reverse order, since |subviews| is bottom-to-top.

    for( AVTTabController* tab in [self.tabArray reverseObjectEnumerator] )
    {
        NSView* tabView = [tab view];
        if( [tab selected] )
        {
            NSAssert( !selectedTabView, @"Invalid selectedTabView" );
            selectedTabView = tabView;
        }
        else
        {
            [subviews addObject: tabView];
        }
    }
    if( selectedTabView )
    {
        [subviews addObject: selectedTabView];
    }
    [self.tabWellView setSubviews: subviews];
    [self setTabTrackingAreasEnabled: self.mouseInside];
}

// Are we in rapid (tab) closure mode? I.e., is a full layout deferred (while the user closes tabs)? Needed to overcome missing
// clicks during rapid tab closure.

- (BOOL) inRapidClosureMode
{
    return NO;
}

// Disable tab dragging when there are any pending animations.

- (BOOL) tabDraggingAllowed
{
    return self.closingControllers.count == 0;
}

#pragma mark - Properties

- (BOOL) showsAddTabButton
{
    return !self.forceAddTabButtonHidden && self.addTabButton;
}

- (void) setShowsAddTabButton: (BOOL) show
{
    if( !!self.forceAddTabButtonHidden == !!show )
    {
        self.forceAddTabButtonHidden = !show;
        [self.addTabButton setHidden: self.forceAddTabButtonHidden];
    }
}

#pragma mark - Notifications

// The model has notified us that we have insert a tab.

- (void) tabInserted: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* document = userInfo[kTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];
    BOOL inForeground = [userInfo[kTabDocumentInForegroundKey] boolValue];

    NSAssert( document, @"Insert didn't get a document." );
    NSAssert( modelIndex == kNoTab || [self.tabWellModel containsIndex: modelIndex], @"Invalid index" );

    NSInteger index = [self indexFromModelIndex: modelIndex];

    // Make a new tab. Load the document of this tab from the nib and associate the new controller with |document|
    // so it can be looked up later.

    AVTTabDocumentController* documentController = [self.container createTabDocumentControllerWithDocument: document];
    [self.tabDocumentArray insertObject: documentController atIndex: index];

    // Make a new tab and add it to the strip. Keep track of its controller.

    AVTTabController* newController = [self newTab];
    [newController setMini: [self.tabWellModel isMiniTabForIndex: modelIndex]];
    [newController setPinned: [self.tabWellModel isTabPinnedForIndex: modelIndex]];
    [newController setApp: [self.tabWellModel isAppTabForIndex: modelIndex]];
    [self.tabArray insertObject: newController atIndex: index];
    NSView* newView = [newController view];

    // Set the originating frame to just below the strip so that it animates upwards as it's being initially layed out.
    // Oddly, this works while doing  something similar in |-layoutTabs| confuses the window server.

    [newView setFrame: NSOffsetRect( [newView frame], 0, -[[self class] defaultTabHeight] )];

    [self setTabTitle: newController withDocument: document];

    // If a tab is being inserted, we can again use the entire tab strip width for layout.

    self.availableResizeWidth = kUseFullAvailableWidth;

    // We don't need to call |-layoutTabs| if the tab will be in the foreground because it will get called when the new tab is
    // selected by the tab model. Whenever |-layoutTabs| is called, it'll also add the new subview.

    if( !inForeground )
    {
        [self layoutTabs];
    }

    // During normal loading, we won't yet have a favicon and we'll get subsequent state change notifications to show the
    // throbber, but when we're  dragging a tab out into a new window, we have to put the tab's favicon into the right state
    // up front as we won't be told to do it from anywhere  else.

    [self updateIconRepresentationForDocument: document atIndex: modelIndex];

    // Send a broadcast that the number of tabs have changed.

    [[NSNotificationCenter defaultCenter] postNotificationName: kTabWellNumberOfTabsChanged object: self];
}

// The model has notified us that a tab was selected.

- (void) tabSelected: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* newDocument = userInfo[kNewTabDocumentKey];
    AVTTabDocument* oldDocument = userInfo[kOldTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];

    NSInteger index = [self indexFromModelIndex: modelIndex];

    if( oldDocument )
    {
        NSInteger oldModelIndex = [self.tabWellModel indexOfTabDocument: oldDocument];
        if( oldModelIndex != kNoTab ) // When closing a tab, the old tab may be gone.
        {
            NSInteger oldIndex = [self indexFromModelIndex: oldModelIndex];
            AVTTabDocumentController* oldController = [self.tabDocumentArray objectAtIndex: oldIndex];
            [oldController willResignSelectedTab];
        }
    }

    // De-select all other tabs and select the new tab.

    NSInteger i = 0;
    for( AVTTabController* current in self.tabArray )
    {
        [current setSelected: (i == index) ? YES: NO];
        ++i;
    }

    // Tell the new tab contents it is about to become the selected tab. Here it
    // can do things like make sure the toolbar is up to date.

    AVTTabDocumentController* newController = [self.tabDocumentArray objectAtIndex: index];
    [newController willBecomeSelectedTab];

    // Relayout for new tabs and to let the selected tab grow to be larger in
    // size than surrounding tabs if the user has many. This also raises the
    // selected tab to the top.

    [self layoutTabs];

    // Swap in the contents for the new tab.

    [self swapInTabAtIndex: modelIndex];

    if( newDocument )
    {
        // TODO: if [<parent window> isMiniaturized] or if app is hidden the tab is
        // not visible

        newDocument.isVisible = oldDocument.isVisible;
        newDocument.isSelected = YES;
    }
    if( oldDocument )
    {
        oldDocument.isVisible = NO;
        oldDocument.isSelected = NO;
    }
}

- (void) tabDetached: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];

    // Take closing tabs into account.

    NSInteger index = [self indexFromModelIndex: modelIndex];

    AVTTabController* tab = [self.tabArray objectAtIndex: index];
    if( self.tabWellModel.count > 0 )
    {
        [self startClosingTabWithAnimation: tab];
        [self layoutTabs];
    }
    else
    {
        [self removeTab: tab];
    }

    // Send a broadcast that the number of tabs have changed.

    [[NSNotificationCenter defaultCenter] postNotificationName: kTabWellNumberOfTabsChanged object: self];
}

- (void) tabMoved: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* document = userInfo[kTabDocumentKey];
    NSInteger modelFrom = [userInfo[kTabDocumentIndexKey] integerValue];
    NSInteger modelTo = [userInfo[kTabDocumentToIndexKey] integerValue];

    // Take closing tabs into account.

    NSInteger from = [self indexFromModelIndex: modelFrom];
    NSInteger to = [self indexFromModelIndex: modelTo];

    AVTTabDocumentController* movedTabContentsController = [[self.tabDocumentArray objectAtIndex: from] retain];
    {
        [self.tabDocumentArray removeObjectAtIndex: from];
        [self.tabDocumentArray insertObject: movedTabContentsController atIndex: to];
        AVTTabController* movedTabController = [[self.tabArray objectAtIndex: from] retain];
        {
            NSAssert( [movedTabController isKindOfClass: [AVTTabController class]], @"Wrong kind of class." );
            [self.tabArray removeObjectAtIndex: from];
            [self.tabArray insertObject: movedTabController atIndex: to];

            // The tab moved, which means that the mini-tab state may have changed.

            if( [self.tabWellModel isMiniTabForIndex: modelTo] != [movedTabController mini] )
                [self tabMiniStateChangedWithDocument: document atIndex: modelTo];
        }
        [movedTabController release];
    }
    [movedTabContentsController release];
}

#pragma mark - Utilities

// Called by the CAAnimation delegate when the tab completes the closing animation.

- (void) animationDidStopForController: (AVTTabController*) controller
                              finished: (BOOL) finished
{
    [self.closingControllers removeObject: controller];
    [self removeTab: controller];
}

- (void) startClosingTabWithAnimation: (AVTTabController*) closingTab
{
    NSAssert( [NSThread isMainThread], @"Must be called on main thread." );

    // Save off the controller into the set of animating tabs. This alerts the layout method to not do anything with it and allows us
    // to correctly calculate offsets when working with indices into the model.

    [self.closingControllers addObject: closingTab];

    // Mark the tab as closing. This prevents it from generating any drags or selections while it's animating closed.

    [(AVTTabView*)[closingTab view] setClosing: YES];

    // Register delegate (owned by the animation system).

    NSView* tabView = [closingTab view];
    CAAnimation* animation = [[tabView animationForKey: @"frameOrigin"] copy];
    [animation autorelease];
    TabCloseAnimationDelegate* delegate = [[TabCloseAnimationDelegate alloc] initWithTabWell: self tabController: closingTab];
    [animation setDelegate: delegate];
    NSMutableDictionary* animationDictionary = [NSMutableDictionary dictionaryWithDictionary: [tabView animations]];
    [animationDictionary setObject: animation forKey: @"frameOrigin"];
    [tabView setAnimations: animationDictionary];
    [delegate release];

    // Periscope down! Animate the tab.

    NSRect newFrame = [tabView frame];
    newFrame = NSOffsetRect( newFrame, 0, -newFrame.size.height );
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] avt_setDuration: kAnimationDuration
                                               eventMask: NSLeftMouseUpMask];
    [[tabView animator] setFrame: newFrame];
    [NSAnimationContext endGrouping];
}

// Called when a tab is pinned or unpinned without moving.

- (void) tabMiniStateChangedWithDocument: (AVTTabDocument*) document
                                 atIndex: (NSInteger) modelIndex
{
    // Take closing tabs into account.

    NSInteger index = [self indexFromModelIndex: modelIndex];

    AVTTabController* tabController = [self.tabArray objectAtIndex: index];
    NSAssert( [tabController isKindOfClass: [AVTTabController class]], @"Not a tab controller" );
    [tabController setMini: [self.tabWellModel isMiniTabForIndex: modelIndex]];
    [tabController setPinned: [self.tabWellModel isTabPinnedForIndex: modelIndex]];
    [tabController setApp: [self.tabWellModel isAppTabForIndex: modelIndex]];
    [self updateIconRepresentationForDocument: document atIndex: modelIndex];

    // If the tab is being restored and it's pinned, the mini state is set after the tab has already been rendered,
    // so re-layout the tabstrip. In all other cases, the state is set before the tab is rendered so this isn't needed.

    [self layoutTabs];
}

// Remove all knowledge about this tab and its associated controller, and remove the view from the strip.

- (void) removeTab: (AVTTabController*) controller
{
    NSUInteger index = [self.tabArray indexOfObject: controller];

    // Release the tab contents controller so those views get destroyed. This will remove all the tab content Cocoa views from the hierarchy.
    // A subsequent "select tab" notification will follow from the model. To tell us what to swap in in its absence.

    [self.tabDocumentArray removeObjectAtIndex: index];

    // Remove the view from the tab strip.

    NSView* tab = [controller view];
    [tab removeFromSuperview];

    // Remove ourself as an observer.

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSViewDidUpdateTrackingAreasNotification
                                                  object: tab];

    // Clear the tab controller's target.

    [controller setTarget: nil];

    if( [self.hoveredTab isEqual: tab] )
        self.hoveredTab = nil;

    NSValue* identifier = [NSValue valueWithPointer: tab];
    [self.targetFrames removeObjectForKey: identifier];

    // Once we're totally done with the tab, delete its controller

    [self.tabArray removeObjectAtIndex: index];
}

// Given an index into the tab model, returns the index into the tab controller or tab document controller array accounting
// for tabs that are currently closing. For example, if there are two tabs in the process of closing before |index|,
// this returns |index| + 2. If there are no closing tabs, this will return |index|.

- (NSInteger) indexFromModelIndex: (NSInteger) index
{
    NSAssert( index >= 0, @"Invalid index." );

    NSInteger resultIndex = index;
    if( index >= 0 )
    {
        NSInteger i = 0;
        for( AVTTabController* controller in self.tabArray )
        {
            if( [self.closingControllers containsObject: controller] )
            {
                NSAssert( [(AVTTabView*)controller.view isClosing], @"Although this index is in the closing controllers, it isn't marked as closing." );
                ++index;
            }
            if( i == index ) // No need to check anything after, it has no effect.
                break;
            ++i;
        }
    }

    return resultIndex;
}

// Move the given tab at index |from| in this window to the location of the current placeholder.

- (void) moveTabFromIndex: (NSInteger) from
{
    int toIndex = [self indexOfPlaceholder];
    [self.tabWellModel moveTabDocumentAtIndex: from toIndex: toIndex selectAfterMove: YES];
}

// Drop a given AVTTabDocument at the location of the current placeholder. If there is no placeholder, it will go at the end.
// Used when dragging from another window when we don't have access to the AVTTabDocument as part of our strip.
// |frame| is in the coordinate system of the tab strip view and represents where the user dropped the new tab so it can be
// animated into its correct location when the tab is added to the model. If the tab was pinned in its previous window,
// setting |pinned| to YES will propagate that state to the new window. Mini-tabs are either app or pinned tabs; the app
// state is stored by the |document|, but the |pinned| state is the caller's responsibility.

- (void) dropTabDocument: (AVTTabDocument*) document
               withFrame: (NSRect) frame
             asPinnedTab: (BOOL) pinned;
{
    NSInteger modelIndex = [self indexOfPlaceholder];

    // Mark that the new tab being created should start at |frame|. It will be
    // reset as soon as the tab has been positioned.

    self.droppedTabFrame = frame;

    // Insert it into this tab strip. We want it in the foreground and to not
    // inherit the current tab's group.

    [self.tabWellModel insertTabDocument: document
                                 atIndex: modelIndex
                               withFlags: eAddSelected | (pinned ? eAddPinned : 0)];
}

// Called when the tab strip view changes size. As we only registered for
// changes on our view, we know it's only for our view. Layout w/out
// animations since they are blocked by the resize nested runloop. We need
// the views to adjust immediately. Neither the tabs nor their z-order are
// changed, so we don't need to update the subviews.

- (void) tabViewFrameChanged: (NSNotification*) info
{
    [self layoutTabsWithAnimation: NO regenerateSubviews: NO];
}

// Called when the tracking areas for any given tab are updated. This allows
// the individual tabs to update their hover states correctly.
// Only generates the event if the cursor is in the tab strip.

- (void) tabUpdateTracking: (NSNotification*) notification
{
    NSAssert( [[notification object] isKindOfClass: [AVTTabView class]], @"Wrong class in notification." );
    NSAssert( self.mouseInside, @"we should be mouseInside for this to be called." );

    NSWindow* window = self.tabWellView.window;
    NSPoint location = [window mouseLocationOutsideOfEventStream];
    if( NSPointInRect( location, self.tabWellView.frame ) )
    {
        NSEvent* mouseEvent = [NSEvent mouseEventWithType: NSMouseMoved
                                                 location: location
                                            modifierFlags: 0
                                                timestamp: 0
                                             windowNumber: [window windowNumber]
                                                  context: nil
                                              eventNumber: 0
                                               clickCount: 0
                                                 pressure: 0];
        [self mouseMoved: mouseEvent];
    }
}

// Returns the index of the subview |view|. Returns -1 if not present. Takes closing tabs into account such that this index
// will correctly match the tab model. If |view| is in the process of closing, returns -1, as closing tabs are no longer in the model.

- (NSInteger) modelIndexForTabView: (NSView*) view
{
    NSInteger index = 0;
    for( AVTTabController* current in self.tabArray )
    {
        // If |current| is closing, skip it.

        if( [self.closingControllers containsObject: current] )
            continue;
        else if( [current view] == view )
            return index;
        ++index;
    }

    return kNoTab;
}

// Returns the index of the contents subview |view|. Returns -1 if not present. Takes closing tabs into account such that
// this index will correctly match the tab model. If |view| is in the process of closing, returns -1, as closing
// tabs are no longer in the model.

- (NSInteger) modelIndexForDocumentView: (NSView*) view
{
    NSInteger index = 0;
    NSInteger i = 0;
    for( AVTTabDocumentController* current in self.tabDocumentArray )
    {
        // If the CTTabController corresponding to |current| is closing, skip it.

        AVTTabController* controller = [self.tabArray objectAtIndex: i];
        if( [self.closingControllers containsObject: controller] )
        {
            ++i;
            continue;
        }
        else if( [current view] == view )
        {
            return index;
        }
        ++index;
        ++i;
    }

    return -1;
}

// Returns the view at the given index, using the array of TabControllers to
// get the associated view. Returns nil if out of range.

- (NSView*) viewAtIndex: (NSInteger) index
{
    NSView* view = nil;

    if( index > 0 && index < self.tabArray.count )
        view = [[self.tabArray objectAtIndex: index] view];

    return view;
}

// Set the placeholder for a dragged tab, allowing the |frame| and |strechiness|
// to be specified. This causes this tab to be rendered in an arbitrary position

- (void) insertPlaceholderForTab: (AVTTabView*) tab
                           frame: (NSRect) frame
                   yStretchiness: (CGFloat) yStretchiness;
{
    self.placeholderTab = tab;
    self.placeholderFrame = frame;
    self.placeholderStretchiness = yStretchiness;
    [self layoutTabsWithAnimation: self.initialLayoutComplete regenerateSubviews: NO];
}

// Create a new tab view and set its cell correctly so it draws the way we want it to. It will be sized and positioned by
// |-layoutTabs| so there's no need to set the frame here. This also creates the view as hidden, it will be shown during layout.

- (AVTTabController*) newTab
{
    AVTTabController* controller = [[[AVTTabController alloc] init] autorelease];
    [controller setTarget: self];
    [controller setAction: @selector( selectTab: )];
    [[controller view] setHidden: YES];

    return controller;
}

// Called when the user clicks a tab. Tell the model the selection has changed,
// which feeds back into us via a notification.

- (void) selectTab: (id) sender
{
    NSAssert( [sender isKindOfClass: [NSView class]], @"Got a selectTab: action who'se sender wasn't a view." );

    NSInteger index = [self modelIndexForTabView: sender];
    if( [self.tabWellModel containsIndex: index] )
        [self.tabWellModel selectTabDocumentAtIndex: index];
}

// Called when the user closes a tab. Asks the model to close the tab. |sender|
// is the AVTTabView that is potentially going away.

- (void) closeTab: (id) sender
{
    NSAssert( [sender isKindOfClass: [AVTTabView class]], @"Sender is wrong class." );
    if( [self.hoveredTab isEqual: sender] )
    {
        self.hoveredTab = nil;
    }

    NSInteger index = [self modelIndexForTabView: sender];
    if( [self.tabWellModel containsIndex: index] )
    {
        const NSInteger numberOfOpenTabs = [self numberOfOpenTabs];
        if( numberOfOpenTabs > 1 )
        {
            bool isClosingLastTab = index == numberOfOpenTabs - 1;
            if( !isClosingLastTab )
            {
                // Limit the width available for laying out tabs so that tabs are not
                // resized until a later time (when the mouse leaves the tab strip).
                // TODO(pinkerton): re-visit when handling tab overflow.
                // http://crbug.com/188

                NSView* penultimateTab = [self viewAtIndex: numberOfOpenTabs - 2];
                self.availableResizeWidth = NSMaxX( [penultimateTab frame] );
            }
            else
            {
                // If the rightmost tab is closed, change the available width so that
                // another tab's close button lands below the cursor (assuming the tabs
                // are currently below their maximum width and can grow).

                NSView* lastTab = [self viewAtIndex: numberOfOpenTabs - 1];
                self.availableResizeWidth = NSMaxX( lastTab.frame );
            }
            [self.tabWellModel closeTabDocumentAtIndex: index];
        }
        else
        {
            // Use the standard window close if this is the last tab
            // this prevents the tab from being removed from the model until after
            // the window dissapears

            [[self.tabWellView window] performClose: nil];
        }
    }
}

// Updates the current loading state, replacing the icon view with a icon representation, a throbber, the default icon,
// or nothing at all.

- (void) updateIconRepresentationForDocument: (AVTTabDocument*) document
                                     atIndex: (NSInteger)modelIndex
{
    if( document )
    {
        static NSImage* sThrobberWaitingImage = nil;
        static NSImage* sThrobberLoadingImage = nil;
        static NSImage* sSadIconImage = nil;

        if( sThrobberWaitingImage == nil )
        {
            NSBundle* frameworkBundle = [NSBundle bundleForClass: [AVTTabWellController class]];
            if( frameworkBundle == nil )
                frameworkBundle = [NSBundle mainBundle];

            sThrobberWaitingImage = [[NSImage alloc] initWithContentsOfFile: [frameworkBundle pathForImageResource: @"throbber_waiting"]];
            NSAssert( sThrobberWaitingImage, @"Missing asset: throbber_waiting.png" );

            sThrobberLoadingImage = [[NSImage alloc] initWithContentsOfFile: [frameworkBundle pathForImageResource: @"throbber"]];
            NSAssert( sThrobberLoadingImage, @"Missing asset: throbber.png" );

            sSadIconImage = [[NSImage alloc] initWithContentsOfFile: [frameworkBundle pathForImageResource: @"sadicon"]];
            NSAssert( sSadIconImage, @"Missing asset: sadicon.png" );
        }

        // Take closing tabs into account.

        NSInteger index = [self indexFromModelIndex: modelIndex];
        AVTTabController* tabController = [self.tabArray objectAtIndex: index];

        // Since the tab is loading, it cannot be phantom any more.

        bool oldHasIcon = [tabController iconView] != nil;
        bool newHasIcon = [document hasIcon] || [self.tabWellModel isMiniTabForIndex: modelIndex]; // Always show icon if mini.

        AVTTabLoadingState oldState = [tabController loadingState];
        AVTTabLoadingState newState = eTabLoadingStateDone;
        NSImage* throbberImage = nil;
        if( [document isCrashed] )
        {
            newState = eTabLoadingStateCrashed;
            newHasIcon = true;
        }
        else if( [document isWaitingForResponse] )
        {
            newState = eTabLoadingStateWaiting;
            throbberImage = sThrobberWaitingImage;
        }
        else if( [document isLoading] )
        {
            newState = eTabLoadingStateLoading;
            throbberImage = sThrobberLoadingImage;
        }

        if( oldState != newState )
            [tabController setLoadingState: newState];

        // While loading, this function is called repeatedly with the same state.
        // To avoid expensive unnecessary view manipulation, only make changes when
        // the state is actually changing.  When loading is complete
        // (CTTabLoadingStateDone), every call to this function is significant.

        if( newState == eTabLoadingStateDone || oldState != newState || oldHasIcon != newHasIcon )
        {
            NSView* iconView = nil;
            if( newHasIcon )
            {
                if( newState == eTabLoadingStateDone )
                {
                    iconView = [self iconImageViewForDocument: document];
                }
                else if( newState == eTabLoadingStateCrashed )
                {
                    NSImage* oldImage = [[self iconImageViewForDocument: document] image];
                    NSRect frame = NSMakeRect( 0, 0, kIconWidthAndHeight, kIconWidthAndHeight );
                    iconView = [AVTThrobberView toastThrobberViewWithFrame: frame
                                                               beforeImage: oldImage
                                                                afterImage: sSadIconImage];
                }
                else
                {
                    NSRect frame = NSMakeRect( 0, 0, kIconWidthAndHeight, kIconWidthAndHeight );
                    iconView = [AVTThrobberView filmstripThrobberViewWithFrame: frame
                                                                         image: throbberImage];
                }
            }

            [tabController setIconView: iconView];
        }
    }
}

// Handles setting the title of the tab based on the given |contents|. Uses a canned string if |contents| is NULL.

- (void) setTabTitle: (NSViewController*) tab
        withDocument: (AVTTabDocument*) document
{
    NSString* titleString = nil;
    if( document )
        titleString = document.title;
    if( titleString.length == 0 )
        titleString = NSLocalizedString( @"New Tab", "Default title for new Tab" );
    [tab setTitle: titleString];
}

// A helper routine for creating an NSImageView to hold the fav icon or app icon for |contents|.

- (NSImageView*) iconImageViewForDocument: (AVTTabDocument*) document
{
    NSImage* image = document.icon ? document.icon : [[self.defaultIcon copy] autorelease];
    NSRect frame = NSMakeRect( 0.0f, 0.0f, kIconWidthAndHeight, kIconWidthAndHeight );
    NSImageView* view = [[[NSImageView alloc] initWithFrame: frame] autorelease];
    [view setImage: image];

    return view;
}

// Finds the AVTTabdocumentController associated with the given index into the tab model and swaps out the sole child
// of the contentArea to display its contents.

- (void) swapInTabAtIndex: (NSInteger) modelIndex
{
    NSAssert( modelIndex >= 0 && modelIndex < self.tabWellModel.count, @"Invalid index." );

    NSInteger index = [self indexFromModelIndex: modelIndex];
    AVTTabDocumentController* controller = [self.tabDocumentArray objectAtIndex: index];

    // Resize the new view to fit the window. Calling |view| may lazily instantiate the AVTTabDocumentController from the nib.
    // Until we call|-ensureContentsVisible|, the controller doesn't install the RWHVMac into the view hierarchy. This is in
    // order to avoid sending the renderer a spurious default size loaded from the nib during the call to |-view|.

    NSView* newView = controller.view;
    NSRect frame = self.switchView.bounds;
    [newView setFrame: frame];
    [controller ensureContentsVisible];

    // Remove the old view from the view hierarchy. We know there's only one child of |switchView| because we're the one who
    // put it there. There may not be any children in the case of a tab that's been closed, in which case there's no swapping
    // going on.

    NSArray* subviews = [self.switchView subviews];
    if( subviews.count )
    {
        NSView* oldView = [subviews objectAtIndex: 0];
        [self.switchView replaceSubview: oldView with: newView];
    }
    else
    {
        [self.switchView addSubview: newView];
    }

    // Make sure the new tabs's sheets are visible (necessary when a background
    // tab opened a sheet while it was in the background and now becomes active).

    AVTTabDocument* newTab = [self.tabWellModel tabDocumentAtIndex: modelIndex];
    assert( newTab );

    // Tell per-tab sheet manager about currently selected tab.

    if( self.sheetController )
    {
        [self.sheetController setActiveView: newView];
    }
}

#pragma mark - WindowSheetController helpers

// This implementation is required by AVTWindowSheetControllerDelegate protocol.

- (void) avt_systemRequestsVisibilityForView: (NSView*) view
{
    // Raise window...

    [self.switchView.window makeKeyAndOrderFront: self];

    // ...and raise a tab with a sheet.

    NSInteger index = [self modelIndexForDocumentView: view];
    assert( index >= 0 );
    if( index >= 0 )
        [self.tabWellModel selectTabDocumentAtIndex: index];
}

@end

#pragma mark - AVTTabWellControllerDragBlockingView

@implementation AVTTabWellControllerDragBlockingView

- (id) initWithFrame: (NSRect) frameRect
          controller: (AVTTabWellController*) controller
{
    self = [super initWithFrame: frameRect];
    if( self != nil )
    {
        _controller = controller;
    }

    return self;
}

- (void) dealloc
{
    _controller = nil;

    [super dealloc];
}

- (BOOL) mouseDownCanMoveWindow
{
    return NO;
}

- (void) drawRect: (NSRect) rect
{
}

// In "rapid tab closure" mode (i.e., the user is clicking close tab buttons in
// rapid succession), the animations confuse Cocoa's hit testing (which appears
// to use cached results, among other tricks), so this view can somehow end up
// getting a mouse down event. Thus we do an explicit hit test during rapid tab
// closure, and if we find that we got a mouse down we shouldn't have, we send
// it off to the appropriate view.

- (void) mouseDown: (NSEvent*) event
{
    if( [self.controller inRapidClosureMode] )
    {
        NSView* superview = self.superview;
        NSPoint hitLocation = [superview.superview convertPoint: event.locationInWindow fromView: nil];
        NSView* hitView = [superview hitTest: hitLocation];
        if( hitView != self )
        {
            [hitView mouseDown: event];
            return;
        }
    }
    [super mouseDown: event];
}

@end

#pragma mark - Animation Delegate

@implementation TabCloseAnimationDelegate

- (id) initWithTabWell: (AVTTabWellController*) well
         tabController: (AVTTabController*) controller
{
    self = [super init];
    if( self != nil )
    {
        NSAssert( well && controller, @"well and controller MUST be supplied" );

        _well = well;
        _controller = controller;
    }

    return self;
}

- (void) invalidate
{
    _well = nil;
    _controller = nil;
}

- (void) animationDidStop: (CAAnimation*) animation finished: (BOOL) finished
{
    [self.well animationDidStopForController: self.controller finished: finished];
}

@end
