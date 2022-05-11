//
//  BHAudioEncode.h
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import <Foundation/Foundation.h>
#import "BHAudioConfigModel.h"
#import <AVFoundation/AVFoundation.h>

@class BHAudioEncoder;

NS_ASSUME_NONNULL_BEGIN

@protocol BHAudioEncoderDelegate <NSObject>

/// AAC音频编码回调
/// @param encoder 当前对象
/// @param data  AAC编码数据
-(void)audioEncoder:(BHAudioEncoder *)encoder aacEncodeData:(NSData *)data;

/// PCM音频数据回调
/// @param encoder 当前对象
/// @param data PCM编码数据
-(void)audioEncoder:(BHAudioEncoder *)encoder pcmData:(NSData *)data;

/// 编码发生错误的回调
/// @param encoder 当前对象
/// @param error 错误信息
-(void)audioEncoder:(BHAudioEncoder *)encoder encodeError:(NSError *)error;

@end


@interface BHAudioEncoder : NSObject

@property (nonatomic, weak) id<BHAudioEncoderDelegate> delegate;


///初始化解码器
/// @param config  音频配置
-(instancetype)initWithConfig:(BHAudioConfigModel *)config;


/// AAC编码
/// @param sampleBuffer  sampleBuffer
/// @param adts  是否需要ADTS头，写入文件的数据必须加ADTS
-(void)audioAACEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer needADTS:(BOOL)adts;

/// PCM编码
/// @param sampleBuffer PCM数据
-(void)audioPCMDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 直接解码SampleBuffer数据
/// @param sampleBuffer  采集原始数据
/// @param error  错误信息
-(NSData *)converterAudioSampleBufferToPCMData:(CMSampleBufferRef)sampleBuffer error:(NSError **)error;

/// 获取ADTS头
/// @param packetLength 编码后的数据长度
-(NSData*)adtsDataForPacketLength:(NSUInteger)packetLength;

@end

NS_ASSUME_NONNULL_END
