import XCTest
import Combine
@testable import CapsWriter_mac

/// 服务集成测试
/// 测试各服务之间的协作和数据流
class ServiceIntegrationTests: XCTestCase {

    var configManager: ConfigurationManager!
    var hotWordService: HotWordService!
    var eventBus: EventBus!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // 设置测试环境
        TestConfiguration.setupTestEnvironment(for: .integration)
        
        // 创建实际服务（非 Mock）进行集成测试
        configManager = ConfigurationManager()
        eventBus = EventBus()
        hotWordService = HotWordService()
    }

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        
        hotWordService?.cleanup()
        hotWordService = nil
        configManager = nil
        eventBus = nil
        
        // 清理测试资源
        TestResourceManager.shared.cleanupAllResources()
        super.tearDown()
    }

    // MARK: - 配置与服务集成测试

    func testConfigurationServiceIntegration() throws {
        // Given - 加载测试配置
        configManager.load()
        
        // 修改热词配置
        configManager.hotwords.enableChineseHotwords = true
        configManager.hotwords.enableEnglishHotwords = false
        configManager.hotwords.hotwordFiles = ["test-hot-zh.txt"]
        
        // When - 保存并重新加载配置
        try configManager.save()
        
        // 创建新的配置管理器验证持久化
        let newConfigManager = ConfigurationManager()
        newConfigManager.load()
        
        // Then - 验证配置正确保存和加载
        XCTAssertTrue(newConfigManager.hotwords.enableChineseHotwords, "中文热词应该启用")
        XCTAssertFalse(newConfigManager.hotwords.enableEnglishHotwords, "英文热词应该关闭")
        XCTAssertEqual(newConfigManager.hotwords.hotwordFiles.first, "test-hot-zh.txt")
    }

    func testHotWordServiceWithConfiguration() throws {
        // Given - 设置配置
        configManager.load()
        configManager.hotwords.enableChineseHotwords = true
        configManager.hotwords.caseSensitive = false
        
        // 初始化热词服务
        try hotWordService.initialize()
        try hotWordService.start()
        
        // 添加测试热词
        hotWordService.addRuntimeHotWord(
            original: "测试集成",
            replacement: "test integration",
            type: .runtime
        )
        
        // When - 处理包含热词的文本
        let inputText = "这是测试集成功能"
        let result = hotWordService.processText(inputText)
        
        // Then - 验证热词替换
        XCTAssertEqual(result, "这是test integration功能", "热词应该被正确替换")
        XCTAssertTrue(hotWordService.isRunning, "热词服务应该运行中")
        
        // 验证统计信息
        let statistics = hotWordService.getStatistics()
        XCTAssertGreaterThan(statistics.runtimeEntries, 0, "应该有运行时热词")
    }

    // MARK: - 事件驱动集成测试

    func testEventBusServiceIntegration() {
        // Given - 设置事件监听
        let configurationChangedExpectation = XCTestExpectation(description: "配置变更事件")
        let hotWordProcessedExpectation = XCTestExpectation(description: "热词处理事件")
        
        var receivedConfigEvent: ConfigurationChangedEvent?
        var receivedHotWordEvent: HotWordProcessedEvent?
        
        // 订阅配置变更事件
        eventBus.subscribe(ConfigurationChangedEvent.self) { event in
            receivedConfigEvent = event
            configurationChangedExpectation.fulfill()
        }
        .store(in: &cancellables)
        
        // 订阅热词处理事件
        eventBus.subscribe(HotWordProcessedEvent.self) { event in
            receivedHotWordEvent = event
            hotWordProcessedExpectation.fulfill()
        }
        .store(in: &cancellables)
        
        // When - 发布事件
        eventBus.publish(ConfigurationChangedEvent(
            configType: "hotwords",
            oldValue: "old config",
            newValue: "new config"
        ))
        
        eventBus.publish(HotWordProcessedEvent(
            originalText: "测试",
            processedText: "test",
            replacementCount: 1,
            processingTime: 0.01
        ))
        
        // Then - 验证事件接收
        wait(for: [configurationChangedExpectation, hotWordProcessedExpectation], timeout: 2.0)
        
        XCTAssertNotNil(receivedConfigEvent, "应该接收到配置变更事件")
        XCTAssertNotNil(receivedHotWordEvent, "应该接收到热词处理事件")
        XCTAssertEqual(receivedConfigEvent?.configType, "hotwords")
        XCTAssertEqual(receivedHotWordEvent?.originalText, "测试")
    }

    // MARK: - 完整工作流集成测试

    func testCompleteWorkflowIntegration() throws {
        // Given - 设置完整的服务链
        configManager.load()
        try hotWordService.initialize()
        try hotWordService.start()
        
        // 设置事件监听链
        var processedResults: [String] = []
        let workflowExpectation = XCTestExpectation(description: "工作流完成")
        
        eventBus.subscribe(TextProcessingCompletedEvent.self) { event in
            processedResults.append(event.result)
            if processedResults.count == 3 {
                workflowExpectation.fulfill()
            }
        }
        .store(in: &cancellables)
        
        // When - 模拟完整的文本处理工作流
        let testTexts = [
            "你好世界测试",
            "语音识别功能正常",
            "系统配置管理完成"
        ]
        
        for text in testTexts {
            // 1. 热词处理
            let processedText = hotWordService.processText(text)
            
            // 2. 发布处理完成事件
            eventBus.publish(TextProcessingCompletedEvent(
                originalText: text,
                result: processedText,
                processingSteps: ["hotword_replacement"]
            ))
        }
        
        // Then - 验证工作流结果
        wait(for: [workflowExpectation], timeout: 5.0)
        XCTAssertEqual(processedResults.count, 3, "应该处理完所有文本")
        
        // 验证每个结果都被正确处理
        for (index, result) in processedResults.enumerated() {
            XCTAssertNotEqual(result, testTexts[index], "处理后的文本应该与原文本不同")
        }
    }

    // MARK: - 服务依赖注入集成测试

    func testDependencyInjectionIntegration() {
        // Given - 创建 DI 容器
        let container = DIContainer()
        
        // 注册服务
        container.register(ConfigurationManagerProtocol.self) { _ in
            return self.configManager
        }
        
        container.register(EventBusProtocol.self) { _ in
            return self.eventBus
        }
        
        container.register(HotWordServiceProtocol.self) { container in
            let configManager = container.resolve(ConfigurationManagerProtocol.self)!
            let eventBus = container.resolve(EventBusProtocol.self)!
            // 这里需要根据实际的 HotWordService 初始化方法调整
            return self.hotWordService
        }
        
        // When - 解析服务
        let resolvedConfigManager = container.resolve(ConfigurationManagerProtocol.self)
        let resolvedEventBus = container.resolve(EventBusProtocol.self)
        let resolvedHotWordService = container.resolve(HotWordServiceProtocol.self)
        
        // Then - 验证依赖注入
        XCTAssertNotNil(resolvedConfigManager, "应该解析到配置管理器")
        XCTAssertNotNil(resolvedEventBus, "应该解析到事件总线")
        XCTAssertNotNil(resolvedHotWordService, "应该解析到热词服务")
        
        // 验证服务可以正常工作
        resolvedConfigManager?.load()
        XCTAssertNoThrow(try resolvedHotWordService?.initialize())
    }

    // MARK: - 错误处理集成测试

    func testErrorHandlingIntegration() {
        // Given - 设置错误处理监听
        let errorExpectation = XCTestExpectation(description: "错误处理")
        var capturedErrors: [Error] = []
        
        eventBus.subscribe(ServiceErrorEvent.self) { event in
            capturedErrors.append(event.error)
            errorExpectation.fulfill()
        }
        .store(in: &cancellables)
        
        // When - 模拟服务错误
        let testError = NSError(domain: "TestError", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "集成测试错误"
        ])
        
        eventBus.publish(ServiceErrorEvent(
            serviceName: "HotWordService",
            error: testError,
            context: "处理文本时发生错误"
        ))
        
        // Then - 验证错误处理
        wait(for: [errorExpectation], timeout: 2.0)
        XCTAssertEqual(capturedErrors.count, 1, "应该捕获一个错误")
        XCTAssertEqual((capturedErrors.first as NSError?)?.domain, "TestError")
    }

    // MARK: - 性能集成测试

    func testPerformanceIntegration() throws {
        // Given - 设置服务
        try hotWordService.initialize()
        try hotWordService.start()
        
        // 添加测试热词
        for i in 0..<100 {
            hotWordService.addRuntimeHotWord(
                original: "测试\(i)",
                replacement: "test\(i)",
                type: .runtime
            )
        }
        
        let testText = generateLongTestText(wordCount: 1000)
        
        // When & Then - 测量处理性能
        measure {
            _ = hotWordService.processText(testText)
        }
        
        // 验证处理结果质量
        let result = hotWordService.processText("测试0 测试50 测试99")
        XCTAssertTrue(result.contains("test0"), "应该正确替换热词")
        XCTAssertTrue(result.contains("test50"), "应该正确替换热词")
        XCTAssertTrue(result.contains("test99"), "应该正确替换热词")
    }

    // MARK: - 并发集成测试

    func testConcurrentServiceAccess() throws {
        // Given - 设置服务
        try hotWordService.initialize()
        try hotWordService.start()
        
        let concurrentQueue = DispatchQueue(label: "integration.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "并发访问完成")
        expectation.expectedFulfillmentCount = 20
        
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // When - 并发访问服务
        for i in 0..<20 {
            concurrentQueue.async {
                // 并发添加热词
                self.hotWordService.addRuntimeHotWord(
                    original: "并发测试\(i)",
                    replacement: "concurrent_test_\(i)",
                    type: .runtime
                )
                
                // 并发处理文本
                let text = "这是并发测试\(i)的内容"
                let result = self.hotWordService.processText(text)
                
                resultsQueue.async {
                    results.append(result)
                    expectation.fulfill()
                }
            }
        }
        
        // Then - 验证并发访问结果
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(results.count, 20, "应该完成所有并发操作")
        
        // 验证结果的一致性
        for (index, result) in results.enumerated() {
            XCTAssertTrue(result.contains("concurrent_test_\(index)"), "并发处理结果应该正确")
        }
    }

    // MARK: - 辅助方法

    private func generateLongTestText(wordCount: Int) -> String {
        let words = ["测试", "文本", "处理", "性能", "集成", "功能", "系统", "应用"]
        return (0..<wordCount).map { _ in words.randomElement()! }.joined(separator: " ")
    }
}

// MARK: - 测试事件定义

/// 配置变更事件
struct ConfigurationChangedEvent {
    let configType: String
    let oldValue: Any?
    let newValue: Any?
    let timestamp: Date = Date()
}

/// 热词处理事件
struct HotWordProcessedEvent {
    let originalText: String
    let processedText: String
    let replacementCount: Int
    let processingTime: TimeInterval
    let timestamp: Date = Date()
}

/// 文本处理完成事件
struct TextProcessingCompletedEvent {
    let originalText: String
    let result: String
    let processingSteps: [String]
    let timestamp: Date = Date()
}

/// 服务错误事件
struct ServiceErrorEvent {
    let serviceName: String
    let error: Error
    let context: String
    let timestamp: Date = Date()
}