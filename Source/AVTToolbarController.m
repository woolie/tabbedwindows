//
//  AVTTabbedWindows - AVTToolbarController.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/21/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTToolbarController.h"

#import "AVTContainer.h"
#import "AVTGradientView.h"
#import "AVTTabDocument.h"
#import "AVTToolbarView.h"

@interface AVTToolbarController()

- (AVTGradientView*) backgroundGradientView;

@end

@implementation AVTToolbarController

- (id) initWithNibName: (NSString*) nibName
                bundle: (NSBundle*) bundle
             container: (AVTContainer*) container
{
    self = [self initWithNibName: nibName bundle: bundle];
    if( self != nil )
    {
        _container = container; // weak
    }

    return self;
}

- (void) setDividerOpacity: (CGFloat) opacity
{
    AVTGradientView* view = [self backgroundGradientView];
    [view setShowsDivider: (opacity > 0 ? YES: NO)];
    if( [view isKindOfClass: [AVTToolbarView class]] )
    {
        AVTToolbarView* toolbarView = (AVTToolbarView*)view;
        [toolbarView setDividerOpacity: opacity];
    }
}

- (void) updateToolbarWithDocument: (AVTTabDocument*) document
                shouldRestoreState: (BOOL) shouldRestore
{
    // subclasses should implement this
}

// Called after the view is done loading and the outlets have been hooked up.

- (void) awakeFromNib
{
}

- (id) customFieldEditorForObject: (id) obj
{
    return nil;
}

#pragma mark - Private

// (Private) Returns the backdrop to the toolbar.

- (AVTGradientView*) backgroundGradientView
{
    // We really do mean |[super view]| see our override of |-view|.

    NSAssert( [super.view isKindOfClass: [AVTGradientView class]], @"" );

    return (AVTGradientView*)super.view;
}

@end
