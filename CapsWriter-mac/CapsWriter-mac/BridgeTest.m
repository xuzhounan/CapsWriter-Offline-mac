//
//  BridgeTest.m
//  CapsWriter-mac
//
//  Created for testing C API header recognition
//

#import <Foundation/Foundation.h>
#import "Include/c-api.h"

@interface BridgeTest : NSObject
@end

@implementation BridgeTest

+ (void)testCAPIAccess {
    // 测试是否能调用 C API 函数
    const char *version = SherpaOnnxGetVersionStr();
    NSLog(@"Sherpa-ONNX Version: %s", version);
}

@end