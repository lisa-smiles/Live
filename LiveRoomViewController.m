//
//  LiveRoomViewController.m
//  Live
//
//  Created by lisa on 2016/10/31.
//  Copyright © 2016年 wanglifang. All rights reserved.
//

#import "LiveRoomViewController.h"
#import <PLCameraStreamingKit/PLCameraStreamingKit.h>

#define HOST @"http://192.168.200.127:8080"

@interface LiveRoomViewController ()
@property (nonatomic, strong) PLCameraStreamingSession *cameraStreamingSession;
@property (nonatomic, strong) NSString *roomID;
@end

@implementation LiveRoomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.cameraStreamingSession = [self _generateCameraStreamingSession];
    [self requireDevicePermissionWithComplete:^(BOOL granted) {
        if (granted) {
            UIView *preView = self.cameraStreamingSession.previewView;
            preView.frame = self.view.bounds;
            preView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.view addSubview:preView];
        }
    }];
    __weak typeof(self) weakSelf = self;
    [self _generatePushURLWithComplete:^(PLStream *stream) {
        __strong typeof(self)strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.cameraStreamingSession.stream = stream;
            [strongSelf.cameraStreamingSession startWithCompleted:^(BOOL success) {
                if (!success) {
                    NSLog(@"推流失败");
                }
            }];
        }
    }];
}

- (void)requireDevicePermissionWithComplete:(void(^)(BOOL granted))complete {
    switch ([PLCameraStreamingSession cameraAuthorizationStatus]) {
        case PLAuthorizationStatusAuthorized:
            complete(YES);
            break;
            
        case PLAuthorizationStatusNotDetermined:{
            [PLCameraStreamingSession requestCameraAccessWithCompletionHandler:^(BOOL granted) {
                complete(granted);
            }];
            break;
        };
        default:
            complete(NO);
            break;
        
    }
}

- (void)_generatePushURLWithComplete:(void(^)(PLStream *stream))complete {
    NSString *urlStr = [NSString stringWithFormat:@"%@%@",HOST,@"/api/pilipili"];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 10;
    [request setHTTPBody:[@"title=room" dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error;
            if (error != nil || response == nil || data == nil) {
                NSLog(@"获取推流URL失败%@", error);
                return;
            }
            NSDictionary *streamJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            NSLog(@"%@", streamJSON);
            self.roomID = streamJSON[@"id"];
            PLStream *stream = [PLStream streamWithJSON:streamJSON];
            if (complete) {
                complete(stream);
            }
        });
    }];
    [task resume];
}


//推流退出 销毁session
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.cameraStreamingSession destroy];
    [self _notifyServerExitRoom];
}

//主播退出房间 需要通知服务器

- (void)_notifyServerExitRoom {
    if (self.roomID) {
        NSString *url = [NSString stringWithFormat:@"%@%@%@",HOST,@"/api/pilipili",self.roomID];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
        request.HTTPMethod = @"DELETE";
        request.timeoutInterval = 10;
        [[[NSURLSession sharedSession] dataTaskWithRequest:request]resume];
    }
}

//配置CameraStreamingSession中的音频 视频
- (PLCameraStreamingSession *)_generateCameraStreamingSession {
    PLVideoCaptureConfiguration *videoCaptureConfiguration = [PLVideoCaptureConfiguration defaultConfiguration];
    PLVideoStreamingConfiguration *videoStreamingConfiguration = [PLVideoStreamingConfiguration defaultConfiguration];
    PLAudioCaptureConfiguration *audioCaptureConfiguration = [PLAudioCaptureConfiguration defaultConfiguration];
    PLAudioStreamingConfiguration *audioStreamingconfiguration = [PLAudioStreamingConfiguration defaultConfiguration];
    
    //摄像头采集的方向
    AVCaptureVideoOrientation captureOrientation = AVCaptureVideoOrientationPortrait;
    //设置为空，是因为获取这个对象需要网络，会阻塞主线程，需要异步操作获取。
    PLStream *steam = nil;
    return [[PLCameraStreamingSession alloc] initWithVideoCaptureConfiguration:videoCaptureConfiguration
                                            audioCaptureConfiguration:audioCaptureConfiguration videoStreamingConfiguration:videoStreamingConfiguration audioStreamingConfiguration:audioStreamingconfiguration stream:steam videoOrientation:captureOrientation];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
