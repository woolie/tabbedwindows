//
//  AVTTabbedWindows - AVTTabController.m
//
//  A class that manages a single tab in the tab strip. Set its target/action
//  to be sent a message when the tab is selected by the user clicking. Setting
//  the |loading| property to YES visually indicates that this tab is currently
//  loading content via a spinner.
//
//  The tab has the notion of an "icon view" which can be used to display
//  identifying characteristics such as a favicon, or since it's a full-fledged
//  view, something with state and animation such as a throbber for illustrating
//  progress. The default in the nib is an image view so nothing special is
//  required if that's all you need.
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/29/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabController.h"

#import "AVTTabView.h"

static NSString* const kContainerThemeDidChangeNotification = @"ContainerThemeDidChangeNotification";

@implementation AVTTabController
{
    @private
    IBOutlet NSView* _iconView;
}

@synthesize iconView = _iconView;
@synthesize selected = _selected;

+ (CGFloat) minTabWidth         { return 31.0f; }
+ (CGFloat) minSelectedTabWidth { return 46.0f; }
+ (CGFloat) maxTabWidth         { return 220.0f; }
+ (CGFloat) miniTabWidth        { return 53.0f; }
+ (CGFloat) appTabWidth         { return 66.0f; }

// Initialize a new controller. The default implementation will locate a nib
// called "TabView" in the app bundle and if not found there, will use the
// default nib from the framework bundle. If you need to rename the nib or load
// if from somepleace else, you should override this method and then call
// initWithNibName:bundle:.

- (id) init
{
	NSBundle* bundle = [NSBundle bundleForClass: [AVTTabController class]];
    if( bundle == nil )
        bundle = [NSBundle mainBundle];

    self = [self initWithNibName: @"TabView" bundle: bundle];
    if( self != nil )
    {
    }

    return self;
}

// Does the actual initialization work

- (id) initWithNibName: (NSString*) nibName
                bundle: (NSBundle*) bundle
{
    self = [super initWithNibName: nibName bundle: bundle];
    if( self != nil )
    {
        _iconShowing = YES;

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( viewResized: )
                                                     name: NSViewFrameDidChangeNotification
                                                   object: [self view]];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( themeChangedNotification: )
                                                     name: kContainerThemeDidChangeNotification
                                                   object: nil];
    }

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    self.tabView.tabController = nil;

    [_closeButton release];

    [super dealloc];
}

// Called when the tab's nib is done loading and all outlets are hooked up.

- (void) awakeFromNib
{
    // Remember the icon's frame, so that if the icon is ever removed, a new one can later replace it in the proper location.

    self.originalIconFrame = self.iconView.frame;

    // When the icon is removed, the title expands to the left to fill the space left by the icon.  When the close button
    // is removed, the title expands to the right to fill its space.  These are the amounts to expand and contract
    // titleView_ under those conditions.

    NSRect titleFrame = self.titleView.frame;
    self.iconTitleXOffset = NSMinX( titleFrame ) - NSMinX( self.originalIconFrame );
    self.titleCloseWidthOffset = NSMaxX( [self.closeButton frame] ) - NSMaxX( titleFrame );

    [self internalSetSelected: self.selected];
}

- (NSMenu*) menu
{
    return nil;
}

- (AVTTabView*) tabView
{
    return (AVTTabView*)self.view;
}

- (IBAction) closeTab: (id) sender
{
    if( [self.target respondsToSelector: @selector( closeTab: )])
    {
        [self.target performSelector: @selector( closeTab: ) withObject: self.view];
    }
}

- (void) setTitle: (NSString*) title
{
    [[self view] setToolTip: title];
    if( [self mini] && ![self selected] )
    {
        AVTTabView* tabView = (AVTTabView*)[self view];
        assert( [tabView isKindOfClass: [AVTTabView class]] );
        [tabView startAlert];
    }

    [super setTitle: title];
}

- (BOOL) selected
{
    return _selected;
}

- (void) setSelected: (BOOL) selected
{
    if( _selected != selected )
        [self internalSetSelected: selected];
}

- (NSView*) iconView
{
    return _iconView;
}

- (void) setIconView: (NSView*) iconView
{
    [_iconView removeFromSuperview];
    _iconView = iconView;
    if( [self app] )
    {
        NSRect appIconFrame = [iconView frame];
        appIconFrame.origin = self.originalIconFrame.origin;

        // Center the icon.

        appIconFrame.origin.x = ([AVTTabController appTabWidth] - NSWidth( appIconFrame ) ) / 2.0;
        [iconView setFrame: appIconFrame];
    }
    else
    {
        [_iconView setFrame: self.originalIconFrame];
    }

    // Ensure that the icon is suppressed if no icon is set or if the tab is too
    // narrow to display one.

    [self updateVisibility];

    if( _iconView )
        [[self view] addSubview: _iconView];
}

- (NSString*) toolTip
{
    return [[self view] toolTip];
}

// Return a rough approximation of the number of icons we could fit in the tab. We never actually do this, but it's a helpful
// guide for determining how much space we have available.

- (CGFloat) iconCapacity
{
    CGFloat width = NSMaxX( [self.closeButton frame] ) - NSMinX( self.originalIconFrame );
    CGFloat iconWidth = NSWidth( self.originalIconFrame );

    return width / iconWidth;
}

// Returns YES if we should show the icon. When tabs get too small, we clip the favicon before the close button for selected tabs,
// and prefer the icon for unselected tabs.  The icon can also be suppressed more directly by clearing iconView.

- (BOOL) shouldShowIcon
{
    BOOL shouldShow = NO;

    if( self.iconView )
    {
        if( [self mini] )
        {
            shouldShow = YES;
        }
        else
        {
            CGFloat iconCapacity = [self iconCapacity];
            if( [self selected] )
                shouldShow =  iconCapacity >= 2.0;
            else
                shouldShow = iconCapacity >= 1.0;
        }
    }

    return shouldShow;
}

// Returns YES if we should be showing the close button. The selected tab always shows the close button.

- (BOOL) shouldShowCloseButton
{
    BOOL shouldShow = NO;

    if( ![self mini] )
        shouldShow = ([self selected] || [self iconCapacity] >= 3.0);

    return shouldShow;
}

// Updates the visibility of certain subviews, such as the icon and close
// button, based on criteria such as the tab's selected state and its current
// width.

- (void) updateVisibility
{
    // iconView_ may have been replaced or it may be nil, so [iconView isHidden] won't work.  Instead, the state of the icon
    // is tracked separately in isIconShowing.

    BOOL oldShowIcon = self.isIconShowing ? YES : NO;
    BOOL newShowIcon = [self shouldShowIcon] ? YES : NO;

    [self.iconView setHidden: newShowIcon ? NO: YES];
    self.iconShowing = newShowIcon;

    // If the tab is a mini-tab, hide the title.

    [self.titleView setHidden: [self mini]];

    BOOL oldShowCloseButton = [self.closeButton isHidden] ? NO : YES;
    BOOL newShowCloseButton = [self shouldShowCloseButton] ? YES : NO;

    [self.closeButton setHidden: newShowCloseButton ? NO: YES];

    // Adjust the title view based on changes to the icon's and close button's visibility.

    NSRect titleFrame = [self.titleView frame];

    if( oldShowIcon != newShowIcon )
    {
        // Adjust the left edge of the title view according to the presence or
        // absence of the icon view.

        if( newShowIcon )
        {
            titleFrame.origin.x += self.iconTitleXOffset;
            titleFrame.size.width -= self.iconTitleXOffset;
        }
        else
        {
            titleFrame.origin.x -= self.iconTitleXOffset;
            titleFrame.size.width += self.iconTitleXOffset;
        }
    }

    if( oldShowCloseButton != newShowCloseButton )
    {
        // Adjust the right edge of the title view according to the presence or absence of the close button.

        if( newShowCloseButton )
            titleFrame.size.width -= self.titleCloseWidthOffset;
        else
            titleFrame.size.width += self.titleCloseWidthOffset;
    }

    [self.titleView setFrame: titleFrame];
}

// Update the title color to match the tabs current state.

- (void) updateTitleColor
{
    NSColor* titleColor = [self selected] ? [NSColor blackColor] : [NSColor darkGrayColor];
    [self.titleView setTextColor: titleColor];
}

// Called by the tabs to determine whether we are in rapid (tab) closure mode.

- (BOOL) inRapidClosureMode
{
    if( [[self target] respondsToSelector: @selector( inRapidClosureMode )] )
    {
        return [[self target] performSelector:@selector(inRapidClosureMode )] ? YES : NO;
    }

    return NO;
}

#pragma mark - Notifications Handlers

// Called when our view is resized. If it gets too small, start by hiding the close button and only show it if tab is selected.
// Eventually, hide the icon as well. We know that this is for our view because we only registered for notifications from our
// specific view.

- (void) viewResized: (NSNotification*) notification
{
    [self updateVisibility];
}

- (void) themeChangedNotification: (NSNotification*) notification
{
    [self updateTitleColor];
}

#pragma mark - Utility

// The internals of |-setSelected:| but doesn't check if we're already set to |selected|. Pass the selection change to the
// subviews that need it and mark ourselves as needing a redraw.

- (void) internalSetSelected: (BOOL) selected
{
    _selected = selected;
    AVTTabView* tabView = (AVTTabView*)[self view];

    NSAssert( [tabView isKindOfClass: [AVTTabView class]], @"Wrong view type." );

    [tabView setState: selected];
    [tabView cancelAlert];

    [self updateVisibility];
    [self updateTitleColor];
}

@end
