//
//  BHAudioManager.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "BHAudioHandle.h"
#import "BHAudioCapture.h"
#import "BHAudioEncoder.h"
#import "BHAudioStreamPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface BHAudioHandle ()<BHAudioCaptureDelegate,BHAudioEncoderDelegate>
@property (nonatomic, strong) BHAudioCapture *audioCapture;
@property (nonatomic, strong) BHAudioEncoder *audioEncoder;
@property (nonatomic, strong) BHAudioStreamPlayer *player;

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end


@implementation BHAudioHandle

+(instancetype)shareManager{
    static BHAudioHandle *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BHAudioHandle alloc] init];
    });
    return manager;
}

-(void)start{
    [self.audioCapture start];
    
    NSString *path = [self audioPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];

    [self writeDataToFilePath:path];
}

-(NSString *)audioPath {
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"audio.mp3"];
}

-(void)readAudioData{
    if (self.filePath == nil) {
        self.filePath = [self audioPath];
        
    }
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
    NSData *data =  [self.fileHandle readDataToEndOfFile];
    
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
    [self.audioPlayer play];
}

-(void)stop{
    [self.audioCapture stop];
    [self.fileHandle closeFile];
    NSLog(@"文件写入路径:%@",self.filePath);
}



-(void)writeDataToFilePath:(NSString *)filePath {
    self.filePath = filePath;
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

#pragma mark ============ BHAudioEncoderDelegate ==============

-(void)audioEncoder:(BHAudioEncoder *)encoder pcmData:(NSData *)data{
    NSLog(@"音频编码PCM数据：%@",data.description);
    [self.player audioPlayWithData:data];
}

-(void)audioEncoder:(BHAudioEncoder *)encoder aacEncodeData:(NSData *)data{
    NSLog(@"音频编码AAC数据：%@",data.description);
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
}

-(void)audioEncoder:(BHAudioEncoder *)encoder encodeError:(NSError *)error{
    NSLog(@"音频编码错误：%@",error);
}

#pragma mark ============ BHAudioCaptureDelegate ==============
-(void)audioCapture:(BHAudioCapture *)capture sampleBuffer:(CMSampleBufferRef)buffer {
    NSLog(@"音频采集数据:%p",buffer);
//    [self.audioEncoder audioAACEncodeWithSampleBuffer:buffer needADTS:YES];
    [self.audioEncoder audioPCMDataWithSampleBuffer:buffer];
    
    
}

-(void)audioCapture:(BHAudioCapture *)capture error:(NSError *)error{
    NSLog(@"音频采集错误:%@",error);
}
#pragma mark ============ Getter ==============

-(BHAudioStreamPlayer *)player {
    if (_player == nil) {
        _player = [[BHAudioStreamPlayer alloc] initWithConfig:[BHAudioConfigModel defaultConfig]];
    }
    return _player;
}
-(BHAudioCapture *)audioCapture{
    if (_audioCapture == nil) {
        _audioCapture = [[BHAudioCapture alloc] initWithDelegate:self];
    }
    return _audioCapture;
}

-(BHAudioEncoder *)audioEncoder{
    if (_audioEncoder == nil) {
        _audioEncoder = [[BHAudioEncoder alloc] initWithConfig:[BHAudioConfigModel defaultConfig]];
        _audioEncoder.delegate = self;
    }
    return _audioEncoder;
}

@end
