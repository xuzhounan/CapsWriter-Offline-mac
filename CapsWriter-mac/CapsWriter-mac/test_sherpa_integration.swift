import Foundation

// 简单的测试函数来验证 sherpa-onnx C API 集成
func testSherpaIntegration() {
    print("🧪 测试 Sherpa-ONNX C API 集成...")
    
    // 创建配置
    var config = SherpaOnnxOnlineRecognizerConfig()
    
    // 测试 enable_endpoint 字段是否可用
    config.enable_endpoint = 1
    print("✅ enable_endpoint 字段可用，值已设置为: \(config.enable_endpoint)")
    
    // 测试其他 endpoint 相关字段
    config.rule1_min_trailing_silence = 2.4
    config.rule2_min_trailing_silence = 1.2
    config.rule3_min_utterance_length = 20.0
    
    print("✅ 所有 endpoint 相关字段都可用:")
    print("   rule1_min_trailing_silence: \(config.rule1_min_trailing_silence)")
    print("   rule2_min_trailing_silence: \(config.rule2_min_trailing_silence)")
    print("   rule3_min_utterance_length: \(config.rule3_min_utterance_length)")
    
    // 测试获取版本信息
    if let versionPtr = SherpaOnnxGetVersionStr() {
        let version = String(cString: versionPtr)
        print("✅ Sherpa-ONNX 版本: \(version)")
    } else {
        print("❌ 无法获取版本信息")
    }
    
    print("🎉 Sherpa-ONNX C API 集成测试完成!")
}

// 在 DEBUG 模式下运行测试
#if DEBUG
testSherpaIntegration()
#endif