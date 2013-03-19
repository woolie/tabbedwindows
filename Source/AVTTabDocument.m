//
//  AVTTabbedWindows - AVTTabDocument.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabDocument.h"

#import "AVTContainer.h"
#import "AVTTabWellModel.h"

NSString* const AVTTabDocumentDidCloseNotification = @"TabDocumentDidCloseNotification";

@implementation AVTTabDocument

@synthesize parentOpener = _parentOpener;
@synthesize isVisible = _isVisible;
@synthesize isSelected = _isSelected;
@synthesize isTeared = _isTeared;

- (id) initWithBaseTabDocument: (AVTTabDocument*) baseDocument
{
    self = [super init];
    if( self != nil )
    {
        _parentOpener = baseDocument;
    }

//    NSLog( @"AVTTabDocument(%p) init. RetainCount = %ld", self, (unsigned long)self.retainCount );

    return self;
}

- (void) dealloc
{
    _parentOpener = nil;

    [_delegate release];
    [_view release];
    [_title release];
    [_icon release];

    [super dealloc];
}

// - (id) autorelease
// {
//     id arVal = [super autorelease];
//     NSLog( @"AVTTabDocument(%p) autorelease. RetainCount = %ld", self, (unsigned long)self.retainCount );
//     return arVal;
// }
// 
// - (id) retain
// {
//     id rVal = [super retain];
//     NSLog( @"AVTTabDocument(%p) retain. RetainCount = %ld", self, (unsigned long)self.retainCount );
//     return rVal;
// }
// 
// - (oneway void) release
// {
//     [super release];
//     NSLog( @"AVTTabDocument(%p) release. RetainCount = %ld", self, (unsigned long)self.retainCount );
// }

 - (void) destroy: (AVTTabWellModel*) sender
 {
     [sender tabDocumentWasDestroyed: self];
     [self release];
 }

#pragma mark Actions

// Selects the tab in it's window and brings the window to front

- (IBAction) makeKeyAndOrderFront: (id) sender
{
    if( self.container )
    {
        NSWindow* window = self.container.window;
        if( window )
            [window makeKeyAndOrderFront: sender];
        NSInteger index = [self.container indexOfTabDocument: self];
        NSAssert( index > -1, @"We should exist in container" );
        [self.container selectTabAtIndex: index];
    }
}

// Give first-responder status to view_ if isVisible

- (BOOL) becomeFirstResponder
{
    BOOL succeeded = NO;
    if( self.isVisible )
    {
        succeeded = [self.view.window makeFirstResponder: self.view];
    }

    return succeeded;
}

#pragma mark - Callbacks

// Called when this tab may be closing (unless AVTContainer respond no to canCloseTab).

- (void) closingOfTabDidStart: (AVTTabWellModel*) model
{
    [[NSNotificationCenter defaultCenter] postNotificationName: AVTTabDocumentDidCloseNotification object: self];
}

// The following three callbacks are meant to be implemented by subclasses: Called when this tab was inserted into a container

- (void) tabDidInsertIntoContainer: (AVTContainer*) container
                           atIndex: (NSInteger) index
                      inForeground: (BOOL) foreground
{
    self.container = container;
}

// Called when this tab replaced another tab

- (void) tabReplaced: (AVTTabDocument*) oldDocument
         inContainer: (AVTContainer*) container
             atIndex: (NSInteger) index
{
    self.container = container;
}

// Called when this tab is about to close

- (void) tabWillCloseInContainer: (AVTContainer*) container
                         atIndex: (NSInteger) index
{
    self.container = nil;
}

// Called when this tab was removed from a container

- (void) tabDidDetachFromContainer: (AVTContainer*) container
                           atIndex: (NSInteger) index
{
    self.container = nil;
}

// The following callbacks called when the tab's visible state changes. If you
// override, be sure and invoke super's implementation. See "Visibility states"
// in the header of this file for details.

// Called when this tab become visible on screen. This is a good place to resume animations.

- (void) tabDidBecomeVisible {}

// Called when this tab is no longer visible on screen. This is a good place to pause animations.

- (void) tabDidResignVisible {}

// Called when this tab is about to become the selected tab. Followed by a call to |tabDidBecomeSelected|

- (void) tabWillBecomeSelected {}

// Called when this tab is about to resign as the selected tab. Followed by a call to |tabDidResignSelected|

- (void) tabWillResignSelected {}

// Called when this tab became the selected tab in its window. This does neccessarily not mean it's visible
// (app might be hidden or window might be minimized). The default implementation makes our view the first responder, if visible.

- (void) tabDidBecomeSelected
{
    [self becomeFirstResponder];
}

// Called when another tab in our window "stole" the selection.

- (void) tabDidResignSelected
{
}

// Called when this tab is about to being "teared" (when dragging a tab from one window to another).

- (void) tabWillBecomeTeared
{
    // Teared tabs should always be visible and selected since tearing is invoked by the user selecting the tab on screen.

    NSAssert( self.isVisible, @"" );
    NSAssert( self.isSelected, @"");
}

// Called when this tab is teared and is about to "land" into a window.

- (void) tabWillResignTeared
{
    // Teared tabs should always be visible and selected since tearing is invoked by the user selecting the tab on screen.

    NSAssert( self.isVisible, @"" );
    NSAssert( self.isSelected, @"");
}

// Called when this tab was teared and just landed in a window. The default implementation makes our view the first responder, restoring focus.

- (void) tabDidResignTeared
{
    [self.view.window makeFirstResponder: self.view];
}

// Called when the frame has changed, which isn't too often. There are at least two cases when it's called:
// - When the tab's view is first inserted into the view hiearchy
// - When a torn off tab is moves into a window with other dimensions than the initial window.

- (void) viewFrameDidChange: (NSRect) newFrame
{
    [self.view setFrame: newFrame];
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*) key
{
    BOOL notifies;

    if( [key isEqualToString: @"isLoading"] ||
        [key isEqualToString: @"isWaitingForResponse"] ||
        [key isEqualToString: @"isCrashed"] ||
        [key isEqualToString: @"isVisible"] ||
        [key isEqualToString: @"title"] ||
        [key isEqualToString: @"icon"] ||
        [key isEqualToString: @"parentOpener"] ||
        [key isEqualToString: @"isSelected"] ||
        [key isEqualToString: @"isTeared"] )
    {
        notifies = YES;
    }
    else
    {
        notifies = [super automaticallyNotifiesObserversForKey: key];
    }

    return notifies;
}

#pragma - Properties

- (BOOL) hasIcon
{
    return YES;
}

- (AVTTabDocument*) parentOpener
{
    return _parentOpener;
}

- (void) setParentOpener: (AVTTabDocument*) parentOpener
{
    if( _parentOpener != parentOpener )
    {
        if( _parentOpener )
        {
            [[NSNotificationCenter defaultCenter] removeObserver: self
                                                            name: AVTTabDocumentDidCloseNotification
                                                          object: _parentOpener];
        }

        [self willChangeValueForKey: @"parentOpener"];
        {
            _parentOpener = parentOpener; // weak
        }
        [self didChangeValueForKey: @"parentOpener"];

        if( _parentOpener )
        {
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector( tabDocumentDidClose: )
                                                         name: AVTTabDocumentDidCloseNotification
                                                       object: _parentOpener];
        }
    }
}

- (BOOL) isVisible
{
    return _isVisible;
}

- (void) setIsVisible: (BOOL) visible
{
    if( _isVisible != visible && !_isTeared )
    {
        _isVisible = visible;
        if( _isVisible )
        {
            [self tabDidBecomeVisible];
        }
        else
        {
            [self tabDidResignVisible];
        }
    }
}

- (BOOL) isSelected
{
    return _isSelected;
}

- (void) setIsSelected: (BOOL) selected
{
    if( _isSelected != selected && !_isTeared )
    {
        _isSelected = selected;
        if( _isSelected )
        {
            [self tabDidBecomeSelected];
        }
        else
        {
            [self tabDidResignSelected];
        }
    }
}

- (BOOL) isTeared
{
    return _isTeared;
}

- (void) setIsTeared: (BOOL) teared
{
    if( _isTeared != teared )
    {
        _isTeared = teared;
        if( _isTeared )
        {
            [self tabWillBecomeTeared];
        }
        else
        {
            [self tabWillResignTeared];
            [self tabDidBecomeSelected];
        }
    }
}

@end
