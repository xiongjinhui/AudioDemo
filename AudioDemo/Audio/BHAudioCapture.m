//
//  BHAudioCapture.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "BHAudioCapture.h"


@interface BHAudioCapture()<AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, weak) id<BHAudioCaptureDelegate> delegate;

//音频采集session
@property (nonatomic, strong) AVCaptureSession *captureSession;
//音频输入
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
//音频输出
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
//音频采集队列
@property (nonatomic, strong) dispatch_queue_t audioQueue;
//音频连接
@property (nonatomic, strong) AVCaptureConnection *audioConnect;
//
@property (nonatomic, assign) BOOL isRunning;


@end


@implementation BHAudioCapture

-(instancetype)initWithDelegate:(id<BHAudioCaptureDelegate>)delegate{
    if (self = [super init]) {
        self.delegate = delegate;
        //1.初始化session
        [self captureSession];
        
        //开始配置
        [self.captureSession beginConfiguration];
        //2.添加device，要转成deviceInput
        if ([self.captureSession canAddInput:self.audioDeviceInput]) {
            [self.captureSession addInput:self.audioDeviceInput];
        }
        //3.添加输出设备
        if ([self.captureSession canAddOutput:self.audioDataOutput]) {
            [self.captureSession addOutput:self.audioDataOutput];
        }
        //提交配置
        [self.captureSession commitConfiguration];
        
        //4.创建捕捉连接
        self.audioConnect = [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    }
    return self;
}

- (void)start {
    if (!self.isRunning) {
        self.isRunning = YES;
        [self.captureSession startRunning];
    }

}

- (void)stop {
    if (self.isRunning) {
        self.isRunning = NO;
        [self.captureSession stopRunning];
    }

}

- (void)destroySession {
    if (_captureSession) {
        [self.captureSession removeInput:self.audioDeviceInput];
        [self.captureSession removeOutput:self.audioDataOutput];
    }
    _captureSession = nil;
}

#pragma mark ============ AVCaptureAudioDataOutputSampleBufferDelegate ==============

-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if (connection == self.audioConnect) {
        //音频
        if ([self.delegate respondsToSelector:@selector(audioCapture:sampleBuffer:)]) {
            [self.delegate audioCapture:self sampleBuffer:sampleBuffer];
        }
    }

}

#pragma mark ============ Getter ==============

-(AVCaptureAudioDataOutput *)audioDataOutput{
    if (_audioDataOutput == nil) {
        _audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        [_audioDataOutput setSampleBufferDelegate:self queue:self.audioQueue];
    }
    return _audioDataOutput;
}

-(AVCaptureDeviceInput *)audioDeviceInput{
    if (_audioDeviceInput == nil) {
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        
        NSError *audioDeviceInputError;
        _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&audioDeviceInputError];
        if (audioDeviceInputError) {
            NSLog(@"初始化音频输入对象失败:%@",audioDeviceInputError);
            if ([self.delegate respondsToSelector:@selector(audioCapture:error:)]) {
                [self.delegate audioCapture:self error:audioDeviceInputError];
            }
        }
    }
    return _audioDeviceInput;
}

-(AVCaptureSession *)captureSession{
    if (_captureSession == nil) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}

-(dispatch_queue_t)audioQueue{
    if (_audioQueue == nil) {
        //串行队列
        _audioQueue = dispatch_queue_create("queue.audio.capture.midea", DISPATCH_QUEUE_SERIAL);
    }
    return _audioQueue;
}


-(void)dealloc {
    [self destroySession];
}



/// 麦克风授权
/// 0:未授权，1:已授权，-1:拒绝
+(int)checkMicrophoneAuth {
    int result = 0;
    AVAudioSessionRecordPermission permission = [[AVAudioSession sharedInstance] recordPermission];
    switch (permission) {
        case AVAudioSessionRecordPermissionUndetermined:{
            //未授权
            //请求授权
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                
            }];
            result = 0;
            break;
        }
        case AVAudioSessionRecordPermissionDenied: {
            //拒绝
            result = -1;
            break;
        }
        case AVAudioSessionRecordPermissionGranted: {
            //允许
            result = 1;
            break;
        }
    }
    return result;
}
@end
