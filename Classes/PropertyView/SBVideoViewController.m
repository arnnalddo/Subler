//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBVideoViewController.h"
#import "SBMediaTagsController.h"
#import <MP42Foundation/MP42File.h>

@interface SBVideoViewController ()

@property (nonatomic, strong) IBOutlet NSView *forcedView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *forcedHeight;

@property (nonatomic, strong) IBOutlet NSView *profileView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *profileHeight;

@end

@implementation SBVideoViewController
{
    MP42VideoTrack *track;
    MP42File       *mp4file;

    NSViewController *_mediaTagsController;

    IBOutlet NSView *mediaTagsView;

    IBOutlet NSTextField *sampleWidth;
    IBOutlet NSTextField *sampleHeight;

    IBOutlet NSTextField *trackWidth;
    IBOutlet NSTextField *trackHeight;

    IBOutlet NSTextField *hSpacing;
    IBOutlet NSTextField *vSpacing;

    IBOutlet NSTextField *offsetX;
    IBOutlet NSTextField *offsetY;

    IBOutlet NSPopUpButton *alternateGroup;

    IBOutlet NSPopUpButton *videoProfile;

    IBOutlet NSPopUpButton *forcedSubs;
    IBOutlet NSPopUpButton *forced;

    IBOutlet NSButton *preserveAspectRatio;

    IBOutlet NSMenuItem *profileLevelUnchanged;
    
    NSMutableArray<MP42SubtitleTrack *> *_forced;
}

static NSString *getProfileName(uint8_t profile) {
    switch (profile) {
        case 66:
            return @"Baseline";
        case 77:
            return @"Main";
        case 88:
            return @"Extended";
        case 100:
            return @"High";
        case 110:
            return @"High 10";
        case 122:
            return @"High 4:2:2";
        case 144:
            return @"High 4:4:4";
        default:
            return @"Unknown profile";
    }
}

static NSString *getLevelName(uint8_t level) {
    switch (level) {
        case 10:
        case 20:
        case 30:
        case 40:
        case 50:
            return [NSString stringWithFormat:@"%u", level/10];
        case 11:
        case 12:
        case 13:
        case 21:
        case 22:
        case 31:
        case 32:
        case 41:
        case 42:
        case 51:
            return [NSString stringWithFormat:@"%u.%u", level/10, level % 10];
        default:
            return [NSString stringWithFormat:@"unknown level %x", level];
    }
}

- (void)loadView
{
    [super loadView];

    _mediaTagsController = [[SBMediaTagsController alloc] initWithTrack:track];

    (_mediaTagsController.view).frame = mediaTagsView.bounds;
    (_mediaTagsController.view).autoresizingMask = ( NSViewWidthSizable | NSViewHeightSizable );

    [mediaTagsView addSubview:_mediaTagsController.view];

    sampleWidth.stringValue = [NSString stringWithFormat:@"%lld", track.width];
    sampleHeight.stringValue = [NSString stringWithFormat:@"%lld", track.height];
    
    trackWidth.stringValue = [NSString stringWithFormat:@"%d", (uint16_t)track.trackWidth];
    trackHeight.stringValue = [NSString stringWithFormat:@"%d", (uint16_t)track.trackHeight];

    hSpacing.stringValue = [NSString stringWithFormat:@"%lld", track.hSpacing];
    vSpacing.stringValue = [NSString stringWithFormat:@"%lld", track.vSpacing];

    offsetX.stringValue = [NSString stringWithFormat:@"%d", track.offsetX];
    offsetY.stringValue = [NSString stringWithFormat:@"%d", track.offsetY];
    
    [alternateGroup selectItemAtIndex:(NSInteger)track.alternate_group];

    if (track.format == kMP42VideoCodecType_H264 && track.origProfile && track.origLevel) {
        profileLevelUnchanged.title = [NSString stringWithFormat:@"Current profile: %@ @ %@", 
                                         getProfileName(track.origProfile), getLevelName(track.origLevel)];
        if ((track.origProfile == track.newProfile) && (track.origLevel == track.newLevel)) {
            [videoProfile selectItemWithTag:1];
        } else {
            if ((track.newProfile == 66) && (track.newLevel == 21)) {
                [videoProfile selectItemWithTag:6621];
            } else if ((track.newProfile == 77) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:7731];
            } else if ((track.newProfile == 100) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:10031];
            } else if ((track.newProfile == 100) && (track.newLevel == 41)) {
                [videoProfile selectItemWithTag:10041];
            }
        }
    } else {
        self.profileView.hidden = YES;
        self.profileHeight.constant = 0;
    }

    if ([track isKindOfClass:[MP42SubtitleTrack class]]) {
        MP42SubtitleTrack * subTrack = (MP42SubtitleTrack*)track;

        if (!subTrack.someSamplesAreForced && !subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:0];
        } else if (subTrack.someSamplesAreForced && !subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:1];
        } else if (subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:2];
        }

        _forced = [[NSMutableArray alloc] init];

        NSInteger i = 1;
        NSInteger selectedItem = 0;
        for (MP42SubtitleTrack *fileTrack in [mp4file tracksWithMediaType:kMP42MediaType_Subtitle]) {
            NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ - %@ - %@",
                                                                      fileTrack.trackId ? [NSString stringWithFormat:@"%d", fileTrack.trackId] : @"NA",
                                                                      fileTrack.name,
                                                                      fileTrack.language]
                                                              action:@selector(setForcedTrack:)
                                                       keyEquivalent:@""];
            newItem.target = self;
            newItem.tag = i;
            [forced.menu addItem:newItem];
            [_forced addObject:fileTrack];

            if (((MP42SubtitleTrack *)track).forcedTrack == fileTrack)
                selectedItem = i;

            i++;
        }

        [forced selectItemWithTag:selectedItem];
    }
    else {
        self.forcedView.hidden = YES;
        self.forcedHeight.constant = 0;
    }
}

- (void)setTrack:(MP42VideoTrack *)videoTrack
{
    track = videoTrack;
}

- (void)setFile:(MP42File *)mp4
{
    mp4file = mp4;
}

- (IBAction)setSize:(id)sender
{
    NSInteger i;

    if (sender == trackWidth) {
        i = trackWidth.integerValue;
        if (track.trackWidth != i) {
            if (preserveAspectRatio.state == NSOnState) {
                track.trackHeight = (track.trackHeight / track.trackWidth) * i;
                trackHeight.integerValue = (NSInteger)track.trackHeight;
            }
            track.trackWidth = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == trackHeight) {
        i = trackHeight.integerValue;
        if (track.trackHeight != i) {
            track.trackHeight = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == offsetX) {
        i = offsetX.integerValue;
        if (track.offsetX != i) {
            track.offsetX = (uint32_t)i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == offsetY) {
        i = offsetY.integerValue;
        if (track.offsetY != i) {
            track.offsetY = (uint32_t)i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
}

- (IBAction)setPixelAspect:(id)sender
{
    NSInteger i;
    
    if (sender == hSpacing) {
        i = hSpacing.integerValue;
        if (track.hSpacing != i) {
            track.hSpacing = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == vSpacing) {
        i = vSpacing.integerValue;
        if (track.vSpacing != i) {
            track.vSpacing = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
}


- (IBAction)setAltenateGroup:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    
    if (track.alternate_group != tagName) {
        track.alternate_group = tagName;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setProfileLevel:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    switch (tagName) {
        case 1:
            track.newProfile = track.origProfile;
            track.newLevel = track.origLevel;
            return;
        case 6621:
            track.newProfile = 66;
            track.newLevel = 21;
            break;
        case 7731:
            track.newProfile = 77;
            track.newLevel = 31;
            break;
        case 10031:
            track.newProfile = 100;
            track.newLevel = 31;
            break;
        case 10041:
            track.newProfile = 100;
            track.newLevel = 41;
            break;
        default:
            return;
    }

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

- (IBAction)setForcedSubtitles:(id)sender
{
    if ([track isKindOfClass:[MP42SubtitleTrack class]]) {
        MP42SubtitleTrack *subTrack = (MP42SubtitleTrack *)track;
        NSInteger tagName = [sender selectedItem].tag;

        switch (tagName) {
            case 0:
                subTrack.someSamplesAreForced = NO;
                subTrack.allSamplesAreForced = NO;
                break;
            case 1:
                subTrack.someSamplesAreForced = YES;
                subTrack.allSamplesAreForced = NO;
                break;
            case 2:
                subTrack.someSamplesAreForced = YES;
                subTrack.allSamplesAreForced = YES;
                break;
            default:
                return;
        }

        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setForcedTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42SubtitleTrack *subTrack = _forced[index-1];

        if (subTrack != ((MP42SubtitleTrack *)track).forcedTrack) {
            ((MP42SubtitleTrack *)track).forcedTrack = subTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        ((MP42SubtitleTrack *)track).forcedTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}


@end
