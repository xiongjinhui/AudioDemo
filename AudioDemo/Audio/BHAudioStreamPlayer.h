//
//  BHAudioStreamPlayer.h
//  AudioDemo
//
//  Created by 熊进辉 on 2022/5/10.
//

#import <Foundation/Foundation.h>
@class BHAudioConfigModel;
@class BHAudioStreamPlayer;
NS_ASSUME_NONNULL_BEGIN

@protocol BHAudioStreamPlayerDelegate <NSObject>

-(void)audioStreamPlayer:(BHAudioStreamPlayer *)player error:(NSError *)error;

@end


@interface BHAudioStreamPlayer : NSObject
@property (nonatomic, weak) id<BHAudioStreamPlayerDelegate> delegate;


-(instancetype)initWithConfig:(BHAudioConfigModel *_Nullable)config;


- (void)audioPlayWithData:(NSData *)data;

-(void)setupSession;

//设置音量大小
- (void)setVolume:(Float32)volume;

@end

NS_ASSUME_NONNULL_END
