//
//  BHAudioCapture.h
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN
@class BHAudioCapture;

@protocol BHAudioCaptureDelegate <NSObject>


/// 采集到音频数据的回调
/// @param capture 当前对象
/// @param sampleBuffer  音频数据
-(void)audioCapture:(BHAudioCapture *)capture sampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 采集发生错误的回调
/// @param capture 当前对象
/// @param error 错误信息
-(void)audioCapture:(BHAudioCapture *)capture error:(NSError *)error;

@end


@interface BHAudioCapture : NSObject

-(instancetype)init UNAVAILABLE_ATTRIBUTE;
//初始化方法
-(instancetype)initWithDelegate:(id<BHAudioCaptureDelegate>)delegate;
//开始采集
-(void)start;
//结束采集
-(void)stop;

/// 麦克风授权
/// 0:未授权，1:已授权，-1:拒绝
+(int)checkMicrophoneAuth;

@end

NS_ASSUME_NONNULL_END
