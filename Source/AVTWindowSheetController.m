//
//  AVTWindowSheetController.m
//
//  Copyright 2009 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "AVTWindowSheetController.h"

@interface AVTWSCSheetInfo : NSObject
{
    @public
    __weak NSWindow*    overlayWindow_;

    // delegate data

    __weak id           modalDelegate_;
    SEL                 didEndSelector_;
    void*               contextInfo_;

    // sheet info

    CGFloat             sheetAlpha_;
    NSRect              sheetFrame_; // relative to overlay window
    BOOL                sheetAutoresizesSubviews_;
}

@end

@implementation AVTWSCSheetInfo
@end

// The information about how to call up various AppKit-implemented sheets

struct AVTWSCSystemSheetInfo
{
    NSString* className_;
    NSString* methodSignature_;
    NSUInteger modalForWindowIndex_;
    NSUInteger modalDelegateIndex_;
    NSUInteger didEndSelectorIndex_;
    NSUInteger contextInfoIndex_;
    // Callbacks invariably take three parameters. The first is always an id, the
    // third always a void*, but the second can be a BOOL (8 bits), an int (32
    // bits), or an id or NSInteger (64 bits in 64 bit mode). This is the size of
    // the argument in 64-bit mode.
    NSUInteger arg1OfEndSelectorSize_;
};

@interface AVTWindowSheetController (PrivateMethods)

- (void) beginSystemSheet: (id)systemSheet
                 withInfo:(const struct AVTWSCSystemSheetInfo*)info
             modalForView:(NSView*)view
           withParameters:(NSArray*)params;
- (const struct AVTWSCSystemSheetInfo*) infoForSheet: (id) systemSheet;
- (void) notificationHappened: (NSNotification*) notification;
- (void) viewDidChangeSize: (NSView*) view;
- (NSRect) screenFrameOfView: (NSView*) view;
- (void) sheetDidEnd: (id) sheet
         returnCode8: (char) returnCode
         contextInfo: (void*) contextInfo;
- (void) sheetDidEnd: (id) sheet
        returnCode32: (int) returnCode
         contextInfo: (void*) contextInfo;
- (void) sheetDidEnd: (id) sheet
        returnCode64: (NSInteger) returnCode
         contextInfo: (void*) contextInfo;
- (void) sheetDidEnd: (id) sheet
          returnCode: (NSInteger) returnCode
         contextInfo: (void*) contextInfo
            arg1Size: (int) size;
- (void) systemRequestsVisibilityForWindow: (NSWindow*) window;
- (NSRect) window: (NSWindow*) window
willPositionSheet: (NSWindow*) sheet
        usingRect: (NSRect) defaultSheetRect;
@end

@interface AVTWSCOverlayWindow : NSWindow
{
    AVTWindowSheetController* sheetController_;
}

- (id) initWithContentRect: (NSRect) contentRect sheetController: (AVTWindowSheetController*) sheetController;
- (void) makeKeyAndOrderFront: (id) sender;

@end

@implementation AVTWSCOverlayWindow

- (id) initWithContentRect: (NSRect) contentRect
           sheetController: (AVTWindowSheetController*) sheetController
{
    self = [super initWithContentRect: contentRect
                            styleMask: NSBorderlessWindowMask
                              backing: NSBackingStoreBuffered
                                defer: NO];
    if( self != nil )
    {
        sheetController_ = sheetController;
        [self setOpaque: NO];
        [self setBackgroundColor: [NSColor clearColor]];
        [self setIgnoresMouseEvents: NO];
    }

    return self;
}

- (void) makeKeyAndOrderFront: (id) sender
{
    [sheetController_ systemRequestsVisibilityForWindow: self];
}

@end

@implementation AVTWindowSheetController

- (id) initWithWindow: (NSWindow*) window
             delegate: (id<AVTWindowSheetControllerDelegate>) delegate
{
    self = [super init];
    if( self != nil )
    {
        window_ = window;
        delegate_ = delegate;
        sheets_ = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) finalize
{
    assert( [sheets_ count] == 0 );
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [super finalize];
}

- (void) dealloc
{
    assert( [sheets_ count] == 0 );
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [sheets_ release];

    [super dealloc];
}

- (void) beginSheet: (NSWindow*) sheet
       modalForView: (NSView*) view
      modalDelegate: (id) modalDelegate
     didEndSelector: (SEL) didEndSelector
        contextInfo: (void*) contextInfo
{
    NSArray* params = [NSArray arrayWithObjects: sheet, [NSNull null], modalDelegate, [NSValue valueWithPointer: didEndSelector],
                                                 [NSValue valueWithPointer: contextInfo],
                                                 nil];
    [self beginSystemSheet: [NSApplication sharedApplication]
              modalForView: view
            withParameters: params];
}

- (void) beginSystemSheet: (id) systemSheet
             modalForView: (NSView*) view
           withParameters: (NSArray*) params
{
    const struct AVTWSCSystemSheetInfo* info = [self infoForSheet: systemSheet];
    if( info )
    {
        [self beginSystemSheet: systemSheet
                      withInfo: info
                  modalForView: view
                withParameters: params];
    } // else already logged
}

- (BOOL) isSheetAttachedToView: (NSView*) view
{
    NSValue* viewValue = [NSValue valueWithNonretainedObject: view];
    return [sheets_ objectForKey: viewValue] != nil;
}

- (NSArray*) viewsWithAttachedSheets
{
    NSMutableArray* views = [NSMutableArray array];
    NSValue* key;
    for( key in sheets_ )
    {
        [views addObject: [key nonretainedObjectValue]];
    }

    return views;
}

- (void) setActiveView: (NSView*) view
{
    // Hide old sheet

    NSValue* oldViewValue = [NSValue valueWithNonretainedObject: activeView_];
    AVTWSCSheetInfo* oldSheetInfo = [sheets_ objectForKey: oldViewValue];
    if( oldSheetInfo )
    {
        NSWindow* overlayWindow = oldSheetInfo->overlayWindow_;
        assert( overlayWindow );
        NSWindow* sheetWindow = [overlayWindow attachedSheet];
        assert( sheetWindow );

        // Why do we hide things this way?
        // - Keeping it local but alpha 0 means we get good Expose behavior
        // - Resizing it to 0 means we get no blurring effect left over

        oldSheetInfo->sheetAlpha_ = [sheetWindow alphaValue];
        [sheetWindow setAlphaValue: (CGFloat)0.0];

        oldSheetInfo->sheetAutoresizesSubviews_ =
            [[sheetWindow contentView] autoresizesSubviews];
        [[sheetWindow contentView] setAutoresizesSubviews: NO];

        NSRect overlayFrame = [overlayWindow frame];
        oldSheetInfo->sheetFrame_ = [sheetWindow frame];
        oldSheetInfo->sheetFrame_.origin.x -= overlayFrame.origin.x;
        oldSheetInfo->sheetFrame_.origin.y -= overlayFrame.origin.y;
        [sheetWindow setFrame: NSZeroRect display: NO];

        [overlayWindow setIgnoresMouseEvents: YES];

        // Make sure the now invisible sheet doesn't keep keyboard focus
        [[overlayWindow parentWindow] makeKeyWindow];
    }

    activeView_ = view;

    // Show new sheet

    NSValue* newViewValue = [NSValue valueWithNonretainedObject: view];
    AVTWSCSheetInfo* newSheetInfo = [sheets_ objectForKey: newViewValue];
    if( newSheetInfo )
    {
        NSWindow* overlayWindow = newSheetInfo->overlayWindow_;
        assert( overlayWindow );
        NSWindow* sheetWindow = [overlayWindow attachedSheet];
        assert( sheetWindow );

        [overlayWindow setIgnoresMouseEvents: NO];

        NSRect overlayFrame = [overlayWindow frame];
        newSheetInfo->sheetFrame_.origin.x += overlayFrame.origin.x;
        newSheetInfo->sheetFrame_.origin.y += overlayFrame.origin.y;
        [sheetWindow setFrame: newSheetInfo->sheetFrame_ display: NO];

        [[sheetWindow contentView]
         setAutoresizesSubviews: newSheetInfo->sheetAutoresizesSubviews_];

        [sheetWindow setAlphaValue: newSheetInfo->sheetAlpha_];

        [self viewDidChangeSize: view];

        [overlayWindow makeKeyWindow];
    }
}

@end

@implementation AVTWindowSheetController (PrivateMethods)

- (void) beginSystemSheet: (id) systemSheet
                 withInfo: (const struct AVTWSCSystemSheetInfo*) info
             modalForView: (NSView*) view
           withParameters: (NSArray*) params
{
    assert( [view window] == window_ /*
                                        Cannot show a sheet for a window for which we are not managing
                                        sheets*/);
    assert( ![self isSheetAttachedToView: view] /*
                                                   Cannot show another sheet for a view while already managing one*/);
    assert( info /*Missing info for the type of sheet*/ );

    AVTWSCSheetInfo* sheetInfo = [[[AVTWSCSheetInfo alloc] init] autorelease];

    sheetInfo->modalDelegate_ = [params objectAtIndex: info->modalDelegateIndex_];
    sheetInfo->didEndSelector_ =
        [[params objectAtIndex: info->didEndSelectorIndex_] pointerValue];
    sheetInfo->contextInfo_ =
        [[params objectAtIndex: info->contextInfoIndex_] pointerValue];

    assert( [sheetInfo->modalDelegate_
             respondsToSelector: sheetInfo->didEndSelector_]
            /* Delegate does not respond to the specified selector*/ );

    [view setPostsFrameChangedNotifications: YES];
    [[NSNotificationCenter defaultCenter]
     addObserver: self
        selector: @selector( notificationHappened: )
            name: NSViewFrameDidChangeNotification
          object: view];

    sheetInfo->overlayWindow_ =
        [[AVTWSCOverlayWindow alloc]
         initWithContentRect: [self screenFrameOfView: view]
             sheetController: self];

    [sheets_ setObject: sheetInfo
                forKey: [NSValue valueWithNonretainedObject: view]];

    [window_ addChildWindow: sheetInfo->overlayWindow_
                    ordered: NSWindowAbove];

    SEL methodSelector = NSSelectorFromString( (NSString*)info->methodSignature_ );
    NSInvocation* invocation =
        [NSInvocation invocationWithMethodSignature:
         [systemSheet methodSignatureForSelector: methodSelector]];
    [invocation setSelector: methodSelector];
    for( NSUInteger i = 0; i < [params count]; ++i )
    {
        // Remember that args 0 and 1 are the target and selector, thus the |i+2|s
        if( i == info->modalForWindowIndex_ )
        {
            [invocation setArgument: &sheetInfo->overlayWindow_ atIndex: i + 2];
        }
        else if( i == info->modalDelegateIndex_ )
        {
            [invocation setArgument: &self atIndex: i + 2];
        }
        else if( i == info->didEndSelectorIndex_ )
        {
            SEL s;
            if( info->arg1OfEndSelectorSize_ == 64 )
                s = @selector( sheetDidEnd:returnCode64:contextInfo: );
            else if( info->arg1OfEndSelectorSize_ == 32 )
                s = @selector( sheetDidEnd:returnCode32:contextInfo: );
            else if( info->arg1OfEndSelectorSize_ == 8 )
                s = @selector( sheetDidEnd:returnCode8:contextInfo: );
            [invocation setArgument: &s atIndex: i + 2];
        }
        else if( i == info->contextInfoIndex_ )
        {
            [invocation setArgument: &view atIndex: i + 2];
        }
        else
        {
            id param = [params objectAtIndex: i];
            if( [param isKindOfClass: [NSValue class]] )
            {
                char buffer[16];
                [param getValue: buffer];
                [invocation setArgument: buffer atIndex: i + 2];
            }
            else
            {
                [invocation setArgument: &param atIndex: i + 2];
            }
        }
    }
    [invocation invokeWithTarget: systemSheet];

    activeView_ = view;
}

- (const struct AVTWSCSystemSheetInfo*) infoForSheet: (id) systemSheet
{
    static const struct AVTWSCSystemSheetInfo kAVTWSCSystemSheetInfoData[] =
    {
        {
            @"ABIdentityPicker",
            @"beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 64,
        },
        {
            @"CBIdentityPicker",
            @"runModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 64,
        },
        {
            @"DRSetupPanel",
            @"beginSetupSheetForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 32,
        },
        {
            @"NSAlert",
            @"beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 32,
        },
        {
            @"NSApplication",
            @"beginSheet:modalForWindow:modalDelegate:didEndSelector:contextInfo:",
            1, 2, 3, 4, 64,
        },
        {
            @"IKFilterBrowserPanel",
            @"beginSheetWithOptions:modalForWindow:modalDelegate:didEndSelector:contextInfo:",
            1, 2, 3, 4, 32,
        },
        {
            @"IKPictureTaker",
            @"beginPictureTakerSheetForWindow:withDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 64,
        },
        {
            @"IOBluetoothDeviceSelectorController",
            @"beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 32,
        },
        {
            @"IOBluetoothObjectPushUIController",
            @"beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 32,
        },
        {
            @"IOBluetoothServiceBrowserController",
            @"beginSheetModalForWindow:modalDelegate:didEndSelector:contextInfo:",
            0, 1, 2, 3, 32,
        },
        {
            @"NSOpenPanel",
            @"beginSheetForDirectory:file:types:modalForWindow:modalDelegate:didEndSelector:contextInfo:",
            3, 4, 5, 6, 32,
        },
        {
            @"NSPageLayout",
            @"beginSheetWithPrintInfo:modalForWindow:delegate:didEndSelector:contextInfo:",
            1, 2, 3, 4, 32,
        },
        {
            @"NSPrintOperation",
            @"runOperationModalForWindow:delegate:didRunSelector:contextInfo:",
            0, 1, 2, 3, 8,
        },
        {
            @"NSPrintPanel",
            @"beginSheetWithPrintInfo:modalForWindow:delegate:didEndSelector:contextInfo:",
            1, 2, 3, 4, 32,
        },
        {
            @"NSSavePanel",
            @"beginSheetForDirectory:file:modalForWindow:modalDelegate:didEndSelector:contextInfo:",
            2, 3, 4, 5, 32,
        },
        {
            @"SFCertificatePanel",
            @"beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:certificates:showGroup:",
            0, 1, 2, 3, 32,
        },
        {
            @"SFCertificateTrustPanel",
            @"beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:trust:message:",
            0, 1, 2, 3, 32,
        },
        {
            @"SFChooseIdentityPanel",
            @"beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:identities:message:",
            0, 1, 2, 3, 32,
        },
        {
            @"SFKeychainSettingsPanel",
            @"beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:settings:keychain:",
            0, 1, 2, 3, 32,
        },
        {
            @"SFKeychainSavePanel",
            @"beginSheetForDirectory:file:modalForWindow:modalDelegate:didEndSelector:contextInfo:",
            2, 3, 4, 5, 32,
        },
    };

    static const size_t kAVTWSCSystemSheetInfoDataSize = sizeof( kAVTWSCSystemSheetInfoData ) / sizeof( kAVTWSCSystemSheetInfoData[0] );

    for( size_t i = 0; i < kAVTWSCSystemSheetInfoDataSize; ++i )
    {
        Class testClass = NSClassFromString( kAVTWSCSystemSheetInfoData[i].className_ );
        if( testClass && [systemSheet isKindOfClass: testClass] )
        {
            return &kAVTWSCSystemSheetInfoData[i];
        }
    }

    NSLog( @"Failed to find info for sheet of type %@", [systemSheet class] );
    return nil;
}

- (void) notificationHappened: (NSNotification*) notification
{
    NSView* view = (NSView*)[notification object];
    [self viewDidChangeSize: view];
}

- (void) viewDidChangeSize: (NSView*) view
{
    AVTWSCSheetInfo* sheetInfo =
        [sheets_ objectForKey: [NSValue valueWithNonretainedObject: view]];
    if( !sheetInfo )
        return;

    if( view != activeView_ )
        return;

    NSWindow* overlayWindow = sheetInfo->overlayWindow_;
    if( !overlayWindow )
        return;

    [overlayWindow setFrame: [self screenFrameOfView: view] display: YES];
    [[overlayWindow attachedSheet] makeKeyWindow];
}

- (NSRect) screenFrameOfView: (NSView*) view
{
    NSRect viewFrame = [view frame];
    viewFrame = [[view superview] convertRect: viewFrame toView: nil];
    viewFrame.origin = [[view window] convertBaseToScreen: viewFrame.origin];
    return viewFrame;
}

- (void) sheetDidEnd: (id) sheet
         returnCode8: (char) returnCode
         contextInfo: (void*) contextInfo
{
    [self sheetDidEnd: sheet
           returnCode: returnCode
          contextInfo: contextInfo
             arg1Size: 8];
}

- (void) sheetDidEnd: (id) sheet
        returnCode32: (int) returnCode
         contextInfo: (void*) contextInfo
{
    [self sheetDidEnd: sheet
           returnCode: returnCode
          contextInfo: contextInfo
             arg1Size: 32];
}

- (void) sheetDidEnd: (id) sheet
        returnCode64: (NSInteger) returnCode
         contextInfo: (void*) contextInfo
{
    [self sheetDidEnd: sheet
           returnCode: returnCode
          contextInfo: contextInfo
             arg1Size: 64];
}

- (void) sheetDidEnd: (id) sheet
          returnCode: (NSInteger) returnCode
         contextInfo: (void*) contextInfo
            arg1Size: (int) size
{
    NSValue* viewKey = [NSValue valueWithNonretainedObject: (NSView*)contextInfo];
    AVTWSCSheetInfo* sheetInfo = [sheets_ objectForKey: viewKey];
    assert( sheetInfo /*Could not find information about the sheet that just
                         ended*/);
    assert( size == 8 || size == 32 || size == 64
            /*Incorrect size information in the sheet entry; don't know how big the
               second parameter is*/);

    // Can't turn off view's frame notifications as we don't know if someone else
    // wants them.

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSViewFrameDidChangeNotification
                                                  object: contextInfo];

    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [sheetInfo->modalDelegate_ methodSignatureForSelector: sheetInfo->didEndSelector_]];
    [invocation setSelector: sheetInfo->didEndSelector_];

    // Remember that args 0 and 1 are the target and selector

    [invocation setArgument: &sheet atIndex: 2];
    if( size == 64 )
    {
        [invocation setArgument: &returnCode atIndex: 3];
    }
    else if( size == 32 )
    {
        int shortReturnCode = (int)returnCode;
        [invocation setArgument: &shortReturnCode atIndex: 3];
    }
    else if( size == 8 )
    {
        char charReturnCode = returnCode;
        [invocation setArgument: &charReturnCode atIndex: 3];
    }
    [invocation setArgument: &sheetInfo->contextInfo_ atIndex: 4];
    [invocation invokeWithTarget: sheetInfo->modalDelegate_];

    [window_ removeChildWindow: sheetInfo->overlayWindow_];
    [sheetInfo->overlayWindow_ release];

    [sheets_ removeObjectForKey: viewKey];
}

- (void) systemRequestsVisibilityForWindow: (NSWindow*) window
{
    NSValue* key;
    for( key in sheets_ )
    {
        AVTWSCSheetInfo* sheetInfo = [sheets_ objectForKey: key];
        if( sheetInfo->overlayWindow_ == window )
        {
            NSView* view = [key nonretainedObjectValue];
            [delegate_ avt_systemRequestsVisibilityForView: view];
        }
    }
}

- (NSRect) window: (NSWindow*) window
willPositionSheet: (NSWindow*) sheet
        usingRect: (NSRect) defaultSheetRect
{
    // Ensure that the sheets come out of the very top of the overlay windows.

    NSRect windowFrame = [window frame];
    defaultSheetRect.origin.y = windowFrame.size.height;
    return defaultSheetRect;
}

@end
