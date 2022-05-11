//
//  BHAudioConfigModel.h
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHAudioConfigModel : NSObject

@property (nonatomic, assign) NSInteger bitrate;//码率

@property (nonatomic, assign) NSInteger channelCount;//声道

@property (nonatomic, assign) NSInteger sampleRate;//采样率

@property (nonatomic, assign) NSInteger sampleSize;//采样点量化

/// 默认初始化方法
+(instancetype)defaultConfig;

@end

NS_ASSUME_NONNULL_END
