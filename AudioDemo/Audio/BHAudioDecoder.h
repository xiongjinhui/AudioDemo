//
//  BHAudioDecoder.h
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import <Foundation/Foundation.h>
@class BHAudioDecoder;

@class BHAudioConfigModel;

NS_ASSUME_NONNULL_BEGIN

@protocol BHAudioDecoderDelegate <NSObject>

-(void)audioDecoder:(BHAudioDecoder *)decoder error:(NSError *)error;

-(void)audioDecoder:(BHAudioDecoder *)decode pcmData:(NSData *)data;
@end

@interface BHAudioDecoder : NSObject
@property (nonatomic, weak) id<BHAudioDecoderDelegate> delegate;


-(instancetype)initWithConfig:(BHAudioConfigModel *)config;
-(void)decodeAudioAACData:(NSData *)aacData;

@end

NS_ASSUME_NONNULL_END
