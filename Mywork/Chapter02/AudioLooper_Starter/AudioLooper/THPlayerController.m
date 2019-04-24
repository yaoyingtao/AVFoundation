//
//  MIT License
//
//  Copyright (c) 2014 Bob McCune http://bobmccune.com/
//  Copyright (c) 2014 TapHarmonic, LLC http://tapharmonic.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "THPlayerController.h"
#import <AVFoundation/AVFoundation.h>

@interface THPlayerController ()
@property (nonatomic, strong) NSArray <AVAudioPlayer*>*players;
@property (nonatomic, readwrite) BOOL playing;

@end

@implementation THPlayerController

- (instancetype)init {
    self = [super init];
    if (self) {
        AVAudioPlayer *guiterPlayer = [self playerWithName:@"guitar"];
        AVAudioPlayer *bassPlayer = [self playerWithName:@"bass"];
        AVAudioPlayer *drumsPlayer = [self playerWithName:@"drums"];
        self.players = @[guiterPlayer, bassPlayer, drumsPlayer];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)play {
    if (!self.isPlaying) {
        NSTimeInterval delayTime = [self.players[0] currentTime] + 0.1;
        for (AVAudioPlayer *player in self.players) {
            [player playAtTime:delayTime];
        }
    }
    self.playing = YES;
}

- (void)stop {
    for (AVAudioPlayer *player in self.players) {
        [player stop];
        player.currentTime = 0.0f;
    }
    self.playing = NO;
}


- (void)adjustRate:(float)rate {
    for (AVAudioPlayer *player in self.players) {
        player.rate = rate;
    }
}

- (void)adjustPan:(float)pan forPlayerAtIndex:(NSUInteger)index {
    AVAudioPlayer *player = [self.players objectAtIndex:index];
    player.pan = pan;
}

- (void)adjustVolume:(float)volume forPlayerAtIndex:(NSUInteger)index {
    AVAudioPlayer *player = [self.players objectAtIndex:index];
    player.volume = volume;
}

- (AVAudioPlayer *)playerWithName:(NSString *)name {
    NSURL *path = [[NSBundle mainBundle] URLForResource:name withExtension:@"caf"];
    NSError *error;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:path error:&error];
    player.numberOfLoops = -1;
    player.enableRate = YES;
    [player prepareToPlay];
    return player;
}

- (void)handleInterruption:(NSNotification *)notify {
    NSDictionary *userInfo = notify.userInfo;
    AVAudioSessionInterruptionType interruptType = [[userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (interruptType == AVAudioSessionInterruptionTypeBegan) {
        [self stop];
        if (self.delegate) {
            [self.delegate playbackStopped];
        }
    } else if (interruptType == AVAudioSessionInterruptionTypeEnded) {
        AVAudioSessionInterruptionOptions option = [[userInfo objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (option == AVAudioSessionInterruptionOptionShouldResume) {
            [self play];
            if (self.delegate) {
                [self.delegate playbackBegan];
            }
        }

    }
}

- (void)handleRouteChange:(NSNotification *)notify {
    NSDictionary *userInfo = notify.userInfo;
    AVAudioSessionRouteChangeReason reason = [[userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *des = [userInfo objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *port = des.outputs[0];
        if ([port.portType isEqualToString:AVAudioSessionPortHeadphones]) {
            [self stop];
            if (self.delegate) {
                [self.delegate playbackStopped];
            }
        }
    }

}

@end
