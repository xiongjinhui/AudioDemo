//
//  BHAudioManager.h
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHAudioHandle : NSObject

+(instancetype)shareManager;

-(void)start;

-(void)stop;

-(void)readAudioData;
@end

NS_ASSUME_NONNULL_END
