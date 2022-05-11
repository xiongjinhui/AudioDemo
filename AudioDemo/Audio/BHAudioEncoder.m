//
//  BHAudioEncode.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "BHAudioEncoder.h"

#import <AudioToolbox/AudioToolbox.h>

@interface BHAudioEncoder ()
//音频编码队列
@property (nonatomic, strong) dispatch_queue_t encodeQueue;
//回调编码结果队列
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
// PCM缓存区
@property (nonatomic) char *pcmBuffer;
//PCM缓存区大小
@property (nonatomic, assign) size_t pcmBufferSize;

//
@property (nonatomic, strong) BHAudioConfigModel *config;

@end


@implementation BHAudioEncoder
{
    //音频转换器对象，需要在使用完成后手动销毁
    AudioConverterRef _audioConverter;
}

static OSStatus aacEncodeInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData){
    
    //
    BHAudioEncoder *encoder = (__bridge BHAudioEncoder *)inUserData;
    //判断pcmBufferSize的大小
    if (!encoder.pcmBufferSize) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    //填充
    ioData->mBuffers[0].mData = encoder.pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = (uint32_t)encoder.pcmBufferSize;
    ioData->mBuffers[0].mNumberChannels = (uint32_t)encoder.config.channelCount;
    
    //填充完毕，则清空数据
    encoder.pcmBufferSize = 0;
    *ioNumberDataPackets = 1;
    return noErr;
}

-(instancetype)initWithConfig:(BHAudioConfigModel *)config{
    if (self = [super init]) {
        //初始化队列
        self.encodeQueue = dispatch_queue_create("encode.queue.audio.midea", DISPATCH_QUEUE_SERIAL);
        self.callbackQueue = dispatch_queue_create("callback.queue.audio.midea", DISPATCH_QUEUE_SERIAL);
        //初始化数据
        _audioConverter = NULL;
        _pcmBuffer = NULL;
        _pcmBufferSize = 0;
        //保存音频配置
        if (config) {
            self.config = config;
        }else{
            self.config = [BHAudioConfigModel defaultConfig];
        }

    }
    return self;
}

-(void)audioPCMDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    
    NSData *pcmData = [self converterAudioSampleBufferToPCMData:sampleBuffer error:NULL];
    if ([self.delegate respondsToSelector:@selector(audioEncoder:pcmData:)]) {
        [self.delegate audioEncoder:self pcmData:pcmData];
    }
}

-(void)audioAACEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer needADTS:(BOOL)adts{
    CFRetain(sampleBuffer);
    if (!_audioConverter) {
        //创建音频转换器
        [self setupEncodeConverterWithSampleBuffer:sampleBuffer];
    }
    
    //音频编码队列
    dispatch_async(self.encodeQueue, ^{
        //获取CMBockBuffer,里面存储了PCM数据
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CFRetain(blockBuffer);
        //获取blockBuffer中PCM数据的大小和地址
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
        
        NSError *error = nil;
        if (status != kCMBlockBufferNoErr) {
            error = [self happenErrorWithStatus:status];
            NSLog(@"Error: AAC硬编码,获取pcm数据失败， %@",error);
            return;
        }
        //开辟pcm内存空间
        uint8_t *pcmBuffer = malloc(_pcmBufferSize);
        //将_pcmBufferSize数据set到pcmBuffer中
        memset(pcmBuffer, 0, _pcmBufferSize);

        //将pcmBuffer数据填充到bufferlist中
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;//固定1
        outAudioBufferList.mBuffers[0].mNumberChannels = (uint32_t)_config.channelCount;
        outAudioBufferList.mBuffers[0].mDataByteSize   = (uint32_t)_pcmBufferSize;
        outAudioBufferList.mBuffers[0].mData           = pcmBuffer;
        
        //输出包大小为1
        UInt32 outputDataPacketSize = 1;
        //获取输出数据
        status = AudioConverterFillComplexBuffer(_audioConverter, aacEncodeInputDataProc, (__bridge void *)self, &outputDataPacketSize, &outAudioBufferList, NULL);
        if (status != noErr) {
            error = [self happenErrorWithStatus:status];
            NSLog(@"Error:AAC编码失败,%@",error);
        }else{
            //获取数据
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            free(pcmBuffer);
            if (adts) {
                //添加ADTS头，想要获取裸流时，请忽略ADTS头，写入文件时，必须添加
                NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
                NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                [fullData appendData:rawAAC];
                //回调数据
                dispatch_async(_callbackQueue, ^{
                    if ([self.delegate respondsToSelector:@selector(audioEncoder:aacEncodeData:)]) {
                        [self.delegate audioEncoder:self aacEncodeData:fullData.copy];
                    }
                });
            }else{
                //回调数据
                dispatch_async(_callbackQueue, ^{
                    if ([self.delegate respondsToSelector:@selector(audioEncoder:aacEncodeData:)]) {
                        [self.delegate audioEncoder:self aacEncodeData:rawAAC];
                    }
                });
            }
        }
        
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);

    });

}

-(NSError *)happenErrorWithStatus:(OSStatus)status{
    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    if ([self.delegate respondsToSelector:@selector(audioEncoder:encodeError:)]) {
        [self.delegate audioEncoder:self encodeError:error];
    }

    return error;
}

/// 创建音频转换器
/// @param sampleBuffer  原始数据
-(void)setupEncodeConverterWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    //获取sampleBuffer数据
    //
    CMAudioFormatDescriptionRef formatSampleBufferRef = CMSampleBufferGetFormatDescription(sampleBuffer);
    AudioStreamBasicDescription inputAudioDes = *CMAudioFormatDescriptionGetStreamBasicDescription(formatSampleBufferRef);
    //设置解码参数
    AudioStreamBasicDescription outputAudioDes = {0};
    outputAudioDes.mSampleRate       = (Float64)self.config.sampleRate;     //采样率
    outputAudioDes.mFormatID         = kAudioFormatMPEG4AAC;                //输出格式
    outputAudioDes.mFormatFlags      = kMPEG4Object_AAC_LC;                 //压缩质量（0代表无损压缩）
    outputAudioDes.mBytesPerPacket   = 0;                                   //packet包大小
    outputAudioDes.mFramesPerPacket  = 1024;                                //每一个packet帧数
    outputAudioDes.mBytesPerFrame    = 0;                                   //每一帧的大小
    outputAudioDes.mChannelsPerFrame = (uint32_t)self.config.channelCount;  //输出声道数
    outputAudioDes.mBitsPerChannel   = 0;                                   //数据帧中每个通道的采样位数
    outputAudioDes.mReserved         = 0;                                   //对齐方式（0:8字节对齐）
    
    //填充输出相关信息
    UInt32 outDesSize = sizeof(outputAudioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &outDesSize, &outputAudioDes);
    
    //获取解码器的描述信息(只能传software)
    AudioClassDescription *audioClassDesc = [self getAudioClassDescriptionWithType:outputAudioDes.mFormatID fromManufacture:kAppleSoftwareAudioCodecManufacturer];
    
    //创建converter
    /*
     参数1：输入音频格式描述
     参数2：输出音频格式描述
     参数3：class desc的数量
     参数4：class desc
     参数5：创建的解码器
     */
    OSStatus status = AudioConverterNewSpecific(&inputAudioDes, &outputAudioDes, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"Error:硬编码AAC，创建Converter失败,status = %d",status);
        [self happenErrorWithStatus:status];
        return;
    }
    
    //设置编码质量
    /*
     kAudioConverterQuality_Max                              = 0x7F,
     kAudioConverterQuality_High                             = 0x60,
     kAudioConverterQuality_Medium                           = 0x40,
     kAudioConverterQuality_Low                              = 0x20,
     kAudioConverterQuality_Min                              = 0
     */

    UInt32 quality = kAudioConverterQuality_High;
    //编码器的呈现质量
    status = AudioConverterSetProperty(_audioConverter, kAudioConverterCodecQuality, sizeof(quality), &quality);
    if (status != noErr) {
        NSLog(@"Error:硬编码AAC，设置编码质量失败 ，status = %d",status);
        [self happenErrorWithStatus:status];
    }
    //设置比特率
    uint32_t audioBitrate = (uint32_t)self.config.bitrate;
    uint32_t audioBitrateSize = sizeof(audioBitrate);
    status = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, audioBitrateSize, &audioBitrate);
    if (status != noErr) {
        NSLog(@"Error:硬编码AAC，设置比特率失败 ，status = %d",status);
        [self happenErrorWithStatus:status];
    }


}

-(AudioClassDescription *)getAudioClassDescriptionWithType:(AudioFormatID)type fromManufacture:(uint32_t)manufacture{
    static AudioClassDescription desc;
    UInt32 encoderSpecific = type;
    //获取满足AAC编码器的总大小
    UInt32 size;
    
    /**
     参数1：编码器类型
     参数2：类型描述大小
     参数3：类型描述
     参数4：大小
     */
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size);
    if (status != noErr) {
        //
        NSLog(@"Error:硬编码AAC get info 失败，status = %d",status);
        [self happenErrorWithStatus:status];
        return nil;
    }
    //计算AAC编码器的个数
    unsigned int count = size / sizeof(AudioClassDescription);
    //创建一个包含count个数编码器的数组
    AudioClassDescription description[count];
    //将满足AAC编码器的信息写入数组
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size, &description);
    if (status != noErr) {
        NSLog(@"Error:硬编码AAC get property失败,status = %d",status);
        [self happenErrorWithStatus:status];
        return nil;
    }

    for (int i =0; i < count; i++) {
        if (type == description[i].mSubType && manufacture == description[i].mManufacturer) {
            desc = description[i];
            return &desc;
        }

    }


    return nil;
}

-(NSData *)converterAudioSampleBufferToPCMData:(CMSampleBufferRef)sampleBuffer error:(NSError **)error{
    //获取pcm数据大小
    size_t size = CMSampleBufferGetTotalSampleSize(sampleBuffer);
    //分配空间
    int8_t *audioData = malloc(size);
    memset(audioData, 0, size);
    //获取CMBlockBuffer
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    //将数据copy的audioData
    OSStatus status = CMBlockBufferCopyDataBytes(blockBuffer, 0, size, audioData);

    if (status != noErr) {
        *error = [self happenErrorWithStatus:status];
        return nil;
    }

    //
    NSData *pcmData = [NSData dataWithBytes:audioData length:size];
    free(audioData);
    return pcmData;
}

//获取ADTS头

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  AAC ADtS头
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*)adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //3： 48000 Hz、4：44.1KHz、8: 16000 Hz、11: 8000 Hz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;    // 11111111      = syncword
    packet[1] = (char)0xF9;    // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

@end
