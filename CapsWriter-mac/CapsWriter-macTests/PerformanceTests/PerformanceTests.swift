import XCTest
@testable import CapsWriter_mac

/// 性能测试套件
/// 测试关键组件的性能表现，确保满足实时性要求
class PerformanceTests: XCTestCase {

    var hotWordService: HotWordService!
    var configManager: ConfigurationManager!
    var eventBus: EventBus!

    override func setUp() {
        super.setUp()
        
        // 设置性能测试环境
        TestConfiguration.setupTestEnvironment(for: .performance)
        
        // 初始化服务
        hotWordService = HotWordService()
        configManager = ConfigurationManager()
        eventBus = EventBus()
        
        do {
            try hotWordService.initialize()
            try hotWordService.start()
        } catch {
            XCTFail("性能测试服务初始化失败: \(error)")
        }
    }

    override func tearDown() {
        hotWordService?.cleanup()
        hotWordService = nil
        configManager = nil
        eventBus = nil
        super.tearDown()
    }

    // MARK: - 热词处理性能测试

    func testHotWordProcessingPerformance() {
        // Given - 设置大量热词
        for i in 0..<1000 {
            hotWordService.addRuntimeHotWord(
                original: "热词\(i)",
                replacement: "hotword_\(i)",
                type: .runtime
            )
        }
        
        let testText = generatePerformanceTestText(length: 1000)
        
        // When & Then - 测量热词处理性能
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = hotWordService.processText(testText)
        }
        
        // 验证性能基准
        let (result, executionTime) = measureExecutionTime {
            return hotWordService.processText(testText)
        }
        
        XCTAssertLessThan(executionTime, TestConfiguration.maxProcessingTime, 
                         "热词处理时间应小于 \(TestConfiguration.maxProcessingTime) 秒")
        XCTAssertFalse(result.isEmpty, "处理结果不应为空")
    }

    func testHotWordProcessingMemoryUsage() {
        // Given - 准备测试数据
        let testTexts = (0..<100).map { _ in 
            generatePerformanceTestText(length: 500)
        }
        
        // When & Then - 测量内存使用
        let (_, memoryDelta) = measureMemoryUsage {
            for text in testTexts {
                _ = hotWordService.processText(text)
            }
        }
        
        // 验证内存使用合理
        XCTAssertLessThan(abs(memoryDelta), 50 * 1024 * 1024, // 50MB
                         "内存使用变化应小于 50MB")
    }

    func testHotWordBatchProcessingPerformance() {
        // Given - 批量文本处理测试
        let batchSize = 1000
        let texts = (0..<batchSize).map { i in
            "这是测试文本\(i)，包含一些热词内容\(i % 10)"
        }
        
        // 添加相关热词
        for i in 0..<10 {
            hotWordService.addRuntimeHotWord(
                original: "内容\(i)",
                replacement: "content_\(i)",
                type: .runtime
            )
        }
        
        // When & Then - 测量批量处理性能
        measure {
            for text in texts {
                _ = hotWordService.processText(text)
            }
        }
    }

    // MARK: - 配置管理性能测试

    func testConfigurationLoadingPerformance() {
        // Given - 创建复杂配置
        configManager.load()
        
        // 设置复杂的配置数据
        configManager.hotwords.hotwordFiles = Array(repeating: "test-file", count: 100)
        
        // When & Then - 测量配置加载性能
        measure {
            let newConfigManager = ConfigurationManager()
            newConfigManager.load()
        }
        
        // 验证加载时间
        let (_, loadingTime) = measureExecutionTime {
            let manager = ConfigurationManager()
            manager.load()
        }
        
        XCTAssertLessThan(loadingTime, 1.0, "配置加载时间应小于 1 秒")
    }

    func testConfigurationSavingPerformance() throws {
        // Given - 加载配置
        configManager.load()
        
        // When & Then - 测量配置保存性能
        measure {
            do {
                try configManager.save()
            } catch {
                XCTFail("配置保存失败: \(error)")
            }
        }
        
        // 验证保存时间
        let (_, savingTime) = measureExecutionTime {
            do {
                try configManager.save()
            } catch {
                XCTFail("性能测试中配置保存失败: \(error)")
            }
        }
        
        XCTAssertLessThan(savingTime, 0.5, "配置保存时间应小于 0.5 秒")
    }

    // MARK: - 事件总线性能测试

    func testEventBusPublishingPerformance() {
        // Given - 准备事件数据
        let eventCount = 10000
        let events = (0..<eventCount).map { i in
            TestPerformanceEvent(id: i, data: "test_data_\(i)")
        }
        
        // When & Then - 测量事件发布性能
        measure {
            for event in events {
                eventBus.publish(event)
            }
        }
        
        // 验证发布效率
        let (_, publishingTime) = measureExecutionTime {
            for event in events {
                eventBus.publish(event)
            }
        }
        
        let averageTimePerEvent = publishingTime / Double(eventCount)
        XCTAssertLessThan(averageTimePerEvent, 0.0001, // 0.1ms per event
                         "单个事件发布时间应小于 0.1ms")
    }

    func testEventBusSubscriptionPerformance() {
        // Given - 创建大量订阅
        let subscriptionCount = 1000
        var cancellables: [AnyCancellable] = []
        
        // When & Then - 测量订阅性能
        measure {
            cancellables = (0..<subscriptionCount).map { _ in
                eventBus.subscribe(TestPerformanceEvent.self) { _ in
                    // 简单处理
                }
            }
        }
        
        // 清理订阅
        cancellables.forEach { $0.cancel() }
        
        // 验证订阅效率
        let (createdCancellables, subscriptionTime) = measureExecutionTime {
            return (0..<subscriptionCount).map { _ in
                eventBus.subscribe(TestPerformanceEvent.self) { _ in
                    // 处理
                }
            }
        }
        
        let averageTimePerSubscription = subscriptionTime / Double(subscriptionCount)
        XCTAssertLessThan(averageTimePerSubscription, 0.001, // 1ms per subscription
                         "单个订阅创建时间应小于 1ms")
        
        // 清理
        createdCancellables.forEach { $0.cancel() }
    }

    func testEventBusHighThroughputPerformance() {
        // Given - 设置高吞吐量测试
        let subscriberCount = 100
        let eventCount = 10000
        
        var receivedEventCounts: [Int] = Array(repeating: 0, count: subscriberCount)
        let countsQueue = DispatchQueue(label: "counts")
        
        // 创建订阅者
        let cancellables = (0..<subscriberCount).map { index in
            eventBus.subscribe(TestPerformanceEvent.self) { _ in
                countsQueue.async {
                    receivedEventCounts[index] += 1
                }
            }
        }
        
        // When & Then - 测量高吞吐量性能
        measure {
            for i in 0..<eventCount {
                eventBus.publish(TestPerformanceEvent(id: i, data: "high_throughput_\(i)"))
            }
        }
        
        // 等待所有事件处理完成
        let expectation = XCTestExpectation(description: "所有事件处理完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        // 验证吞吐量
        countsQueue.sync {
            let totalReceived = receivedEventCounts.reduce(0, +)
            let expectedTotal = eventCount * subscriberCount
            
            // 允许一定的丢失率（高并发下可能有少量丢失）
            let successRate = Double(totalReceived) / Double(expectedTotal)
            XCTAssertGreaterThan(successRate, 0.95, "事件传递成功率应大于 95%")
        }
        
        // 清理
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - 并发性能测试

    func testConcurrentHotWordProcessing() {
        // Given - 设置并发测试
        let concurrentThreadCount = 10
        let operationsPerThread = 100
        let totalOperations = concurrentThreadCount * operationsPerThread
        
        // 添加热词
        for i in 0..<50 {
            hotWordService.addRuntimeHotWord(
                original: "并发\(i)",
                replacement: "concurrent_\(i)",
                type: .runtime
            )
        }
        
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "concurrent.test", attributes: .concurrent)
        
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // When & Then - 测量并发处理性能
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for threadIndex in 0..<concurrentThreadCount {
            group.enter()
            concurrentQueue.async {
                let threadResults = (0..<operationsPerThread).map { opIndex in
                    let text = "并发测试\(threadIndex)-\(opIndex % 10)"
                    return self.hotWordService.processText(text)
                }
                
                resultsQueue.async {
                    results.append(contentsOf: threadResults)
                    group.leave()
                }
            }
        }
        
        let result = group.wait(timeout: .now() + 30)
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        XCTAssertEqual(result, .success, "并发操作应该在超时时间内完成")
        XCTAssertEqual(results.count, totalOperations, "应该完成所有操作")
        
        let operationsPerSecond = Double(totalOperations) / totalTime
        XCTAssertGreaterThan(operationsPerSecond, 1000, "每秒处理操作数应大于 1000")
        
        print("并发性能: \(operationsPerSecond) 操作/秒")
    }

    // MARK: - 内存泄漏性能测试

    func testMemoryLeaksInLongRunningOperations() {
        // Given - 长时间运行测试
        let iterations = 1000
        let initialMemory = getMemoryUsage()
        
        // When - 执行大量操作
        for i in 0..<iterations {
            // 创建和销毁服务
            autoreleasepool {
                let tempHotWordService = HotWordService()
                try? tempHotWordService.initialize()
                tempHotWordService.addRuntimeHotWord(
                    original: "临时\(i)",
                    replacement: "temp_\(i)",
                    type: .runtime
                )
                _ = tempHotWordService.processText("临时测试\(i)")
                tempHotWordService.cleanup()
            }
            
            // 创建和销毁事件总线订阅
            autoreleasepool {
                let tempEventBus = EventBus()
                let cancellable = tempEventBus.subscribe(TestPerformanceEvent.self) { _ in }
                tempEventBus.publish(TestPerformanceEvent(id: i, data: "temp"))
                cancellable.cancel()
            }
        }
        
        // 强制垃圾回收
        for _ in 0..<3 {
            autoreleasepool {}
        }
        
        // Then - 验证内存使用
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 允许合理的内存增长（< 10MB）
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024,
                         "长时间运行后内存增长应小于 10MB，实际增长: \(memoryIncrease) bytes")
        
        print("内存使用变化: \(memoryIncrease) bytes")
    }

    // MARK: - 压力测试

    func testStressTestWithHighVolume() {
        // Given - 高容量压力测试
        let textCount = 5000
        let hotWordCount = 2000
        
        // 添加大量热词
        for i in 0..<hotWordCount {
            hotWordService.addRuntimeHotWord(
                original: "压力\(i)",
                replacement: "stress_\(i)",
                type: .runtime
            )
        }
        
        // 生成测试文本
        let testTexts = (0..<textCount).map { i in
            "这是压力测试文本\(i)，包含压力\(i % 100)等热词"
        }
        
        // When & Then - 执行压力测试
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            for text in testTexts {
                _ = hotWordService.processText(text)
            }
        }
        
        // 验证系统在压力下仍能正常工作
        let finalResult = hotWordService.processText("压力0 压力999")
        XCTAssertTrue(finalResult.contains("stress_0"), "压力测试后系统应仍能正常工作")
        XCTAssertTrue(finalResult.contains("stress_999"), "压力测试后系统应仍能正常工作")
    }

    // MARK: - 辅助方法

    private func generatePerformanceTestText(length: Int) -> String {
        let words = ["测试", "性能", "处理", "热词", "文本", "系统", "功能", "应用", "开发", "集成"]
        return (0..<length).map { _ in words.randomElement()! }.joined(separator: " ")
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    private func measureExecutionTime<T>(operation: () -> T) -> (result: T, executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }

    private func measureMemoryUsage<T>(operation: () -> T) -> (result: T, memoryDelta: Int64) {
        let startMemory = getMemoryUsage()
        let result = operation()
        let endMemory = getMemoryUsage()
        return (result, endMemory - startMemory)
    }
}

// MARK: - 性能测试事件

struct TestPerformanceEvent {
    let id: Int
    let data: String
    let timestamp: Date = Date()
}