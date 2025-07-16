import Foundation

// 测试 C API 是否正确桥接
func testCAPIBridge() {
    print("🧪 测试 C API 桥接...")
    
    // 测试基本类型是否可用
    print("📋 测试基本类型...")
    var config = SherpaOnnxOnlineRecognizerConfig()
    print("✅ SherpaOnnxOnlineRecognizerConfig 可用")
    
    // 测试 enable_endpoint 字段
    config.enable_endpoint = 1
    print("✅ enable_endpoint 字段可用: \(config.enable_endpoint)")
    
    // 测试其他字段
    config.rule1_min_trailing_silence = 2.4
    config.rule2_min_trailing_silence = 1.2
    config.rule3_min_utterance_length = 20.0
    print("✅ 所有 endpoint 相关字段都可用")
    
    // 测试版本函数
    if let versionPtr = SherpaOnnxGetVersionStr() {
        let version = String(cString: versionPtr)
        print("✅ 版本信息: \(version)")
    } else {
        print("❌ 无法获取版本信息")
    }
    
    print("🎉 C API 桥接测试完成!")
}

// 在应用启动时调用测试
#if DEBUG
testCAPIBridge()
#endif