import Foundation

class SherpaAPITest {
    
    static func testCAPIBasics() {
        print("🔍 开始测试 Sherpa-ONNX C API 基础功能...")
        
        // 测试版本信息
        let version = SherpaOnnxGetVersionStr()
        let versionStr = version != nil ? String(cString: version!) : "未知"
        print("📦 Sherpa-ONNX 版本: \(versionStr)")
        
        // 测试 Git 信息
        let gitSha = SherpaOnnxGetGitSha1()
        let gitShaStr = gitSha != nil ? String(cString: gitSha!) : "未知"
        print("🔧 Git SHA: \(gitShaStr)")
        
        let gitDate = SherpaOnnxGetGitDate()
        let gitDateStr = gitDate != nil ? String(cString: gitDate!) : "未知"
        print("📅 Git 日期: \(gitDateStr)")
        
        // 测试结构体初始化
        print("\n🧪 测试结构体初始化...")
        
        var config = SherpaOnnxOnlineRecognizerConfig()
        config.enable_endpoint = 1
        config.rule1_min_trailing_silence = 2.4
        config.rule2_min_trailing_silence = 1.2
        config.rule3_min_utterance_length = 20.0
        
        print("✅ SherpaOnnxOnlineRecognizerConfig 初始化成功")
        print("   - enable_endpoint: \(config.enable_endpoint)")
        print("   - rule1_min_trailing_silence: \(config.rule1_min_trailing_silence)")
        print("   - rule2_min_trailing_silence: \(config.rule2_min_trailing_silence)")
        print("   - rule3_min_utterance_length: \(config.rule3_min_utterance_length)")
        
        // 测试其他结构体
        var featConfig = SherpaOnnxFeatureConfig()
        featConfig.sample_rate = 16000
        featConfig.feature_dim = 80
        
        print("✅ SherpaOnnxFeatureConfig 初始化成功")
        print("   - sample_rate: \(featConfig.sample_rate)")
        print("   - feature_dim: \(featConfig.feature_dim)")
        
        var paraformerConfig = SherpaOnnxOnlineParaformerModelConfig()
        paraformerConfig.encoder = nil
        paraformerConfig.decoder = nil
        
        print("✅ SherpaOnnxOnlineParaformerModelConfig 初始化成功")
        
        var transducerConfig = SherpaOnnxOnlineTransducerModelConfig()
        transducerConfig.encoder = nil
        transducerConfig.decoder = nil
        transducerConfig.joiner = nil
        
        print("✅ SherpaOnnxOnlineTransducerModelConfig 初始化成功")
        
        var zipformerConfig = SherpaOnnxOnlineZipformer2CtcModelConfig()
        zipformerConfig.model = nil
        
        print("✅ SherpaOnnxOnlineZipformer2CtcModelConfig 初始化成功")
        
        var modelConfig = SherpaOnnxOnlineModelConfig()
        modelConfig.paraformer = paraformerConfig
        modelConfig.transducer = transducerConfig
        modelConfig.zipformer2_ctc = zipformerConfig
        modelConfig.tokens = nil
        modelConfig.num_threads = 2
        modelConfig.provider = nil
        modelConfig.debug = 0
        
        print("✅ SherpaOnnxOnlineModelConfig 初始化成功")
        
        // 测试文件存在性检查
        print("\n📁 测试文件检查功能...")
        let testPath = "/tmp/test_file"
        let fileExists = SherpaOnnxFileExists(testPath)
        print("🔍 文件 \(testPath) 存在: \(fileExists == 1 ? "是" : "否")")
        
        print("\n🎉 所有 C API 基础功能测试完成！")
    }
    
    static func testRecognizerCreation() {
        print("\n🔬 开始测试识别器创建...")
        
        // 创建基本配置
        var featConfig = SherpaOnnxFeatureConfig()
        featConfig.sample_rate = 16000
        featConfig.feature_dim = 80
        
        var paraformerConfig = SherpaOnnxOnlineParaformerModelConfig()
        paraformerConfig.encoder = nil
        paraformerConfig.decoder = nil
        
        var transducerConfig = SherpaOnnxOnlineTransducerModelConfig()
        transducerConfig.encoder = nil
        transducerConfig.decoder = nil
        transducerConfig.joiner = nil
        
        var zipformerConfig = SherpaOnnxOnlineZipformer2CtcModelConfig()
        zipformerConfig.model = nil
        
        var modelConfig = SherpaOnnxOnlineModelConfig()
        modelConfig.paraformer = paraformerConfig
        modelConfig.transducer = transducerConfig
        modelConfig.zipformer2_ctc = zipformerConfig
        modelConfig.tokens = nil
        modelConfig.num_threads = 2
        modelConfig.provider = UnsafePointer(strdup("cpu"))
        modelConfig.debug = 0
        
        var ctcConfig = SherpaOnnxOnlineCtcFstDecoderConfig()
        ctcConfig.graph = nil
        ctcConfig.max_active = 3000
        
        var config = SherpaOnnxOnlineRecognizerConfig()
        config.feat_config = featConfig
        config.model_config = modelConfig
        config.decoding_method = UnsafePointer(strdup("greedy_search"))
        config.max_active_paths = 4
        config.enable_endpoint = 1
        config.rule1_min_trailing_silence = 2.4
        config.rule2_min_trailing_silence = 1.2
        config.rule3_min_utterance_length = 20.0
        config.ctc_fst_decoder_config = ctcConfig
        
        print("⚙️ 配置创建完成，尝试创建识别器...")
        
        // 注意：由于没有实际的模型文件，这里会失败，但可以测试 API 调用
        let recognizer = SherpaOnnxCreateOnlineRecognizer(&config)
        
        if recognizer != nil {
            print("✅ 识别器创建成功")
            
            // 创建流
            let stream = SherpaOnnxCreateOnlineStream(recognizer)
            if stream != nil {
                print("✅ 音频流创建成功")
                
                // 清理资源
                SherpaOnnxDestroyOnlineStream(stream)
                print("✅ 音频流已销毁")
            } else {
                print("❌ 音频流创建失败")
            }
            
            // 清理识别器
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
            print("✅ 识别器已销毁")
        } else {
            print("❌ 识别器创建失败（预期结果，因为没有模型文件）")
        }
        
        // 清理分配的字符串
        if let provider = modelConfig.provider {
            free(UnsafeMutableRawPointer(mutating: provider))
        }
        if let decodingMethod = config.decoding_method {
            free(UnsafeMutableRawPointer(mutating: decodingMethod))
        }
        
        print("🧹 内存清理完成")
    }
    
    static func runAllTests() {
        print("🚀 开始 Sherpa-ONNX C API 完整测试...")
        testCAPIBasics()
        testRecognizerCreation()
        print("✅ 所有测试完成!")
    }
}

// 运行测试
SherpaAPITest.runAllTests()