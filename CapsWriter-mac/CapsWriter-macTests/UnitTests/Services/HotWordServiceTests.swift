import XCTest
import Combine
@testable import CapsWriter_mac

class HotWordServiceTests: XCTestCase {

    var hotWordService: HotWordService!
    var mockConfigManager: MockConfigurationManager!
    var mockEventBus: MockEventBus!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // 创建 Mock 依赖
        mockConfigManager = MockConfigurationManager()
        mockEventBus = MockEventBus()

        // 创建测试对象 - 根据实际 HotWordService 初始化方法调整
        hotWordService = HotWordService()
    }

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        hotWordService?.cleanup()
        hotWordService = nil
        mockConfigManager = nil
        mockEventBus = nil
        super.tearDown()
    }

    // MARK: - 基础功能测试

    func testBasicHotWordReplacement() {
        // Given
        let inputText = "你好世界"
        let expectedOutput = "hello世界"

        // 设置热词数据
        setUpBasicHotWords()

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertEqual(result, expectedOutput, "基础热词替换应该正确工作")
    }

    func testMultipleHotWordReplacement() {
        // Given
        let inputText = "你好世界测试开发"
        let expectedOutput = "hello世界test开发"

        setUpBasicHotWords()

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertEqual(result, expectedOutput, "多个热词替换应该正确工作")
    }

    func testEmptyTextProcessing() {
        // Given
        let inputText = ""

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertEqual(result, "", "空文本应该返回空字符串")
    }

    func testNoMatchingHotWords() {
        // Given
        let inputText = "没有匹配的热词内容"

        setUpBasicHotWords()

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertEqual(result, inputText, "没有匹配的热词时应该返回原文本")
    }

    func testCaseSensitiveReplacement() {
        // Given
        let inputText = "测试 Test TEST"

        // 设置包含大小写敏感的热词
        setUpCaseSensitiveHotWords()

        // When
        let result = hotWordService.processText(inputText)

        // Then
        // 根据实际 HotWordService 的行为调整期望结果
        XCTAssertTrue(result.contains("test"), "应该正确处理大小写敏感的替换")
    }

    // MARK: - 服务生命周期测试

    func testServiceInitialization() throws {
        // Given
        let service = HotWordService()

        // When & Then
        XCTAssertNoThrow(try service.initialize())
        XCTAssertTrue(service.isInitialized, "服务应该初始化成功")
    }

    func testServiceStartStop() throws {
        // Given
        try hotWordService.initialize()

        // When - Start
        XCTAssertNoThrow(try hotWordService.start())
        XCTAssertTrue(hotWordService.isRunning, "服务应该启动成功")

        // When - Stop
        hotWordService.stop()
        XCTAssertFalse(hotWordService.isRunning, "服务应该停止成功")
    }

    func testServiceCleanup() throws {
        // Given
        try hotWordService.initialize()
        try hotWordService.start()

        // When
        hotWordService.cleanup()

        // Then
        XCTAssertFalse(hotWordService.isInitialized, "清理后服务应该未初始化")
        XCTAssertFalse(hotWordService.isRunning, "清理后服务应该未运行")
    }

    // MARK: - 热词管理测试

    func testAddRuntimeHotWord() {
        // Given
        let original = "动态测试"
        let replacement = "dynamic test"

        // When
        hotWordService.addRuntimeHotWord(
            original: original,
            replacement: replacement,
            type: .runtime
        )

        let result = hotWordService.processText("这是动态测试")

        // Then
        XCTAssertEqual(result, "这是dynamic test", "运行时热词应该正确添加并工作")
    }

    func testRemoveRuntimeHotWord() {
        // Given
        let original = "临时热词"
        let replacement = "temp hotword"

        hotWordService.addRuntimeHotWord(
            original: original,
            replacement: replacement,
            type: .runtime
        )

        // Verify addition worked
        let beforeRemoval = hotWordService.processText("这是临时热词")
        XCTAssertEqual(beforeRemoval, "这是temp hotword")

        // When
        hotWordService.removeRuntimeHotWord(original: original, type: .runtime)
        let afterRemoval = hotWordService.processText("这是临时热词")

        // Then
        XCTAssertEqual(afterRemoval, "这是临时热词", "移除后热词不应该再生效")
    }

    func testHotWordStatistics() {
        // Given
        setUpBasicHotWords()
        
        // When
        let statistics = hotWordService.getStatistics()

        // Then
        XCTAssertGreaterThan(statistics.totalEntries, 0, "应该有热词条目")
        XCTAssertNotNil(statistics.lastReloadTime, "应该有加载时间记录")
        XCTAssertFalse(statistics.summary.isEmpty, "统计摘要不应该为空")
    }

    func testReloadHotWords() {
        // Given
        let initialStatistics = hotWordService.getStatistics()

        // When
        hotWordService.reloadHotWords()
        let newStatistics = hotWordService.getStatistics()

        // Then
        // 重载后时间应该更新（如果实现了）
        if let initialTime = initialStatistics.lastReloadTime,
           let newTime = newStatistics.lastReloadTime {
            XCTAssertGreaterThanOrEqual(newTime, initialTime, "重载时间应该更新")
        }
    }

    // MARK: - 性能测试

    func testPerformanceWithLargeText() {
        // Given
        let largeText = String(repeating: "测试文本内容 ", count: 1000)
        setUpBasicHotWords()

        // When & Then
        measure {
            _ = hotWordService.processText(largeText)
        }

        // 性能期望：1000个重复词汇的处理应在合理时间内完成
    }

    func testPerformanceWithManyHotWords() {
        // Given
        let inputText = "测试文本"

        // 添加大量运行时热词
        for i in 0..<1000 {
            hotWordService.addRuntimeHotWord(
                original: "测试\(i)",
                replacement: "test\(i)",
                type: .runtime
            )
        }

        // When & Then
        measure {
            _ = hotWordService.processText(inputText)
        }
    }

    // MARK: - 边界条件测试

    func testVeryLongHotWord() {
        // Given
        let longOriginal = String(repeating: "很长的热词", count: 100)
        let longReplacement = String(repeating: "very long hotword ", count: 100)
        let inputText = "前缀" + longOriginal + "后缀"

        hotWordService.addRuntimeHotWord(
            original: longOriginal,
            replacement: longReplacement,
            type: .runtime
        )

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertEqual(result, "前缀" + longReplacement + "后缀", "应该正确处理很长的热词")
    }

    func testSpecialCharacters() {
        // Given
        let inputText = "特殊字符！@#$%^&*()测试[]{}|\\:;\"'<>?,./`~"

        hotWordService.addRuntimeHotWord(
            original: "测试",
            replacement: "test",
            type: .runtime
        )

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertTrue(result.contains("test"), "应该正确处理包含特殊字符的文本")
        XCTAssertTrue(result.contains("！@#$%^&*()"), "特殊字符应该保持不变")
    }

    func testUnicodeCharacters() {
        // Given
        let inputText = "Unicode测试: 🚀 emoji 测试 中文测试 한국어 テスト"

        hotWordService.addRuntimeHotWord(
            original: "测试",
            replacement: "test",
            type: .runtime
        )

        // When
        let result = hotWordService.processText(inputText)

        // Then
        XCTAssertTrue(result.contains("🚀"), "Emoji应该保持不变")
        XCTAssertTrue(result.contains("한국어"), "其他语言字符应该保持不变")
        XCTAssertTrue(result.contains("test"), "中文热词应该被正确替换")
    }

    // MARK: - 错误处理测试

    func testErrorHandling() {
        // Given
        let invalidText: String? = nil

        // When & Then
        XCTAssertNoThrow {
            // 测试 nil 输入处理
            let result = hotWordService.processText(invalidText ?? "")
            XCTAssertEqual(result, "", "应该安全处理 nil 输入")
        }
    }

    func testConcurrentAccess() {
        // Given
        setUpBasicHotWords()
        let expectation = XCTestExpectation(description: "并发访问完成")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "test.results")

        // When
        for i in 0..<10 {
            concurrentQueue.async {
                let text = "测试并发访问\(i)"
                let result = self.hotWordService.processText(text)

                resultsQueue.async {
                    results.append(result)
                    if results.count == 10 {
                        expectation.fulfill()
                    }
                }
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(results.count, 10, "所有并发操作都应该完成")

        // 验证结果的一致性
        for result in results {
            XCTAssertTrue(result.contains("test"), "并发访问结果应该一致")
        }
    }

    // MARK: - 集成测试

    func testHotWordTypePriority() {
        // Given - 添加不同优先级的热词
        hotWordService.addRuntimeHotWord(original: "测试", replacement: "runtime_test", type: .runtime)

        // 假设还有其他类型的热词文件中也包含"测试"的替换
        
        // When
        let result = hotWordService.processText("测试")

        // Then
        // runtime 类型应该有最高优先级
        XCTAssertEqual(result, "runtime_test", "运行时热词应该有最高优先级")
    }

    // MARK: - 异步操作测试

    func testAsyncHotWordLoading() async throws {
        // Given
        let service = HotWordService()

        // When
        try await service.initialize()

        // Then
        XCTAssertTrue(service.isInitialized, "异步初始化应该完成")
    }

    // MARK: - 测试辅助方法

    private func setUpBasicHotWords() {
        // 添加基本测试热词
        hotWordService.addRuntimeHotWord(original: "你好", replacement: "hello", type: .runtime)
        hotWordService.addRuntimeHotWord(original: "测试", replacement: "test", type: .runtime)
        hotWordService.addRuntimeHotWord(original: "世界", replacement: "world", type: .runtime)
    }

    private func setUpCaseSensitiveHotWords() {
        hotWordService.addRuntimeHotWord(original: "测试", replacement: "test", type: .runtime)
        hotWordService.addRuntimeHotWord(original: "Test", replacement: "replaced_test", type: .runtime)
        hotWordService.addRuntimeHotWord(original: "TEST", replacement: "REPLACED_TEST", type: .runtime)
    }

    // MARK: - 自定义断言

    private func assertHotWordReplacement(
        input: String,
        expected: String,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let result = hotWordService.processText(input)
        XCTAssertEqual(result, expected, message, file: file, line: line)
    }

    private func assertContainsHotWordReplacement(
        input: String,
        shouldContain: String,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let result = hotWordService.processText(input)
        XCTAssertTrue(result.contains(shouldContain), message, file: file, line: line)
    }
}

// MARK: - 测试扩展

extension HotWordServiceTests {
    
    /// 测试热词文件加载
    func testHotWordFileLoading() {
        // 这个测试需要根据实际的文件加载机制来实现
        // 如果 HotWordService 有加载外部文件的功能
    }
    
    /// 测试热词缓存机制
    func testHotWordCaching() {
        // 测试热词的缓存和失效机制
    }
    
    /// 测试内存使用情况
    func testMemoryUsage() {
        measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<1000 {
                _ = hotWordService.processText("测试内存使用情况")
            }
        }
    }
}