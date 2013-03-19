//
//  AVTTabbedWindows - AVTTabWellModelOrderController.m
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 02/04/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import "AVTTabWellModelOrderController.h"

#import "AVTTabDocument.h"

@interface AVTTabWellModelOrderController()

- (NSInteger) validIndexForIndex: (NSInteger) index withRemovingIndex: (NSInteger) removingIndex isRemoving: (BOOL) removing;

@end

@implementation AVTTabWellModelOrderController

- (id) initWithTabWellModel: (AVTTabWellModel*) model
{
    self = [super init];
    if( self != nil )
    {
        _model = [model retain];
        _insertionPolicy = eInsertAfter;
    }

    return self;
}

- (void) dealloc
{
    [_model release];

    [super dealloc];
}

// Determine where to place a newly opened tab by using the supplied transition and foreground flag to figure out how it was opened.

- (NSInteger) determineInsertionIndexForTabDocument: (AVTTabDocument*) newDocument
                                       inForeground: (BOOL) foreground
{
    return self.model.count ? [self determineInsertionIndexForAppending] : 0;
}

// Returns the index to append tabs at.

- (NSInteger) determineInsertionIndexForAppending
{
    return (self.insertionPolicy == eInsertAfter) ? self.model.count : 0;
}

// Determine where to shift selection after a tab is closed is made phantom. If |isRemove| is false, the tab is not being removed but rather made
// phantom (see description of phantom tabs in TabWellModel).

- (NSInteger) determineNewSelectedIndexWithRemovingIndex: (NSInteger) removingIndex
                                                isRemove: (BOOL) isRemove
{
    NSUInteger tabCount = self.model.count;
    NSAssert( removingIndex >= 0 && removingIndex < tabCount, @"" );

    // If the closing tab has a valid parentOpener tab, return its index

    AVTTabDocument* parentOpener = [self.model tabDocumentAtIndex: removingIndex].parentOpener;
    if( parentOpener )
    {
        NSInteger index = [self.model indexOfTabDocument: parentOpener];
        if( index != kNoTab )
            return [self validIndexForIndex: index withRemovingIndex: removingIndex isRemoving: isRemove];
    }

    // No opener set, fall through to the default handler...

    NSInteger selectedIndex = [self.model selectedIndex];
    if( isRemove && selectedIndex >= (tabCount - 1) )
        return selectedIndex - 1;

    return selectedIndex;
}

- (NSInteger) validIndexForIndex: (NSInteger) index
               withRemovingIndex: (NSInteger) removingIndex
                      isRemoving: (BOOL) removing
{
    if( removing && removingIndex < index )
        index = MAX( 0, index - 1 );

    return index;
}

@end
