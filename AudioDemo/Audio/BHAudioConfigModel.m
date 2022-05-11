//
//  BHAudioConfigModel.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "BHAudioConfigModel.h"

@implementation BHAudioConfigModel

-(instancetype)init{
    if (self = [super init]) {
        self.bitrate = 96000;
        self.channelCount = 1;
        self.sampleRate = 44100;//44.1kHz
        self.sampleSize = 16;
    }
    return self;
}

+(instancetype)defaultConfig{
    return [[BHAudioConfigModel alloc] init];
}

@end
