//
//  AVTTabbedWindows - AVTContainerWindowController.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/11/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTContainerWindowController.h"

#import "AVTContainer.h"
#import "AVTFastResizeView.h"
#import "AVTTabDocument.h"
#import "AVTTabView.h"
#import "AVTTabWellController.h"
#import "AVTTabWellModel.h"
#import "AVTTabWellView.h"
#import "AVTToolbarController.h"

static AVTContainerWindowController* sCurrentMainWindowController = nil; // weak

@interface NSWindow( ThingsThatMightBeImplemented )
- (void) setShouldHideTitle: (BOOL) flag;
- (void) setBottomCornerRounded: (BOOL) flag;
@end

@interface AVTContainerWindowController()

- (CGFloat) layoutTabWellAtMaxY: (CGFloat) maxY width: (CGFloat) width fullscreen: (BOOL) fullscreen;
- (CGFloat) layoutToolbarAtMinX: (CGFloat) minX maxY: (CGFloat) maxY width: (CGFloat) width;

@property (nonatomic, assign) BOOL initializing;

@end

@implementation NSDocumentController( AVTContainerWindowControllerAdditions )

- (id) openUntitledDocumentWithWindowController: (NSWindowController*) windowController
                                        display: (BOOL) display
                                          error: (NSError**) outError
{
    return [self openUntitledDocumentAndDisplay: display error: outError];
}

@end

@implementation AVTContainerWindowController

+ (AVTContainerWindowController*) containerWindowController
{
    return [[[self alloc] init] autorelease];
}

+ (AVTContainerWindowController*) mainContainerWindowController
{
    return sCurrentMainWindowController;
}

+ (AVTContainerWindowController*) containerWindowControllerForWindow: (NSWindow*) window
{
    while( window )
    {
        id controller = [window windowController];
        if( [controller isKindOfClass: [AVTContainerWindowController class]] )
            return (AVTContainerWindowController*)controller;
        window = [window parentWindow];
    }
    return nil;
}

+ (AVTContainerWindowController*) containerWindowControllerForView: (NSView*) view
{
    NSWindow* window = view.window;
    return [AVTContainerWindowController containerWindowControllerForWindow: window];
}

- (id) initWithWindowNibPath: (NSString*) windowNibPath
                   container: (AVTContainer*) container
{
    self = [super initWithWindowNibPath: windowNibPath owner: self];
    if( self != nil )
    {
        // Set initialization boolean state so subroutines can act accordingly

        _initializing = YES;

        _container = [container retain];
        _container.windowController = self;

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabInserted: )
                                                     name: kDidInsertTabDocumentNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabSelected: )
                                                     name: kDidSelectTabDocumentNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabClosing: )
                                                     name: kWillCloseTabDocumentNotification
                                                   object: nil];
//        [[NSNotificationCenter defaultCenter] addObserver: self
//                                                 selector: @selector( tabReplaced: )
//                                                     name: ???
//                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector( tabDetached: )
                                                     name: kDidDetachTabDocumentNotification
                                                   object: nil];

        // Note: the below statement including self.window implicitly loads the window and thus initializes IBOutlets, needed later.
        // If self.window is not called (i.e. code removed), substitute the loading with a call to [self loadWindow]

        // Sets the window to not have rounded corners, which prevents the resize control from being inset slightly and looking ugly.

        NSWindow* window = self.window;
        if( [window respondsToSelector: @selector( setBottomCornerRounded: )] )
            [window setBottomCornerRounded: NO];
        [[window contentView] setAutoresizesSubviews: YES];

        // Note: when using the default ContainerWindow.xib, window bounds are saved and
        // restored by Cocoa using NSUserDefaults key "containerWindow".

        // Create a tab strip controller

        _tabWellController = [[AVTTabWellController alloc] initWithView: self.tabWellView
                                                             switchView: self.tabContentArea
                                                              container: container];

        // Create a toolbar controller. The container object might return nil, in which means we do not have a toolbar.

        _toolbarController = [[_container createToolbarController] retain];
        if( _toolbarController )
        {
            [self.window.contentView addSubview: _toolbarController.view];
        }

        // When using NSDocuments

        [self setShouldCloseDocument: YES];

        [self layoutSubviews];

        _initializing = NO;
        if( !sCurrentMainWindowController )
        {
            sCurrentMainWindowController = self;
        }
    }

    return self;
}

- (id) initWithContainer: (AVTContainer*) container
{
	NSString* path = [[NSBundle bundleForClass: [AVTContainerWindowController class]] pathForResource: @"ContainerWindow" ofType: @"nib"];
	if( path == nil ) // Slight hack to resolve issues with running Sparkle in debug configurations.
	{
		NSString* frameworkPath = [[[NSBundle mainBundle] sharedFrameworksPath] stringByAppendingPathComponent: @"TabbedWindow.framework"];
		NSBundle* framework = [NSBundle bundleWithPath: frameworkPath];
		path = [framework pathForResource: @"ContainerWindow" ofType: @"nib"];
	}

    self = [self initWithWindowNibPath: path container: container];
    if( self != nil )
    {
    }

    return self;
}

- (id) init
{
    // Subclasses could override this to provide a custom |AVTContainer|

    return [self initWithContainer: [AVTContainer container]];
}

- (void) dealloc
{
    if( sCurrentMainWindowController == self )
        sCurrentMainWindowController = nil;

    [[NSNotificationCenter defaultCenter] removeObserver: self];

    _toolbarController = nil;

    [_container release];
    [_tabWellController release];

    [super dealloc];
}

- (BOOL) hasTabWell
{
    return YES;
}

- (BOOL) hasToolbar
{
    return self.toolbarController;
}

// Updates the toolbar with the states of the specified |document|. If |shouldRestore| is true, we're switching (back?)
// to this tab and should restore any previous state (such as user editing a text field) as well.

- (void) updateToolbarWithDocument: (AVTTabDocument*) document
                shouldRestoreState: (BOOL) shouldRestore
{
    [self.toolbarController updateToolbarWithDocument: document shouldRestoreState: shouldRestore];
}

- (void) synchronizeWindowTitleWithDocumentName
{
    // overriding this to not do anything have the effect of not adding a title to
    // our window (the title is in the tab, remember?)
}

#pragma mark - NSWindow (AVTThemed)

- (NSPoint) themePatternPhase
{
    // Our patterns want to be drawn from the upper left hand corner of the view. Cocoa wants to do it from the lower left of the window.
    //
    // Rephase our pattern to fit this view. Some other views (Tabs, Toolbar etc.) will phase their patterns relative to this so all the views look right.
    //
    // To line up the background pattern with the pattern in the browser window the background pattern for the tabs needs to be moved left by 5 pixels.

    const CGFloat kPatternHorizontalOffset = -5;
    NSRect tabWellViewWindowBounds = [self.tabWellView bounds];
    NSView* windowChromeView = [[[self window] contentView] superview];
    tabWellViewWindowBounds = [self.tabWellView convertRect: tabWellViewWindowBounds toView: windowChromeView];
    NSPoint phase = NSMakePoint( NSMinX( tabWellViewWindowBounds ) + kPatternHorizontalOffset,
                                 NSMinY( tabWellViewWindowBounds ) + [AVTTabWellController defaultTabHeight]);
    return phase;
}

#pragma mark - Actions

- (IBAction) saveAllDocuments: (id) sender
{
    [[NSDocumentController sharedDocumentController] saveAllDocuments: sender];
}

- (IBAction) openDocument: (id) sender
{
    [[NSDocumentController sharedDocumentController] openDocument: sender];
}

- (IBAction) newDocument: (id) sender
{
    NSDocumentController* docController = [NSDocumentController sharedDocumentController];
    NSError* error = nil;

    AVTTabDocument* baseTabDocument = [self.container selectedTabDocument];
    AVTTabDocument* tabDocument = [docController openUntitledDocumentWithWindowController: self
                                                                                  display: YES
                                                                                    error: &error];
    if( !tabDocument )
    {
        [NSApp presentError: error];
    }
    else if( baseTabDocument )
    {
        tabDocument.parentOpener = baseTabDocument;
    }
}

- (IBAction) newWindow: (id) sender
{
    AVTContainerWindowController* windowController = [[isa containerWindowController] retain];
    [windowController newDocument: sender];
    [windowController showWindow: self];
}

// Called when the user picks a menu or toolbar item when this window is key.
// Calls through to the browser object to execute the command. This assumes that
// the command is supported and doesn't check, otherwise it would have been
// disabled in the UI in validateUserInterfaceItem:.

- (void) commandDispatch: (id) sender
{
    NSAssert( sender, @"Sender must be non-nil" );

    // Identify the actual BWC to which the command should be dispatched. It might
    // belong to a background window, yet this controller gets it because it is
    // the foreground window's controller and thus in the responder chain. Some
    // senders don't have this problem (for example, menus only operate on the
    // foreground window), so this is only an issue for senders that are part of
    // windows.

    AVTContainerWindowController* targetController = self;
    if( [sender respondsToSelector: @selector( window )] )
        targetController = [[sender window] windowController];
    NSAssert( [targetController isKindOfClass: [AVTContainerWindowController class]], @"Wrong targetController class." );
    [targetController.container executeCommand: [sender tag]];
}

- (IBAction) closeTab: (id) sender
{
    [self.container.tabWellModel closeTabDocumentAtIndex: [self.container.tabWellModel selectedIndex]];
}

#pragma mark - Layout

- (void) layoutTabContentArea: (NSRect) newFrame
{
    AVTFastResizeView* tabDocumentView = self.tabContentArea;
    NSRect tabDocumentFrame = tabDocumentView.frame;
    BOOL contentShifted = NSMaxY( tabDocumentFrame ) != NSMaxY( newFrame ) || NSMinX( tabDocumentFrame ) != NSMinX( newFrame );
    tabDocumentFrame.size.height = newFrame.size.height;
    tabDocumentView.frame = tabDocumentFrame;

    // If the relayout shifts the content area up or down, let the renderer know.

    if( contentShifted )
    {
        AVTTabDocument* document = [self.container selectedTabDocument];
        if( document )
        {
            [document viewFrameDidChange: newFrame];
        }
    }
}

- (CGFloat) layoutTabWellAtMaxY: (CGFloat) maxY
                          width: (CGFloat) width
                     fullscreen: (BOOL) fullscreen
{
    // Nothing to do if no tab well.

    if( [self hasTabWell] )
    {
        NSView* tabWellView = self.tabWellView;
        CGFloat tabWellHeight = NSHeight( tabWellView.frame );
        maxY -= tabWellHeight;
        [tabWellView setFrame: NSMakeRect( 0, maxY, width, tabWellHeight )];

        // Set indentation.

        [self.tabWellController setIndentForControls: (fullscreen ? 0 : [[self.tabWellController class] defaultIndentForControls] )];

        // TODO(viettrungluu): Seems kind of bad -- shouldn't |-layoutSubviews| do this? Moreover, |-layoutTabs| will try to animate....

        [self.tabWellController layoutTabs];
    }

    return maxY;
}

#pragma mark AVTTabWindowController Implementation

// Accept tabs from a CTBrowserWindowController with the same Profile.

- (BOOL) canReceiveFrom: (AVTTabWindowController*) source
{
    if( ![source isKindOfClass: [isa class]] )
    {
        return NO;
    }

    // here we could for instance check (and deny) dragging a tab from a normal window into a special window (e.g. pop-up or similar)

    return YES;
}

// Move a given tab view to the location of the current placeholder. If there is no placeholder, it will go at the end.
// |controller| is the window controller of a tab being dropped from a different window. It will be nil if the drag is
// within the window, otherwise the tab is removed from that window before being placed into this one.
//
// The implementation will call |-removePlaceholder| since the drag is now complete. This also calls |-layoutTabs| internally
// so clients do not need to call it again.

- (void) moveTabView: (NSView*) view
      fromController: (AVTTabWindowController*) dragController
{
    if( dragController )
    {
        // Moving between windows. Figure out the AVTTabDocument to drop into our tab model from the source window's model.

        BOOL isContainer = [dragController isKindOfClass: [AVTContainerWindowController class]];
        assert( isContainer );

        if( isContainer )
        {
            AVTContainerWindowController* dragContainerWC = (AVTContainerWindowController*)dragController;
            NSInteger index = [dragContainerWC.tabWellController modelIndexForTabView: view];
            AVTTabDocument* document = [dragContainerWC.container.tabWellModel tabDocumentAtIndex: index];

            // The tab contents may have gone away if given a window.close() while it is being dragged. If so, bail, we've got nothing to drop.

            if( document )
            {
                // Convert |view|'s frame (which starts in the source tab strip's coordinate system) to the coordinate system of
                // the destination tab strip. This needs to be done before being detached so the window transforms can be performed.

                NSRect destinationFrame = view.frame;
                NSPoint tabOrigin = destinationFrame.origin;
                tabOrigin = [dragController.tabWellView convertPoint: tabOrigin toView: nil];
                tabOrigin = [view.window convertBaseToScreen: tabOrigin];
                tabOrigin = [self.window convertScreenToBase: tabOrigin];
                tabOrigin = [self.tabWellView convertPoint: tabOrigin fromView: nil];
                destinationFrame.origin = tabOrigin;

                // Before the tab is detached from its originating tab strip, store the pinned state so that it can be maintained between the windows.

                BOOL isPinned = [dragContainerWC.container.tabWellModel isTabPinnedForIndex: index];

                // Now that we have enough information about the tab, we can remove it from the dragging window. We need to do this *before* we add it to the new
                // window as this will remove the AVTTabDocument' delegate.

                [dragController detachTabView: view];

                // Deposit it into our model at the appropriate location (it already knows where it should go from tracking the drag). Doing this sets the tab's
                // delegate to be the AVTContainer.

                [self.tabWellController dropTabDocument: document
                                              withFrame: destinationFrame
                                            asPinnedTab: isPinned];
            }
        }
    }
    else
    {
        // Moving within a window.

        NSInteger index = [self.tabWellController modelIndexForTabView: view];
        [self.tabWellController moveTabFromIndex: index];
    }

    // Remove the placeholder since the drag is now complete.

    [self removePlaceholder];
}

- (NSView*) selectedTabView
{
    return [self.tabWellController selectedTabView];
}

- (void) layoutTabs
{
    [self.tabWellController layoutTabs];
}

// Creates a new window by pulling the given tab out and placing it in
// the new window. Returns the controller for the new window. The size of the
// new window will be the same size as this window.

- (AVTTabWindowController*) detachTabToNewWindow: (AVTTabView*) tabView
{
    // Disable screen updates so that this appears as a single visual change.

    AVTContainerWindowController* controller = nil;
    NSDisableScreenUpdates();
    {
        // Keep a local ref to the tab strip model object

        AVTTabWellModel* tabWellModel = self.container.tabWellModel;

        // Fetch the tab document for the tab being dragged.

        NSInteger index = [self.tabWellController modelIndexForTabView: (NSView*)tabView];
        AVTTabDocument* document = [tabWellModel tabDocumentAtIndex: index];

        // Set the window size. Need to do this before we detach the tab so it's
        // still in the window. We have to flip the coordinates as that's what
        // is expected by the CTBrowser code.

        NSWindow* sourceWindow = [tabView window];
        NSRect windowRect = [sourceWindow frame];
        NSScreen* screen = [sourceWindow screen];
        windowRect.origin.y = [screen frame].size.height - windowRect.size.height - windowRect.origin.y;

        NSRect tabRect = [tabView frame];

        // Before detaching the tab, store the pinned state.

        BOOL isPinned = [tabWellModel isTabPinnedForIndex: index];

        // Detach it from the source window, which just updates the model without deleting the tab contents. This needs to come
        // before creating the new AVTContainer because it clears the AVTTabDocument' delegate, which gets hooked
        // up during creation of the new window.

        [tabWellModel detachTabDocumentAtIndex: index];

        // Create the new browser with a single tab in its model, the one being dragged. Note that we do not retain
        // the (autoreleased) reference since the new browser will be owned by a window controller (created later)

        // New container

        AVTContainer* newContainer = [[self.container class] container];

        // Create a new window controller with the browser.

        controller = [[[[self class] alloc] initWithContainer: newContainer] autorelease];

        // Add the tab to the browser (we do it here after creating the window
        // controller so that notifications are properly delegated)

        [newContainer.tabWellModel appendTabDocument: document inForeground: YES];
        [newContainer loadingStateDidChange: document];

        // Set window frame

        [controller.window setFrame: windowRect display: NO];

        // Propagate the tab pinned state of the new tab (which is the only tab in
        // this new window).

        [newContainer.tabWellModel setTabPinnedForIndex: 0 withState: isPinned];

        // Force the added tab to the right size (remove stretching.)

        tabRect.size.height = [AVTTabWellController defaultTabHeight];

        // And make sure we use the correct frame in the new view.

        [controller.tabWellController setFrameOfSelectedTab: tabRect];
    }
    NSEnableScreenUpdates();

    return controller;
}

- (void) insertPlaceholderForTab: (AVTTabView*) tab
                           frame: (NSRect) frame
                   yStretchiness: (CGFloat) yStretchiness
{
    [super insertPlaceholderForTab: tab frame: frame yStretchiness: yStretchiness];
    [self.tabWellController insertPlaceholderForTab: tab
                                              frame: frame
                                      yStretchiness: yStretchiness];
}

- (void) removePlaceholder
{
    [super removePlaceholder];
    [self.tabWellController insertPlaceholderForTab: nil
                                              frame: NSZeroRect
                                      yStretchiness: 0];
}

- (BOOL) tabDraggingAllowed
{
    return [self.tabWellController tabDraggingAllowed];
}

- (BOOL) showsAddTabButton
{
    return self.tabWellController.showsAddTabButton;
}

- (void) setShowsAddTabButton: (BOOL) show
{
    self.tabWellController.showsAddTabButton = show;
}

// Tells the tab strip to forget about this tab in preparation for it being
// put into a different tab strip, such as during a drop on another window.

- (void) detachTabView: (NSView*) view
{
    NSInteger index = [self.tabWellController modelIndexForTabView: view];
    [self.container.tabWellModel detachTabDocumentAtIndex: index];
}

- (NSInteger) numberOfTabs
{
    return self.container.tabWellModel.count;
}

- (BOOL) hasLiveTabs
{
    return self.numberOfTabs;
}

- (NSInteger) selectedTabIndex
{
    return [self.container.tabWellModel selectedIndex];
}

- (AVTTabDocument*) selectedTabDocument
{
    return [self.container.tabWellModel selectedTabDocument];
}

- (NSString*) selectedTabTitle
{
    AVTTabDocument* document = [self selectedTabDocument];
    return document ? document.title : nil;
}

- (BOOL) hasTabStrip
{
    return YES;
}

// Called when the size of the window content area has changed. Position specific views.

- (void) layoutSubviews
{
    // With the exception of the top tab strip, the subviews which we lay out are subviews of the content view,
    // so we mainly work in the content view's coordinate system. Note, however, that the content view's coordinate system
    // and the window's base coordinate system should coincide.

    NSWindow* window = self.window;
    NSView* contentView = window.contentView;
    NSRect contentBounds = contentView.bounds;

    CGFloat minX = NSMinX( contentBounds );
    CGFloat minY = NSMinY( contentBounds );
    CGFloat width = NSWidth( contentBounds );

    // Suppress title drawing (the title is in the tab, baby)

    if( [window respondsToSelector: @selector( setShouldHideTitle: )] )
        [window setShouldHideTitle: YES];

    BOOL isFullscreen = [self isFullscreen];

    // In fullscreen mode, |yOffset| accounts for the sliding position of the
    // floating bar and the extra offset needed to dodge the menu bar.

    CGFloat yOffset = 0;
    CGFloat maxY = NSMaxY( contentBounds ) + yOffset;

    if( [self hasTabWell] )
    {
        // If we need to lay out the top tab strip, replace |maxY| and |startMaxY| with higher values, and then lay out the tab strip.

        NSRect windowFrame = [contentView convertRect: window.frame fromView: nil];
        maxY = NSHeight( windowFrame ) + yOffset;
        maxY = [self layoutTabWellAtMaxY: maxY width: width fullscreen: isFullscreen];
    }

    // Sanity-check |maxY|.

    NSAssert( maxY >= minY, @"" );
    NSAssert( maxY <= NSMaxY( contentBounds ) + yOffset, @"" );

    // The base class already positions the side tab strip on the left side of the window's content area and sizes it to take the entire vertical
    // height. All that's needed here is to push everything over to the right, if necessary.

    // Place the toolbar at the top of the reserved area.

    if( [self hasToolbar] )
        maxY = [self layoutToolbarAtMinX: minX maxY: maxY width: width];

    // If we're not displaying the bookmark bar below the infobar, then it goes immediately below the toolbar.

    // The floating bar backing view doesn't actually add any height.

    // Place the find bar immediately below the toolbar/attached bookmark bar. In fullscreen mode, it hangs off the top of the screen when the
    // bar is hidden. The find bar is unaffected by the side tab positioning.

    // If in fullscreen mode, reset |maxY| to top of screen, so that the floating bar slides over the things which appear to be in the content area.

    if( isFullscreen )
        maxY = NSMaxY( contentBounds );

    // Also place the infobar container immediate below the toolbar, except in fullscreen mode in which case it's at the top of the visual content area.

    // If the bookmark bar is detached, place it next in the visual content area.

    // Place the download shelf, if any, at the bottom of the view.

    // Finally, the content area takes up all of the remaining space.

    NSRect contentAreaRect = NSMakeRect( minX, minY, width, maxY - minY );
    [self layoutTabContentArea: contentAreaRect];

    // Place the status bubble at the bottom of the content area.

    // Normally, we don't need to tell the toolbar whether or not to show the divider, but things break down during animation.

    if( self.toolbarController )
    {
        [self.toolbarController setDividerOpacity: 0.4];
    }
}

- (CGFloat) layoutToolbarAtMinX: (CGFloat) minX
                           maxY: (CGFloat) maxY
                          width: (CGFloat) width
{
    NSAssert( self.hasToolbar, @"No toolbar layout needed." );

    NSView* toolbarView = self.toolbarController.view;
    NSRect toolbarFrame = toolbarView.frame;

    NSAssert( toolbarView.isHidden == NO, @"Why are we doing this if we are hidden?" );

    toolbarFrame.origin.x = minX;
    toolbarFrame.origin.y = maxY - NSHeight( toolbarFrame );
    toolbarFrame.size.width = width;
    maxY -= NSHeight( toolbarFrame );

    toolbarView.frame = toolbarFrame;

    return maxY;
}

#pragma NSWindowController Implementation

- (BOOL) windowShouldClose: (id) sender
{
    BOOL shouldClose = YES;

    // Disable updates while closing all tabs to avoid flickering.

    NSDisableScreenUpdates();
    {
        // NOTE: when using the default ContainerWindow.xib, window bounds are saved and
        //       restored by Cocoa using NSUserDefaults key "containerWindow".

        // NOTE: orderOut: ends up activating another window, so if we save window
        //       bounds in a custom manner we have to do it here, before we call
        //       orderOut:

        if( self.container.tabWellModel.count )
        {
            // Tab strip isn't empty.  Hide the frame (so it appears to have closed
            // immediately) and close all the tabs, allowing them to shut down. When the
            // tab strip is empty we'll be called back again.

            [self.window orderOut: self];
            [self.container windowDidBeginToClose];
            if( sCurrentMainWindowController == self )
            {
                sCurrentMainWindowController = nil;
            }

            shouldClose = NO;
        }
    }
    NSEnableScreenUpdates();

    // the tab strip is empty, it's ok to close the window

    return shouldClose;
}

- (void) windowWillClose: (NSNotification*) notification
{
    [self autorelease];
}

// Called right after our window became the main window.

- (void) windowDidBecomeMain: (NSNotification*) notification
{
    // NOTE: if you use custom window bounds saving/restoring, you should probably
    //       save the window bounds here.

    sCurrentMainWindowController = self;

    // TODO(dmaclach): Instead of redrawing the whole window, views that care
    // about the active window state should be registering for notifications.

    [self.window setViewsNeedDisplay: YES];

    // TODO(viettrungluu): For some reason, the above doesn't suffice.
    // if ([self isFullscreen])
    //  [floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

- (void) windowDidResignMain: (NSNotification*) notification
{
    if( sCurrentMainWindowController == self )
    {
        sCurrentMainWindowController = nil;
    }

    // TODO(dmaclach): Instead of redrawing the whole window, views that care
    // about the active window state should be registering for notifications.

    [self.window setViewsNeedDisplay: YES];

    // TODO(viettrungluu): For some reason, the above doesn't suffice.
    // if ([self isFullscreen])
    //  [floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

// Called when we are activated (when we gain focus).

- (void) windowDidBecomeKey: (NSNotification*) notification
{
    if( ![self.window isMiniaturized] )
    {
        AVTTabDocument* document = [self.container selectedTabDocument];
        if( document )
        {
            document.isVisible = YES;
        }
    }
}

// Called when we are deactivated (when we lose focus).

- (void) windowDidResignKey: (NSNotification*) notification
{
    // If our app is still active and we're still the key window, ignore this
    // message, since it just means that a menu extra (on the "system status bar")
    // was activated; we'll get another |-windowDidResignKey| if we ever really
    // lose key window status.

    if( [NSApp isActive] && ([NSApp keyWindow] == self.window) )
        return;
}

// Called when we have been minimized.

- (void) windowDidMiniaturize: (NSNotification*) notification
{
    AVTTabDocument* document = [self.container selectedTabDocument];
    if( document )
    {
        document.isVisible = NO;
    }
}

// Called when we have been unminimized.

- (void) windowDidDeminiaturize: (NSNotification*) notification
{
    AVTTabDocument* document = [self.container selectedTabDocument];
    if( document )
    {
        document.isVisible = YES;
    }
}

// Called when the application has been hidden.

- (void) applicationDidHide: (NSNotification*) notification
{
    // Let the selected tab know (unless we are minimized, in which case nothing has really changed).

    if( ![self.window isMiniaturized] )
    {
        AVTTabDocument* document = [self.container selectedTabDocument];
        if( document )
        {
            document.isVisible = NO;
        }
    }
}

// Called when the application has been unhidden.

- (void) applicationDidUnhide: (NSNotification*) notification
{
    // Let the selected tab know (unless we are minimized, in which case nothing has really changed).

    if( ![self.window isMiniaturized] )
    {
        AVTTabDocument* document = [self.container selectedTabDocument];
        if( document )
        {
            document.isVisible = YES;
        }
    }
}

#pragma mark - Notifications

- (void) tabInserted: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* document = userInfo[kTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];
    BOOL inForeground = [userInfo[kTabDocumentInForegroundKey] boolValue];

    NSAssert( document, @"Insert didn't get a document." );
    NSAssert( modelIndex == kNoTab || [self.container.tabWellModel containsIndex: modelIndex], @"Invalid index" );

    [document tabDidInsertIntoContainer: self.container
                                atIndex: modelIndex
                           inForeground: inForeground];
}

- (void) tabSelected: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* newDocument = userInfo[kNewTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];

    NSAssert( newDocument, @"Insert didn't get a newDocument." );
    NSAssert( modelIndex == kNoTab || [self.container.tabWellModel containsIndex: modelIndex], @"Invalid index" );

    // TODO: We aren't handling the should restore in the notifications yet.

    [self.toolbarController updateToolbarWithDocument: newDocument shouldRestoreState: YES];
}

- (void) tabClosing: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* document = userInfo[kTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];

    [document tabWillCloseInContainer: self.container atIndex: modelIndex];
    if( document.isSelected )
        [self updateToolbarWithDocument: nil shouldRestoreState: NO];
}

- (void) tabReplaced: (NSNotification*) notification
{
    NSLog( @"tabReplaced:");
}

- (void) tabDetached: (NSNotification*) notification
{
    NSDictionary* userInfo = notification.userInfo;
    AVTTabDocument* document = userInfo[kTabDocumentKey];
    NSInteger modelIndex = [userInfo[kTabDocumentIndexKey] integerValue];

    [document tabDidDetachFromContainer: self.container atIndex: modelIndex];
    if( document.isSelected )
        [self updateToolbarWithDocument: nil shouldRestoreState: NO];
}

@end
