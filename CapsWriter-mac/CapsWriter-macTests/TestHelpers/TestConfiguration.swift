import Foundation
import XCTest
@testable import CapsWriter_mac

/// 测试配置管理
struct TestConfiguration {
    
    // MARK: - 测试超时设置
    
    /// 默认测试超时时间
    static let defaultTimeout: TimeInterval = 5.0
    
    /// 长时间操作超时时间
    static let longTimeout: TimeInterval = 30.0
    
    /// 性能测试超时时间
    static let performanceTimeout: TimeInterval = 10.0
    
    /// 网络操作超时时间
    static let networkTimeout: TimeInterval = 15.0
    
    /// 文件操作超时时间
    static let fileTimeout: TimeInterval = 10.0
    
    // MARK: - 测试路径配置
    
    /// 测试资源根路径
    static let testResourcesPath: String = {
        let bundle = Bundle(for: TestConfiguration.self)
        return bundle.resourcePath ?? FileManager.default.temporaryDirectory.path
    }()
    
    /// 测试音频文件路径
    static let testAudioPath = "\(testResourcesPath)/test_audio"
    
    /// 测试配置文件路径
    static let testConfigPath = "\(testResourcesPath)/test_configs"
    
    /// 测试热词文件路径
    static let testHotWordPath = "\(testResourcesPath)/test_hotwords"
    
    /// 测试模型文件路径
    static let testModelPath = "\(testResourcesPath)/test_models"
    
    /// 临时文件路径
    static let tempPath = FileManager.default.temporaryDirectory.path
    
    // MARK: - 性能基准设置
    
    /// 最大内存使用量 (200MB)
    static let maxMemoryUsage: Int64 = 200 * 1024 * 1024
    
    /// 最大文本处理时间 (500ms)
    static let maxProcessingTime: TimeInterval = 0.5
    
    /// 最大服务启动时间 (3秒)
    static let maxStartupTime: TimeInterval = 3.0
    
    /// 最大音频处理延迟 (100ms)
    static let maxAudioProcessingDelay: TimeInterval = 0.1
    
    /// 最大识别响应时间 (2秒)
    static let maxRecognitionResponseTime: TimeInterval = 2.0
    
    // MARK: - 测试数据配置
    
    /// 默认测试热词
    static let defaultHotWords: [String: String] = [
        "测试": "test",
        "你好": "hello",
        "世界": "world",
        "开发": "development",
        "应用": "application",
        "语音": "voice",
        "识别": "recognition",
        "转录": "transcription",
        "系统": "system",
        "功能": "function"
    ]
    
    /// 中文测试热词
    static let chineseHotWords: [String: String] = [
        "北京": "Beijing",
        "上海": "Shanghai",
        "深圳": "Shenzhen",
        "广州": "Guangzhou",
        "杭州": "Hangzhou",
        "成都": "Chengdu",
        "西安": "Xi'an",
        "南京": "Nanjing",
        "武汉": "Wuhan",
        "重庆": "Chongqing"
    ]
    
    /// 英文测试热词
    static let englishHotWords: [String: String] = [
        "AI": "Artificial Intelligence",
        "ML": "Machine Learning",
        "NLP": "Natural Language Processing",
        "ASR": "Automatic Speech Recognition",
        "TTS": "Text To Speech",
        "API": "Application Programming Interface",
        "SDK": "Software Development Kit",
        "JSON": "JavaScript Object Notation",
        "HTTP": "HyperText Transfer Protocol",
        "REST": "Representational State Transfer"
    ]
    
    /// 规则替换测试数据
    static let ruleReplacements: [String: String] = [
        "\\b数字(\\d+)": "number_$1",
        "\\b时间\\s*(\\d{1,2}):(\\d{2})": "time_$1h$2m",
        "\\b日期\\s*(\\d{4})年(\\d{1,2})月(\\d{1,2})日": "date_$1-$2-$3",
        "\\b电话\\s*(\\d{3,4})-(\\d{7,8})": "phone_$1-$2",
        "\\b邮箱\\s*([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})": "email_$1"
    ]
    
    // MARK: - 音频测试配置
    
    /// 测试音频格式配置
    struct AudioTestConfig {
        static let sampleRate: Double = 16000
        static let channels: Int = 1
        static let bufferSize: UInt32 = 1024
        static let testFrequency: Float = 440.0 // A4 音符
        static let testAmplitude: Float = 0.5
        static let testDuration: TimeInterval = 2.0
    }
    
    /// 支持的音频格式
    static let supportedAudioFormats = ["wav", "mp3", "m4a", "aac"]
    
    // MARK: - 识别测试配置
    
    /// 测试识别配置
    struct RecognitionTestConfig {
        static let testModelPath = "models/test-paraformer"
        static let numThreads = 2
        static let provider = "cpu"
        static let maxActivePaths = 4
        static let enableEndpoint = true
        static let language = "zh"
    }
    
    /// 测试语句
    static let testSentences = [
        "这是一个测试语句",
        "语音识别功能正常工作",
        "热词替换系统运行良好",
        "配置管理模块测试通过",
        "事件总线功能验证成功"
    ]
    
    /// 包含热词的测试语句
    static let testSentencesWithHotWords = [
        "测试语音识别功能",
        "你好世界，开发应用系统",
        "转录功能识别准确率很高",
        "系统配置和功能测试完成"
    ]
    
    // MARK: - 错误测试配置
    
    /// 测试错误类型
    enum TestErrorType: Error, CaseIterable {
        case configurationError
        case audioProcessingError
        case recognitionError
        case hotWordProcessingError
        case fileSystemError
        case networkError
        case permissionError
        case timeoutError
        
        var localizedDescription: String {
            switch self {
            case .configurationError:
                return "配置错误"
            case .audioProcessingError:
                return "音频处理错误"
            case .recognitionError:
                return "识别错误"
            case .hotWordProcessingError:
                return "热词处理错误"
            case .fileSystemError:
                return "文件系统错误"
            case .networkError:
                return "网络错误"
            case .permissionError:
                return "权限错误"
            case .timeoutError:
                return "超时错误"
            }
        }
    }
    
    // MARK: - 并发测试配置
    
    /// 并发测试配置
    struct ConcurrencyTestConfig {
        static let maxConcurrentOperations = 50
        static let testIterations = 100
        static let concurrencyTimeout: TimeInterval = 30.0
        static let stressTestDuration: TimeInterval = 60.0
    }
    
    // MARK: - 环境配置
    
    /// 测试环境类型
    enum TestEnvironment {
        case unit          // 单元测试环境
        case integration   // 集成测试环境
        case performance   // 性能测试环境
        case ui           // UI测试环境
        
        var description: String {
            switch self {
            case .unit: return "Unit Test"
            case .integration: return "Integration Test"
            case .performance: return "Performance Test"
            case .ui: return "UI Test"
            }
        }
    }
    
    /// 当前测试环境
    static var currentEnvironment: TestEnvironment = .unit
    
    /// 是否为调试模式
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// 是否启用详细日志
    static var enableVerboseLogging = false
    
    // MARK: - 工具方法
    
    /// 创建测试临时目录
    static func createTemporaryTestDirectory(name: String = "CapsWriterTest") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent(name + "_" + UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        } catch {
            fatalError("无法创建测试临时目录: \(error)")
        }
        
        return testDir
    }
    
    /// 清理测试临时目录
    static func cleanupTemporaryTestDirectory(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("清理测试临时目录失败: \(error)")
        }
    }
    
    /// 获取测试配置文件路径
    static func getTestConfigurationPath(for configType: String) -> URL {
        let testDir = createTemporaryTestDirectory(name: "Config")
        return testDir.appendingPathComponent("test_\(configType).json")
    }
    
    /// 创建测试用的音频配置
    static func createTestAudioConfiguration() -> AudioConfiguration {
        return AudioConfiguration(
            sampleRate: AudioTestConfig.sampleRate,
            channels: AudioTestConfig.channels,
            bufferSize: AudioTestConfig.bufferSize,
            enableNoiseReduction: false,
            enableAudioEnhancement: false
        )
    }
    
    /// 创建测试用的识别配置
    static func createTestRecognitionConfiguration() -> RecognitionConfiguration {
        return RecognitionConfiguration(
            modelPath: RecognitionTestConfig.testModelPath,
            numThreads: RecognitionTestConfig.numThreads,
            provider: RecognitionTestConfig.provider,
            maxActivePaths: RecognitionTestConfig.maxActivePaths,
            enableEndpoint: RecognitionTestConfig.enableEndpoint,
            language: RecognitionTestConfig.language
        )
    }
    
    /// 生成随机测试字符串
    static func generateRandomTestString(length: Int = 10) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// 生成随机中文测试字符串
    static func generateRandomChineseTestString(length: Int = 5) -> String {
        let chineseCharacters = ["测", "试", "语", "音", "识", "别", "转", "录", "系", "统", 
                               "应", "用", "开", "发", "功", "能", "配", "置", "管", "理"]
        return String((0..<length).map { _ in chineseCharacters.randomElement()! })
    }
    
    /// 验证测试环境
    static func validateTestEnvironment() -> Bool {
        // 检查必要的测试资源
        let fileManager = FileManager.default
        
        // 检查临时目录可访问性
        guard fileManager.isWritableFile(atPath: tempPath) else {
            print("警告: 临时目录不可写")
            return false
        }
        
        // 检查内存限制
        let memoryUsage = getMemoryUsage()
        if memoryUsage > maxMemoryUsage {
            print("警告: 内存使用过高 (\(memoryUsage) bytes)")
        }
        
        return true
    }
    
    /// 获取当前内存使用量
    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    /// 设置测试环境
    static func setupTestEnvironment(for environment: TestEnvironment) {
        currentEnvironment = environment
        
        switch environment {
        case .unit:
            enableVerboseLogging = false
        case .integration:
            enableVerboseLogging = true
        case .performance:
            enableVerboseLogging = false
        case .ui:
            enableVerboseLogging = true
        }
        
        // 验证环境
        _ = validateTestEnvironment()
    }
}

// MARK: - 测试资源管理

/// 测试资源管理器
class TestResourceManager {
    static let shared = TestResourceManager()
    
    private var createdResources: [URL] = []
    private let queue = DispatchQueue(label: "TestResourceManager", attributes: .concurrent)
    
    private init() {}
    
    /// 创建测试热词文件
    func createTestHotWordFile(
        type: HotWordType,
        entries: [String: String]? = nil
    ) -> URL {
        let hotWords = entries ?? TestConfiguration.defaultHotWords
        let content = hotWords.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        
        let fileName = "test-hot-\(type.rawValue).txt"
        let url = TestConfiguration.createTemporaryTestDirectory()
            .appendingPathComponent(fileName)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            registerResource(url)
        } catch {
            fatalError("创建测试热词文件失败: \(error)")
        }
        
        return url
    }
    
    /// 创建测试音频文件
    func createTestAudioFile(
        duration: TimeInterval = 2.0,
        frequency: Float = 440.0,
        format: String = "wav"
    ) -> URL {
        let fileName = "test-audio-\(UUID().uuidString).\(format)"
        let url = TestConfiguration.createTemporaryTestDirectory()
            .appendingPathComponent(fileName)
        
        // 生成音频数据 (这里简化处理，实际可能需要更复杂的音频生成)
        let sampleRate = Int(TestConfiguration.AudioTestConfig.sampleRate)
        let samplesCount = Int(duration * Double(sampleRate))
        var samples: [Float] = []
        
        for i in 0..<samplesCount {
            let time = Float(i) / Float(sampleRate)
            let sample = TestConfiguration.AudioTestConfig.testAmplitude * 
                        sin(2.0 * Float.pi * frequency * time)
            samples.append(sample)
        }
        
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
        
        do {
            try data.write(to: url)
            registerResource(url)
        } catch {
            fatalError("创建测试音频文件失败: \(error)")
        }
        
        return url
    }
    
    /// 创建测试配置文件
    func createTestConfigurationFile() -> URL {
        let config = [
            "audio": [
                "sampleRate": TestConfiguration.AudioTestConfig.sampleRate,
                "channels": TestConfiguration.AudioTestConfig.channels,
                "bufferSize": TestConfiguration.AudioTestConfig.bufferSize
            ],
            "recognition": [
                "modelPath": TestConfiguration.RecognitionTestConfig.testModelPath,
                "numThreads": TestConfiguration.RecognitionTestConfig.numThreads,
                "provider": TestConfiguration.RecognitionTestConfig.provider
            ]
        ]
        
        let fileName = "test-config-\(UUID().uuidString).json"
        let url = TestConfiguration.createTemporaryTestDirectory()
            .appendingPathComponent(fileName)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: url)
            registerResource(url)
        } catch {
            fatalError("创建测试配置文件失败: \(error)")
        }
        
        return url
    }
    
    /// 注册资源以便清理
    private func registerResource(_ url: URL) {
        queue.async(flags: .barrier) {
            self.createdResources.append(url)
        }
    }
    
    /// 清理所有创建的资源
    func cleanupAllResources() {
        queue.sync {
            for url in createdResources {
                try? FileManager.default.removeItem(at: url)
            }
            createdResources.removeAll()
        }
    }
    
    deinit {
        cleanupAllResources()
    }
}