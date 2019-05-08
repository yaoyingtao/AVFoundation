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

#import "THRecorderController.h"
#import <AVFoundation/AVFoundation.h>
#import "THMemo.h"
#import "THLevelPair.h"
#import "THMeterTable.h"

@interface THRecorderController () <AVAudioRecorderDelegate>

@property (strong, nonatomic) AVAudioPlayer *player;
@property (strong, nonatomic) AVAudioRecorder *recorder;
@property (strong, nonatomic) THRecordingStopCompletionHandler completionHandler;
@property (strong, nonatomic) THMeterTable *meterTable;


@end

@implementation THRecorderController

- (id)init {
    self = [super init];
    if (self) {
        NSString *tempDir = NSTemporaryDirectory();
        NSString *path = [tempDir stringByAppendingPathComponent:@"memo.caf"];
        NSURL *url = [NSURL fileURLWithPath:path];
        NSDictionary *setting = @{
                                  AVFormatIDKey : @(kAudioFormatAppleIMA4),
                                  AVSampleRateKey : @44100.0f,
                                  AVNumberOfChannelsKey : @1,
                                  AVEncoderBitDepthHintKey : @16,
                                  AVEncoderAudioQualityKey : @(AVAudioQualityMedium),
                                  };
        NSError *error = nil;
        _recorder = [[AVAudioRecorder alloc] initWithURL:url settings:setting error:&error];
        _recorder.delegate = self;
        _recorder.meteringEnabled = YES;
        if (!error) {
            [_recorder prepareToRecord];
        } else {
            NSLog(@"record create fail");
        }
        _meterTable = [[THMeterTable alloc] init];
    }
    return self;
}

- (BOOL)record {
    return [self.recorder record];
}

- (void)pause {
    [self.recorder pause];
}

- (void)stopWithCompletionHandler:(THRecordingStopCompletionHandler)handler {
    self.completionHandler = handler;
    [self.recorder stop];

}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)success {
    if (self.completionHandler) {
        self.completionHandler(success);
    }
}

- (void)saveRecordingWithName:(NSString *)name completionHandler:(THRecordingSaveCompletionHandler)handler {
    NSString *documentPaht = [self doucmentPath];
    NSString *dest = [documentPaht stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf", name]];
    
    NSURL *sourceUrl = self.recorder.url;
    NSURL *destUrl = [NSURL fileURLWithPath:dest];
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] moveItemAtURL:sourceUrl toURL:destUrl error:&error];
    if (success) {
        handler(YES, [THMemo memoWithTitle:name url:destUrl]);
        [self.recorder prepareToRecord];
    } else {
        handler(NO, nil);
    }
}

- (THLevelPair *)levels {
    [self.recorder updateMeters];
    float avgPower = [self.recorder averagePowerForChannel:0];
    float peakPower = [self.recorder peakPowerForChannel:0];
    float linearLevel = [self.meterTable valueForPower:avgPower];
    float linearPeak = [self.meterTable valueForPower:peakPower];
    return [THLevelPair levelsWithLevel:linearLevel peakLevel:linearPeak];
}

- (NSString *)formattedCurrentTime {
    NSInteger currentTime = self.recorder.currentTime;
    NSInteger hour = currentTime / 3600;
    NSInteger min = (currentTime / 60) % 60;
    NSInteger second = currentTime % 60;
    
    return [NSString stringWithFormat:@"%02li:%02li:%02li", (long)hour, (long)min, (long)second];
}

- (BOOL)playbackMemo:(THMemo *)memo {
    [self.player stop];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:memo.url error:nil];
    if (self.player) {
        [self.player play];
        return YES;
    } else {
        return NO;
    }
}

- (NSString *)doucmentPath {
    NSArray *array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return array[0];
}

@end
