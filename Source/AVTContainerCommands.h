//
//  AVTTabbedWindows - AVTContainerCommands.h
//
//  Copyright (c) 2009 The Chromium Authors. All rights reserved.
//  Modified by Steven Woolgar on 01/28/2013.
//  Copyright (c) 2013 Avatron Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    // Window management commands

    eContainerCommandNewWindow                 = 34000,
    eContainerCommandCloseWindow               = 34012,
    eContainerCommandNewTab                    = 34014,
    eContainerCommandCloseTab                  = 34015,
    eContainerCommandSelectNextTab             = 34016,
    eContainerCommandSelectPreviousTab         = 34017,
    eContainerCommandSelectTab0                = 34018,
    eContainerCommandSelectTab1                = 34019,
    eContainerCommandSelectTab2                = 34020,
    eContainerCommandSelectTab3                = 34021,
    eContainerCommandSelectTab4                = 34022,
    eContainerCommandSelectTab5                = 34023,
    eContainerCommandSelectTab6                = 34024,
    eContainerCommandSelectTab7                = 34025,
    eContainerCommandSelectLastTab             = 34026,
    eContainerCommandDuplicateTab              = 34027,
    eContainerCommandRestoreTab                = 34028,
    eContainerCommandShowAsTab                 = 34029,
    eContainerCommandFullscreen                = 34030,
    eContainerCommandExit                      = 34031,
    eContainerCommandMoveTabNext               = 34032,
    eContainerCommandMoveTabPrevious           = 34033

} AVTContainerCommand;
