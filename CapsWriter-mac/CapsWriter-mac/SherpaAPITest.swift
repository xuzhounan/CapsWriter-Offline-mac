import Foundation

/// 测试 Sherpa-ONNX C API 类型识别
class SherpaAPITest {
    
    /// 测试基本 C API 类型
    func testBasicTypes() {
        print("🧪 测试基本 C API 类型...")
        
        // 测试创建配置结构体
        var config = SherpaOnnxOnlineRecognizerConfig()
        print("✅ SherpaOnnxOnlineRecognizerConfig 创建成功")
        
        // 测试 enable_endpoint 字段
        config.enable_endpoint = 1
        print("✅ enable_endpoint 字段可用: \(config.enable_endpoint)")
        
        // 测试其他 endpoint 相关字段
        config.rule1_min_trailing_silence = 2.4
        config.rule2_min_trailing_silence = 1.2
        config.rule3_min_utterance_length = 20.0
        print("✅ endpoint 相关字段都可用")
        
        // 测试版本信息函数
        if let versionPtr = SherpaOnnxGetVersionStr() {
            let version = String(cString: versionPtr)
            print("✅ 版本信息: \(version)")
        } else {
            print("❌ 无法获取版本信息")
        }
        
        print("🎉 基本类型测试完成!")
    }
    
    /// 测试完整的 C API 流程
    func testFullAPIFlow() {
        print("🧪 测试完整 C API 流程...")
        
        // 创建配置
        var config = SherpaOnnxOnlineRecognizerConfig()
        config.enable_endpoint = 1
        
        // 测试创建识别器
        let recognizer = SherpaOnnxCreateOnlineRecognizer(&config)
        if recognizer != nil {
            print("✅ SherpaOnnxCreateOnlineRecognizer 成功")
            
            // 测试创建流
            let stream = SherpaOnnxCreateOnlineStream(recognizer)
            if stream != nil {
                print("✅ SherpaOnnxCreateOnlineStream 成功")
                
                // 测试其他 API 函数
                let isReady = SherpaOnnxIsOnlineStreamReady(recognizer, stream)
                print("✅ SherpaOnnxIsOnlineStreamReady: \(isReady)")
                
                let isEndpoint = SherpaOnnxOnlineStreamIsEndpoint(recognizer, stream)
                print("✅ SherpaOnnxOnlineStreamIsEndpoint: \(isEndpoint)")
                
                // 清理资源
                SherpaOnnxDestroyOnlineStream(stream)
                print("✅ SherpaOnnxDestroyOnlineStream 成功")
            } else {
                print("❌ SherpaOnnxCreateOnlineStream 失败")
            }
            
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
            print("✅ SherpaOnnxDestroyOnlineRecognizer 成功")
        } else {
            print("❌ SherpaOnnxCreateOnlineRecognizer 失败")
        }
        
        print("🎉 完整 API 流程测试完成!")
    }
    
    /// 运行所有测试
    func runAllTests() {
        print("🚀 开始 Sherpa-ONNX C API 测试...")
        testBasicTypes()
        testFullAPIFlow()
        print("✅ 所有测试完成!")
    }
}

// 在 DEBUG 模式下运行测试
#if DEBUG
let test = SherpaAPITest()
test.runAllTests()
#endif