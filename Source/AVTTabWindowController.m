//
//  AVTTabbedWindows - AVTTabWindowController.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabWindowController.h"

#import "AVTFastResizeView.h"
#import "AVTTabView.h"
#import "AVTTabWellView.h"
#import "AVTTabWindowController.h"

@interface AVTTabWindowOverlayWindow : NSWindow
@end

@implementation AVTTabWindowOverlayWindow

- (NSPoint) themePatternPhase
{
    return NSZeroPoint;
}

@end

@interface AVTTabWindowController()

- (void) setUseOverlay: (BOOL) useOverlay;

@end

@implementation AVTTabWindowController

- (id) initWithWindow: (NSWindow*) window
{
    self = [super initWithWindow: window];
    if( self != nil )
    {
        _lockedTabs = [[NSMutableSet alloc] initWithCapacity: 10];
    }

    return self;
}

- (void) dealloc
{
    if( self.overlayWindow )
        [self setUseOverlay: NO];

    [_lockedTabs release];
    [_tabContentArea release];
    [_tabWellView release];
    [_overlayWindow release];

    [super dealloc];
}

- (void) windowDidLoad
{
    // Cache the difference in height between the window content area and the tab content area.

    NSRect tabFrame = self.tabContentArea.frame;
    NSRect contentFrame = [[[self window] contentView] frame];
    self.contentAreaHeightDelta = NSHeight( contentFrame ) - NSHeight( tabFrame );

    if( [self hasTabWell] )
    {
        [self addTabWellToWindow];
    }
    else
    {
        // No top tabwell so remove the tabContentArea offset.

        tabFrame.size.height = contentFrame.size.height;
        self.tabContentArea.frame = tabFrame;
    }
}

// Add the top tab strop to the window, above the content box and add it to the view hierarchy as a sibling of the content view
// so it can overlap with the window frame.

- (void) addTabWellToWindow
{
    NSRect contentFrame = self.tabContentArea.frame;
    NSRect tabFrame = NSMakeRect( 0, NSMaxY( contentFrame ),
                                  NSWidth( contentFrame ),
                                  NSHeight( self.tabWellView.frame ) );
    self.tabWellView.frame = tabFrame;
    [[self.window.contentView superview] addSubview: self.tabWellView];
}

// Toggles from one display mode of the tab strip to another. Will automatically call -layoutSubviews to reposition other content.

- (void) toggleTabWellDisplayMode
{
    // Adjust the size of the tab contents to either use more or less space, depending on the direction of the toggle.
    // This needs to be done prior to adding back in the top tab strip as its position is based off the MaxY
    // of the tab content area.

    NSRect tabContentsFrame = self.tabContentArea.frame;
    tabContentsFrame.size.height += -self.contentAreaHeightDelta;
    self.tabContentArea.frame = tabContentsFrame;
    [self addTabWellToWindow];

    [self layoutSubviews];
}

// Used during tab dragging to turn on/off the overlay window when a tab is torn off.
// If -deferPerformClose (below) is used, -removeOverlay will cause the controller to be autoreleased before returning.

- (void) showOverlay
{
    [self setUseOverlay: YES];
}

- (void) removeOverlay
{
    [self setUseOverlay: NO];
    if( self.closeDeferred )
    {
        // See comment in ContainerWindowCocoa::Close() about orderOut:.

        [self.window orderOut: self];
        [self.window performClose: self];     // Autoreleases the controller.
    }
}

// Returns YES if it is ok to constrain the window's frame to fit the screen.

- (BOOL) shouldConstrainFrameRect
{
    // If we currently have an overlay window, do not attempt to change the window's size, as our overlay window doesn't
    // know how to resize properly.

    return self.overlayWindow == nil;
}

// A collection of methods, stubbed out in this base class, that provide the implementation of tab dragging based on whatever
// model is most appropriate.

// Layout the tabs based on the current ordering of the model.

- (void) layoutTabs
{
    NSAssert( NO, @"Subclass must implement." );
}

// Creates a new window by pulling the given tab out and placing it in the new window. Returns the controller for the new window.
// The size of the new window will be the same size as this window.

- (AVTTabWindowController*) detachTabToNewWindow: (AVTTabView*) tabView
{
    NSAssert( NO, @"Subclass must implement." );
    return nil;
}

// Make room in the tab strip for |tab| at the given x coordinate. Will hide the new tab button while there's a placeholder.
// Subclasses need to call the superclass implementation.

- (void) insertPlaceholderForTab: (AVTTabView*) tab
                           frame: (NSRect) frame
                   yStretchiness: (CGFloat) yStretchiness
{
    self.didShowNewTabButtonBeforeTemporalAction = self.showsAddTabButton;
    self.showsAddTabButton = NO;
}

// Removes the placeholder installed by |-insertPlaceholderForTab:atLocation:| and restores the new tab button. Subclasses need
// to call the superclass implementation.

- (void) removePlaceholder
{
    if( self.didShowNewTabButtonBeforeTemporalAction )
        self.showsAddTabButton = YES;
}

// The follow return YES if tab dragging/tab tearing (off the tab strip)/window movement is currently allowed. Any number of
// things can choose to disable it, such as pending animations. The default implementations always return YES.
// Subclasses should override as appropriate.

- (BOOL) tabDraggingAllowed
{
    return YES;
}

- (BOOL) tabTearingAllowed
{
    return YES;
}

- (BOOL) windowMovementAllowed
{
    return YES;
}

// Called when dragging of teared tab in an overlay window occurs

- (void) willStartTearingTab {}
- (void) willEndTearingTab   {}
- (void) didEndTearingTab    {}

// Returns whether or not |tab| can still be fully seen in the tab strip or if its current position would cause it be obscured by things
// such as the edge of the window or the window decorations. Returns YES only if the entire tab is visible.
// The default implementation always returns YES.

- (BOOL) isTabFullyVisible: (AVTTabView*) tab
{
    return YES;
}

// Called to check if the receiver can receive dragged tabs from source.  Return YES if so.  The default implementation returns NO.

- (BOOL) canReceiveFrom: (id) controller
{
    NSAssert( NO, @"Subclass must implement." );
    return NO;
}

// Move a given tab view to the location of the current placeholder. If there is no placeholder, it will go at the end.
// |controller| is the window controller of a tab being dropped from a different window. It will be nil if the drag is
// within the window, otherwise the tab is removed from that window before being placed into this one. The implementation
// will call |-removePlaceholder| since the drag is now complete.  This also calls |-layoutTabs| internally so clients do
// not need to call it again.

- (void) moveTabView: (NSView*) view fromController: (AVTTabWindowController*) controller
{
    NSAssert( NO, @"Subclass must implement." );
}

- (NSView*) selectedTabView
{
    NSAssert( NO, @"Subclass must implement." );
    return nil;
}

- (BOOL) hasTabWell
{
    NSAssert( NO, @"Subclass must implement." );
    return YES;
}

- (BOOL) showsAddTabButton
{
    NSAssert( NO, @"Subclass must implement." );
    return YES;
}

- (void) setShowsAddTabButton: (BOOL) show
{
    NSAssert( NO, @"Subclass must implement." );
}

- (void) detachTabView: (NSView*) view
{
    NSAssert( NO, @"Subclass must implement." );
}

- (NSInteger) numberOfTabs
{
    NSAssert( NO, @"Subclass must implement." );
    return 0;
}

- (NSString*) selectedTabTitle
{
    NSAssert( NO, @"Subclass must implement." );
    return nil;
}

// Get/set whether a particular tab is draggable between windows.

- (BOOL) isTabDraggable: (NSView*) tabView
{
    return ![self.lockedTabs containsObject: tabView];
}

- (void) setTab: (NSView*) tabView isDraggable: (BOOL) draggable
{
    if( draggable )
        [self.lockedTabs removeObject: tabView];
    else
        [self.lockedTabs addObject: tabView];
}

// Tell the window that it needs to call performClose: as soon as the current
// drag is complete. This prevents a window (and its overlay) from going away
// during a drag.

- (void) deferPerformClose
{
    self.closeDeferred = YES;
}

// Called when the size of the window content area has changed. Override to position specific views.
// Base class implementation does nothing.

- (void) layoutSubviews
{
    NSAssert( NO, @"Implemented by subclasses." );
}

- (void) setUseOverlay: (BOOL) useOverlay
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector( removeOverlay )
                                               object: nil];
    NSWindow* window = self.window;
    if( useOverlay && !self.overlayWindow )
    {
        NSAssert( self.cachedContentView == nil, @"Should be nil." );
        self.overlayWindow = [[[AVTTabWindowOverlayWindow alloc] initWithContentRect: window.frame
                                                                           styleMask: NSBorderlessWindowMask
                                                                             backing: NSBackingStoreBuffered
                                                                               defer: YES] autorelease];
        [self.overlayWindow setTitle: @"overlay"];
        [self.overlayWindow setBackgroundColor: [NSColor clearColor]];
        [self.overlayWindow setOpaque: NO];
        [self.overlayWindow setDelegate: self];
        self.cachedContentView = window.contentView;
        [window addChildWindow: self.overlayWindow ordered: NSWindowAbove];
        [self moveViewsBetweenWindowAndOverlay: useOverlay];
        [self.overlayWindow orderFront: nil];
    }
    else if( !useOverlay && self.overlayWindow )
    {
        NSAssert( self.cachedContentView, @"Should not be nil" );
        [self.overlayWindow setDelegate: nil];
        [window setDelegate: nil];
        [window setContentView: self.cachedContentView];
        [self moveViewsBetweenWindowAndOverlay: useOverlay];
        [window makeFirstResponder: self.cachedContentView];
        [window display];
        [window removeChildWindow: self.overlayWindow];
        [self.overlayWindow orderOut: nil];
        self.overlayWindow = nil;
        self.cachedContentView = nil;
    }
    else
    {
        NSAssert( NO, @"Should not be reachable." );
    }
}

// if |useOverlay| is true, we're moving views into the overlay's content area. If false, we're moving out of the overlay back into the window's content.

- (void) moveViewsBetweenWindowAndOverlay: (BOOL) useOverlay
{
    if( useOverlay )
    {
        [[self.overlayWindow.contentView superview] addSubview: self.tabWellView];

        // Add the original window's content view as a subview of the overlay window's content view.  We cannot simply use setContentView: here because
        // the overlay window has a different content size (due to it being borderless).

        [self.overlayWindow.contentView addSubview: self.cachedContentView];
    }
    else
    {
        [self.window setContentView: self.cachedContentView];

        // The AVTTabWellView always needs to be in front of the window's content view and therefore it should always be added after the content view is set.

        [[self.window.contentView superview] addSubview: self.tabWellView];
        [[self.window.contentView superview] updateTrackingAreas];
    }
}

@end
