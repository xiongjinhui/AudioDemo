//
//  ViewController.m
//  AudioDemo
//
//  Created by 熊进辉 on 2021/10/26.
//

#import "ViewController.h"
#import "BHAudioHandle.h"
#import "BHAudioCapture.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [BHAudioCapture checkMicrophoneAuth];
}

- (IBAction)startAction:(UIButton *)sender {
    [[BHAudioHandle shareManager] start];
}
- (IBAction)stopAction:(UIButton *)sender {
    [[BHAudioHandle shareManager] stop];
}
- (IBAction)playBtn:(UIButton *)sender {
    
    [[BHAudioHandle shareManager] readAudioData];
}

@end
