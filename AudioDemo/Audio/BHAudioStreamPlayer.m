//
//  BHAudioStreamPlayer.m
//  AudioDemo
//
//  Created by 熊进辉 on 2022/5/10.
//

#import "BHAudioStreamPlayer.h"
#import "BHAudioConfigModel.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

static const int kMinSizePerFrame = 2048;//每帧是小数据长度
static const int kNumberBuffers_play = 3;

typedef struct BHAQPlayerState {
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberBuffers_play];
    AudioStreamPacketDescription *mPacketDescs;
}BHAQPlayerState;


@interface BHAudioStreamPlayer ()
@property (nonatomic, strong) BHAudioConfigModel *config;//
@property (nonatomic, assign) BHAQPlayerState playerState;
@property (nonatomic, assign) BOOL isPlaying;


@end


@implementation BHAudioStreamPlayer


static void TMAudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    AudioQueueFreeBuffer(inAQ, inBuffer);
}


-(instancetype)initWithConfig:(BHAudioConfigModel *_Nullable)config {
    if (self = [super init]) {
        _config = config ? : [BHAudioConfigModel defaultConfig];
        
        //音频输出配置
        AudioStreamBasicDescription dataFormat = {0};
        dataFormat.mSampleRate = (Float64)_config.sampleRate;//采样率
        dataFormat.mChannelsPerFrame = (UInt32)_config.channelCount;//输出声道数
        dataFormat.mFormatID = kAudioFormatLinearPCM; //输出格式
        dataFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;//编码12
        dataFormat.mFramesPerPacket = 1; //每一个packet帧数
        dataFormat.mBitsPerChannel = 16; //数据帧中每个通道的采样位数
        dataFormat.mBytesPerFrame = dataFormat.mBitsPerChannel / 8 * dataFormat.mChannelsPerFrame;//每一帧大小 = 采样位数和/8 * 声道数
        dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame * dataFormat.mFramesPerPacket;//每个packet大小 = 帧大小 * 帧数
        dataFormat.mReserved = 0;
        
        //
        BHAQPlayerState state = {0};
        state.mDataFormat = dataFormat;
        _playerState = state;
        
        [self setupSession];
        
        //创建播放队列
        OSStatus status = AudioQueueNewOutput(&_playerState.mDataFormat, TMAudioQueueOutputCallback, NULL, NULL, NULL, 0, &_playerState.mQueue);
        if (status != noErr) {
            NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            [self happendError:error];
            return self;
        }
        
        [self setVolume:1.0];
        
        _isPlaying = NO;
    }
    return self;
}

- (void)audioPlayWithData:(NSData *)data {
    AudioQueueBufferRef outBuffer;
    
    //分配音频队列缓冲区
    /*
     参数1:要分配缓冲区的音频队列
     参数2:新缓冲区所需的大小
     参数3:输出,指向新分配的音频队列缓冲区
     */
    AudioQueueAllocateBuffer(_playerState.mQueue, kMinSizePerFrame, &outBuffer);
    
    //将音频数据copy到缓冲区
    memcpy(outBuffer->mAudioData, data.bytes, data.length);
    //
    outBuffer->mAudioDataByteSize = (UInt32)data.length;
    
    //将缓冲区数据填充到缓冲队列
    /*
     参数1:拥有音频队列缓冲区的音频队列
     参数2:要添加到缓冲区队列的音频队列缓冲区。
     参数3:inBuffer参数中音频数据包的数目,对于以下任何情况，请使用值0：
            * 播放恒定比特率（CBR）格式时。
            * 当音频队列是录制（输入）音频队列时。
            * 当使用audioqueueallocateBufferWithPacketDescriptions函数分配要重新排队的缓冲区时。在这种情况下，回调应该描述缓冲区的mpackedDescriptions和mpackedDescriptionCount字段中缓冲区的数据包。
     参数4:一组数据包描述。对于以下任何情况，请使用空值
            * 播放恒定比特率（CBR）格式时。
            * 当音频队列是输入（录制）音频队列时。
            * 当使用audioqueueallocateBufferWithPacketDescriptions函数分配要重新排队的缓冲区时。在这种情况下，回调应该描述缓冲区的mpackedDescriptions和mpackedDescriptionCount字段中缓冲区的数据包
     */
    OSStatus status = AudioQueueEnqueueBuffer(_playerState.mQueue, outBuffer, 0, NULL);
    if (status != noErr) {
        NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        [self happendError:error];
    }

    //开始播放/录制音频
    /*
     参数1:要开始的音频队列
     参数2:音频队列应开始的时间。
     要指定相对于关联音频设备时间线的开始时间，请使用audioTimestamp结构的msampletime字段。使用NULL表示音频队列应尽快启动
     */
    AudioQueueStart(_playerState.mQueue, NULL);
    _isPlaying = YES;
}

//暂停播放
- (void)pause {
    _isPlaying = NO;
    AudioQueuePause(_playerState.mQueue);
}
//结束播放
- (void)dispose {
    _isPlaying = NO;
    AudioQueueStop(_playerState.mQueue, true);
    AudioQueueDispose(_playerState.mQueue, true);
}

-(void)setupSession {
    NSError *error1 = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&error1];
    if (error1) {
        [self happendError:error1];
    }

    NSError *error2 = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error2];
    if (error2) {
        [self happendError:error2];
    }

}

//设置音量大小
- (void)setVolume:(Float32)volume {
    if (volume < 0 ) {
        volume = 0;
    }else if (volume > 1.0){
        volume = 1.0;
    }
    
    //设置播放音频队列参数
    AudioQueueSetParameter(_playerState.mQueue, kAudioQueueParam_Volume, volume);

}


-(void)happendError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(audioStreamPlayer:error:)]) {
        [self.delegate audioStreamPlayer:self error:error];
    }
}

@end
