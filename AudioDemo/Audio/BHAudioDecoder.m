//
//  BHAudioDecoder.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "BHAudioDecoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "BHAudioConfigModel.h"

typedef struct {
    char *data;
    UInt32 size;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDesc;
} BHAudioUserData;

@interface BHAudioDecoder ()

@property (nonatomic, strong) dispatch_queue_t decodeQueue;//编码队列
@property (nonatomic, strong) dispatch_queue_t callbackQueue;//回调队列
@property (nonatomic, assign) AudioConverterRef audioConverter;//音频转换器

@property (nonatomic, assign) char * aacBuffer;//aac数据
@property (nonatomic, assign) UInt32 aacBufferSize;//aac数据大小

@property (nonatomic, strong) BHAudioConfigModel *config;//解码配置信息
@property (nonatomic, assign) AudioStreamPacketDescription *packetDesc;//音频流包信息


@end


@implementation BHAudioDecoder


//解码回调函数
static OSStatus AudioDecoderConverterComplexInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData){
    BHAudioUserData *audioDecoder = (BHAudioUserData *)inUserData;
    if (audioDecoder->size == 0) {
        ioNumberDataPackets = 0;
        return -1;
    }
    
    //开始填充数据
    *outDataPacketDescription = &audioDecoder->packetDesc;
    (*outDataPacketDescription)[0].mStartOffset = 0;
    (*outDataPacketDescription)[0].mDataByteSize = audioDecoder->size;
    (*outDataPacketDescription)[0].mVariableFramesInPacket = 0;
    //
    ioData->mBuffers[0].mData = audioDecoder->data;
    ioData->mBuffers[0].mNumberChannels = audioDecoder->channelCount;
    ioData->mBuffers[0].mDataByteSize = audioDecoder->size;
    
    return noErr;
}


-(instancetype)initWithConfig:(BHAudioConfigModel *)config{
    if (self = [super init]) {
        
        _config = config ? : [BHAudioConfigModel defaultConfig];
        
        _decodeQueue = dispatch_queue_create("aac.decode.queue.audio.midea", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("aac.callback.queue.audio.midea", DISPATCH_QUEUE_SERIAL);
        
        _audioConverter = NULL;
        _aacBuffer = NULL;
        _aacBufferSize = 0;
        
        AudioStreamPacketDescription desc = {0};
        _packetDesc = &desc;
        
        [self setupDecoder];
    }
    return self;
}


-(void)decodeAudioAACData:(NSData *)aacData{
    if (!_audioConverter) {
        return;
    }

    dispatch_async(_decodeQueue, ^{
        //记录AAC数据作为参数传入解码函数
        BHAudioUserData userData = {0};
        userData.channelCount = (UInt32)self->_config.channelCount;
        userData.size = (UInt32)aacData.length;
        userData.data = (char *)aacData.bytes;
        userData.packetDesc.mDataByteSize = (UInt32)aacData.length;
        userData.packetDesc.mStartOffset = 0;
        userData.packetDesc.mVariableFramesInPacket = 0;
        
        //输出的 pcm
        UInt32 pcmBufferSize = (UInt32)(self->_config.channelCount * 2048);
        
        //开辟pcm数据空间
        char *pcmBuffer = malloc(pcmBufferSize);
        memset(pcmBuffer, 0, pcmBufferSize);
        
        //pcmBuffer 转成 bufferList
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mDataByteSize = pcmBufferSize;
        outAudioBufferList.mBuffers[0].mNumberChannels = (UInt32)self->_config.channelCount;
        outAudioBufferList.mBuffers[0].mData = pcmBuffer;
        
        
        AudioStreamPacketDescription outputPacketDesc = {0};
        
        UInt32 pcmDataPacketSize = 1024;
        
       OSStatus status =  AudioConverterFillComplexBuffer(_audioConverter, AudioDecoderConverterComplexInputDataProc, &userData, &pcmDataPacketSize, &outAudioBufferList, &outputPacketDesc);
        if (status != noErr) {
            NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            [self happendError:error];
            return;
        }
        
        //如果获取到了数据，则回调
        if (outAudioBufferList.mBuffers[0].mDataByteSize > 0) {
            NSData *pcmData = [[NSData alloc] initWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            dispatch_async(_callbackQueue, ^{
                if ([self.delegate respondsToSelector:@selector(audioDecoder:pcmData:)]) {
                    [self.delegate audioDecoder:self pcmData:pcmData];
                }
            });
        }

        free(pcmBuffer);
    });
}

-(void)setupDecoder{
    //输出参数pcm
    AudioStreamBasicDescription outputAudioDesc = {0};
    outputAudioDesc.mSampleRate = (Float64)_config.sampleRate;//采样率
    outputAudioDesc.mChannelsPerFrame = (UInt32)_config.channelCount;//输出声道数
    outputAudioDesc.mFormatID = kAudioFormatLinearPCM;//输出格式
    outputAudioDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; //编码12
    outputAudioDesc.mFramesPerPacket = 1;//每一个packet包帧数
    outputAudioDesc.mBitsPerChannel = 16;//数据帧中每个通道的采样位数
    outputAudioDesc.mBytesPerFrame = outputAudioDesc.mBitsPerChannel / 8 * outputAudioDesc.mChannelsPerFrame;//每一帧的大小 = 采样位数 / 8 * 声道数
    outputAudioDesc.mBytesPerPacket = outputAudioDesc.mBytesPerFrame * outputAudioDesc.mFramesPerPacket;//每个packet包的大小 = 帧大小 * 帧数
    outputAudioDesc.mReserved = 0 ;//对其方式（0:8字节对齐）
    
    //输出参数aac
    AudioStreamBasicDescription inputAudioDesc = {0};
    inputAudioDesc.mSampleRate = (Float64)_config.channelCount;//采样率
    inputAudioDesc.mFormatID = kAudioFormatMPEG4AAC;//输出格式
    inputAudioDesc.mFormatFlags = kMPEG4Object_AAC_LC;
    inputAudioDesc.mFramesPerPacket = 1024;//包帧数
    inputAudioDesc.mChannelsPerFrame = (UInt32)_config.channelCount;//声道数
    
    //填充输出参数
    UInt32 inDescSize = sizeof(inputAudioDesc);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &inDescSize, &inputAudioDesc);
    
    //获取解码器描述信息(只能传software)
    AudioClassDescription *audioClassDesc = [self getAudioClassDescriptionWithType:outputAudioDesc.mFormatID formManufacture:kAppleSoftwareAudioCodecManufacturer];
    
    //创建转换器
    /** 创建converter
     参数1：输入音频格式描述
     参数2：输出音频格式描述
     参数3：class desc的数量
     参数4：class desc
     参数5：创建的解码器
     */
    OSStatus status = AudioConverterNewSpecific(&inputAudioDesc, &outputAudioDesc, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        [self happendError:error];
    }

}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(AudioFormatID)type formManufacture:(UInt32)manufacture {
    
    UInt32 decoderSpecific = type;
    UInt32 size;
    //获取满足AAC解码器的总大小
    /**
     参数1：编码器类型（解码）
     参数2：类型描述大小
     参数3：类型描述
     参数4：大小
     */
    OSStatus status =AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, sizeof(decoderSpecific), &decoderSpecific, &size);
    if (status != noErr) {
        NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        [self happendError:error];
        return nil;
    }

    //计算解码器的个数
    unsigned int count = size / sizeof(AudioClassDescription);
    
    //创建解码器数组
    AudioClassDescription description[count];
    
    //将解码器信息写入数组
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(decoderSpecific), &decoderSpecific, &size, &description);
    if (status != noErr) {
        NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        [self happendError:error];
        return nil;
    }
    
    static AudioClassDescription desc;

    for (int i = 0; i< count; i++) {
        AudioClassDescription desc0 = description[i];
        if (type == desc0.mSubType && manufacture == desc0.mManufacturer) {
            desc = desc0;
            return &desc;
        }
    }
    
    return nil;
}

-(void)happendError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(audioDecoder:error:)]) {
        [self.delegate audioDecoder:self error:error];
    }
}


-(void)dealloc{
    if (_audioConverter) {
        AudioConverterDispose(_audioConverter);
        _audioConverter = NULL;
    }
}

@end
