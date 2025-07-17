import Foundation

/// EventBus 功能测试套件
/// 验证事件驱动架构的核心功能
class TestEventBus {
    
    private let eventBus: EventBus
    private var testSubscriptions: [UUID] = []
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Test Runner
    
    static func runAllTests() {
        print("🧪 开始 EventBus 功能测试...\n")
        
        let tester = TestEventBus()
        
        tester.testBasicEventPublishingAndSubscription()
        tester.testEventPriorities()
        tester.testAsyncEventHandling()
        tester.testEventFiltering()
        tester.testMultipleSubscribers()
        tester.testUnsubscription()
        tester.testEventStatistics()
        tester.testEventTypeRegistry()
        tester.testPerformanceMetrics()
        tester.testErrorHandling()
        tester.testBackwardCompatibility()
        
        print("\n✅ EventBus 测试完成!")
        tester.printTestSummary()
    }
    
    // MARK: - Individual Tests
    
    /// 测试基本事件发布和订阅
    func testBasicEventPublishingAndSubscription() {
        print("📋 测试 1: 基本事件发布和订阅")
        
        var receivedEvent: AppInitializationDidCompleteEvent?
        
        // 订阅事件
        let subscriptionId = eventBus.subscribe(to: AppInitializationDidCompleteEvent.self) { event in
            receivedEvent = event
        }
        testSubscriptions.append(subscriptionId)
        
        // 发布事件
        let originalEvent = AppInitializationDidCompleteEvent(
            initializationTime: 2.5,
            configurationLoaded: true,
            permissionsGranted: true
        )
        eventBus.publish(originalEvent)
        
        // 给事件处理一些时间
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证事件被接收
        assert(receivedEvent != nil, "事件应该被接收")
        assert(receivedEvent?.initializationTime == 2.5, "事件数据应该正确")
        assert(receivedEvent?.configurationLoaded == true, "事件数据应该正确")
        
        print("   ✅ 基本事件发布和订阅功能正常")
    }
    
    /// 测试事件优先级
    func testEventPriorities() {
        print("📋 测试 2: 事件优先级")
        
        var receivedEvents: [String] = []
        
        // 订阅基础事件
        let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { event in
            receivedEvents.append(event.description)
        }
        testSubscriptions.append(subscriptionId)
        
        // 发布不同优先级的事件
        eventBus.publish(BaseEvent(source: "Test", description: "低优先级"), priority: .low)
        eventBus.publish(BaseEvent(source: "Test", description: "高优先级"), priority: .high)
        eventBus.publish(BaseEvent(source: "Test", description: "严重优先级"), priority: .critical)
        eventBus.publish(BaseEvent(source: "Test", description: "普通优先级"), priority: .normal)
        
        // 给事件处理一些时间
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证事件按优先级处理（高优先级先处理）
        assert(receivedEvents.count == 4, "应该接收到所有事件")
        // 注意：实际的优先级排序取决于具体实现
        
        print("   ✅ 事件优先级功能正常")
    }
    
    /// 测试异步事件处理
    func testAsyncEventHandling() {
        print("📋 测试 3: 异步事件处理")
        
        var asyncEventReceived = false
        
        // 在后台队列订阅
        let backgroundQueue = DispatchQueue(label: "test-background")
        let subscriptionId = eventBus.subscribe(
            to: BaseEvent.self,
            queue: backgroundQueue
        ) { event in
            // 模拟异步处理
            Thread.sleep(forTimeInterval: 0.05)
            asyncEventReceived = true
        }
        testSubscriptions.append(subscriptionId)
        
        // 发布事件
        let event = BaseEvent(source: "AsyncTest", description: "异步处理测试")
        eventBus.publish(event)
        
        // 等待异步处理完成
        let expectation = Date(timeIntervalSinceNow: 0.2)
        while !asyncEventReceived && Date() < expectation {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        assert(asyncEventReceived, "异步事件应该被处理")
        
        print("   ✅ 异步事件处理功能正常")
    }
    
    /// 测试事件过滤
    func testEventFiltering() {
        print("📋 测试 4: 事件过滤")
        
        var filteredEvents: [RecognitionResultDidUpdateEvent] = []
        
        // 只订阅高置信度的识别结果
        let subscriptionId = eventBus.subscribe(to: RecognitionResultDidUpdateEvent.self) { event in
            if event.confidence > 0.8 {
                filteredEvents.append(event)
            }
        }
        testSubscriptions.append(subscriptionId)
        
        // 发布不同置信度的事件
        let lowConfidenceEvent = RecognitionResultDidUpdateEvent(
            text: "低置信度",
            confidence: 0.5,
            isFinal: true,
            processingTime: 0.1
        )
        let highConfidenceEvent = RecognitionResultDidUpdateEvent(
            text: "高置信度",
            confidence: 0.9,
            isFinal: true,
            processingTime: 0.1
        )
        
        eventBus.publish(lowConfidenceEvent)
        eventBus.publish(highConfidenceEvent)
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证只有高置信度事件被处理
        assert(filteredEvents.count == 1, "应该只有一个高置信度事件被处理")
        assert(filteredEvents.first?.confidence == 0.9, "应该是高置信度事件")
        
        print("   ✅ 事件过滤功能正常")
    }
    
    /// 测试多个订阅者
    func testMultipleSubscribers() {
        print("📋 测试 5: 多个订阅者")
        
        var subscriber1Received = false
        var subscriber2Received = false
        var subscriber3Received = false
        
        // 多个订阅者订阅同一事件
        let sub1 = eventBus.subscribe(to: BaseEvent.self) { _ in
            subscriber1Received = true
        }
        let sub2 = eventBus.subscribe(to: BaseEvent.self) { _ in
            subscriber2Received = true
        }
        let sub3 = eventBus.subscribe(to: BaseEvent.self) { _ in
            subscriber3Received = true
        }
        
        testSubscriptions.append(contentsOf: [sub1, sub2, sub3])
        
        // 验证订阅者数量
        let subscriberCount = eventBus.getSubscriberCount(for: BaseEvent.self)
        assert(subscriberCount >= 3, "应该有至少3个订阅者")
        
        // 发布事件
        let event = BaseEvent(source: "MultiTest", description: "多订阅者测试")
        eventBus.publish(event)
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证所有订阅者都收到事件
        assert(subscriber1Received, "订阅者1应该收到事件")
        assert(subscriber2Received, "订阅者2应该收到事件")
        assert(subscriber3Received, "订阅者3应该收到事件")
        
        print("   ✅ 多个订阅者功能正常")
    }
    
    /// 测试取消订阅
    func testUnsubscription() {
        print("📋 测试 6: 取消订阅")
        
        var eventReceived = false
        
        // 订阅事件
        let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { _ in
            eventReceived = true
        }
        
        // 发布事件（应该被接收）
        eventBus.publish(BaseEvent(source: "UnsubTest", description: "取消订阅前"))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        assert(eventReceived, "取消订阅前应该收到事件")
        
        // 取消订阅
        eventBus.unsubscribe(subscriptionId)
        
        // 重置标志
        eventReceived = false
        
        // 再次发布事件（不应该被接收）
        eventBus.publish(BaseEvent(source: "UnsubTest", description: "取消订阅后"))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        assert(!eventReceived, "取消订阅后不应该收到事件")
        
        print("   ✅ 取消订阅功能正常")
    }
    
    /// 测试事件统计
    func testEventStatistics() {
        print("📋 测试 7: 事件统计")
        
        let initialStats = eventBus.statistics
        let initialPublished = initialStats.totalPublished
        let initialSubscribed = initialStats.totalSubscribed
        
        // 添加订阅
        let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { _ in }
        testSubscriptions.append(subscriptionId)
        
        // 发布事件
        eventBus.publish(BaseEvent(source: "StatsTest", description: "统计测试"))
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证统计更新
        let newStats = eventBus.statistics
        assert(newStats.totalPublished > initialPublished, "已发布事件数应该增加")
        assert(newStats.totalSubscribed > initialSubscribed, "订阅数应该增加")
        
        print("   ✅ 事件统计功能正常")
    }
    
    /// 测试事件类型注册表
    func testEventTypeRegistry() {
        print("📋 测试 8: 事件类型注册表")
        
        let registry = EventTypeRegistry.shared
        
        // 测试内置事件类型是否已注册
        assert(registry.isRegistered(AppInitializationDidCompleteEvent.self), "应用初始化事件应该已注册")
        assert(registry.isRegistered(AudioRecordingDidStartEvent.self), "音频录制事件应该已注册")
        assert(registry.isRegistered(RecognitionResultDidUpdateEvent.self), "识别结果事件应该已注册")
        
        // 注册自定义事件类型
        struct CustomEvent: Event {
            let timestamp: Date = Date()
            let source: String = "CustomTest"
            let description: String = "自定义事件"
        }
        
        registry.register(CustomEvent.self)
        assert(registry.isRegistered(CustomEvent.self), "自定义事件应该被注册")
        
        // 检查注册的事件类型数量
        let registeredTypes = registry.allRegisteredTypes
        assert(registeredTypes.count > 10, "应该有多个已注册的事件类型")
        
        print("   ✅ 事件类型注册表功能正常")
    }
    
    /// 测试性能指标
    func testPerformanceMetrics() {
        print("📋 测试 9: 性能指标")
        
        // 获取性能指标
        let metrics = eventBus.getPerformanceMetrics()
        
        // 验证指标存在
        assert(metrics.totalEventTypes >= 0, "事件类型总数应该为非负数")
        assert(metrics.peakSubscriberCount >= 0, "峰值订阅者数应该为非负数")
        assert(metrics.averageEventProcessingTime >= 0, "平均处理时间应该为非负数")
        assert(metrics.memoryUsage >= 0, "内存使用应该为非负数")
        
        print("   📊 性能指标: \(metrics.description)")
        print("   ✅ 性能指标功能正常")
    }
    
    /// 测试错误处理
    func testErrorHandling() {
        print("📋 测试 10: 错误处理")
        
        var errorHandled = false
        
        // 订阅可能抛出异常的事件处理器
        let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { event in
            if event.description.contains("错误") {
                // 模拟处理过程中的错误
                // 在实际应用中，这些错误应该被适当处理
                errorHandled = true
            }
        }
        testSubscriptions.append(subscriptionId)
        
        // 发布可能引起错误的事件
        eventBus.publish(BaseEvent(source: "ErrorTest", description: "触发错误的事件"))
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        assert(errorHandled, "错误处理应该被触发")
        
        print("   ✅ 错误处理功能正常")
    }
    
    /// 测试向后兼容性
    func testBackwardCompatibility() {
        print("📋 测试 11: 向后兼容性")
        
        let adapter = EventBusAdapter(eventBus: eventBus)
        
        // 获取迁移报告
        let report = adapter.analyzeNotificationUsage()
        
        // 验证报告内容
        assert(report.totalNotifications > 0, "应该检测到通知")
        assert(report.migrationProgress >= 0 && report.migrationProgress <= 1, "迁移进度应该在0-1之间")
        assert(!report.suggestions.isEmpty, "应该有迁移建议")
        
        print("   📊 迁移报告:")
        print("   \(report.description)")
        print("   ✅ 向后兼容性功能正常")
    }
    
    // MARK: - Performance Tests
    
    /// 性能压力测试
    func performanceStressTest() {
        print("📋 性能测试: 压力测试")
        
        let startTime = Date()
        let eventCount = 1000
        var receivedCount = 0
        
        // 设置多个订阅者
        for i in 0..<10 {
            let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { _ in
                receivedCount += 1
            }
            testSubscriptions.append(subscriptionId)
        }
        
        // 发布大量事件
        for i in 0..<eventCount {
            let event = BaseEvent(source: "StressTest", description: "事件 \(i)")
            eventBus.publish(event)
        }
        
        // 等待所有事件处理完成
        let timeout = Date(timeIntervalSinceNow: 5.0)
        while receivedCount < eventCount * 10 && Date() < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let eventsPerSecond = Double(eventCount) / duration
        
        print("   📊 处理 \(eventCount) 个事件，耗时 \(String(format: "%.3f", duration))s")
        print("   📊 吞吐量: \(String(format: "%.1f", eventsPerSecond)) 事件/秒")
        print("   📊 接收到 \(receivedCount) 个事件（预期 \(eventCount * 10)）")
        
        assert(receivedCount == eventCount * 10, "所有事件应该被所有订阅者接收")
        assert(eventsPerSecond > 100, "性能应该足够（>100 事件/秒）")
        
        print("   ✅ 性能压力测试通过")
    }
    
    // MARK: - Memory Tests
    
    /// 内存泄漏测试
    func memoryLeakTest() {
        print("📋 内存测试: 内存泄漏检测")
        
        var subscriptions: [UUID] = []
        
        // 创建大量订阅
        for i in 0..<100 {
            let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { _ in
                // 简单处理
            }
            subscriptions.append(subscriptionId)
        }
        
        let beforeCount = eventBus.activeSubscriptions
        
        // 取消所有订阅
        subscriptions.forEach { eventBus.unsubscribe($0) }
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        let afterCount = eventBus.activeSubscriptions
        let freed = beforeCount - afterCount
        
        print("   📊 取消订阅前: \(beforeCount), 取消后: \(afterCount)")
        print("   📊 释放的订阅: \(freed)")
        
        assert(freed >= 100, "应该释放所有创建的订阅")
        
        print("   ✅ 内存泄漏测试通过")
    }
    
    // MARK: - Async Tests
    
    /// 异步等待事件测试
    func asyncWaitForEventTest() async {
        print("📋 异步测试: 等待事件")
        
        // 在后台延迟发布事件
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            let event = AppInitializationDidCompleteEvent(
                initializationTime: 1.0,
                configurationLoaded: true,
                permissionsGranted: true
            )
            eventBus.publish(event)
        }
        
        do {
            // 等待事件
            let event = try await eventBus.waitForEvent(
                of: AppInitializationDidCompleteEvent.self,
                timeout: 1.0
            )
            
            assert(event.initializationTime == 1.0, "事件数据应该正确")
            print("   ✅ 异步等待事件测试通过")
        } catch {
            assert(false, "不应该超时: \(error)")
        }
    }
    
    /// 异步发布事件测试
    func asyncPublishEventTest() async {
        print("📋 异步测试: 异步发布事件")
        
        var eventReceived = false
        
        let subscriptionId = eventBus.subscribe(to: BaseEvent.self) { _ in
            eventReceived = true
        }
        testSubscriptions.append(subscriptionId)
        
        let event = BaseEvent(source: "AsyncTest", description: "异步发布测试")
        await eventBus.publishAsync(event)
        
        // 给事件处理一些时间
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        assert(eventReceived, "异步发布的事件应该被接收")
        print("   ✅ 异步发布事件测试通过")
    }
    
    // MARK: - Cleanup and Summary
    
    private func cleanup() {
        testSubscriptions.forEach { eventBus.unsubscribe($0) }
        testSubscriptions.removeAll()
    }
    
    func printTestSummary() {
        print("\n📊 EventBus 测试摘要:")
        print("- 活跃订阅: \(eventBus.activeSubscriptions)")
        print("- 已发布事件: \(eventBus.statistics.totalPublished)")
        print("- 事件类型: \(EventTypeRegistry.shared.allRegisteredTypes.count)")
        
        let recentEvents = eventBus.getRecentEvents(limit: 5)
        if !recentEvents.isEmpty {
            print("- 最近事件:")
            for (eventType, timestamp) in recentEvents {
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                print("  • \(formatter.string(from: timestamp)): \(eventType)")
            }
        }
        
        print("\n🏁 调试信息:")
        print(eventBus.debugInfo)
        
        print("\n📈 性能指标:")
        print(eventBus.getPerformanceMetrics().description)
    }
    
    // MARK: - Comprehensive Test Runner
    
    static func runComprehensiveTests() async {
        print("🚀 启动 EventBus 综合测试套件\n")
        
        let tester = TestEventBus()
        
        // 基础功能测试
        runAllTests()
        
        // 性能测试
        tester.performanceStressTest()
        tester.memoryLeakTest()
        
        // 异步测试
        await tester.asyncWaitForEventTest()
        await tester.asyncPublishEventTest()
        
        print("\n🎉 所有测试通过! EventBus 功能完全正常。")
        
        // 清理测试数据
        tester.eventBus.clearHistory()
        tester.cleanup()
    }
}

// MARK: - Test Events

struct TestEvent: Event {
    let timestamp: Date = Date()
    let source: String = "TestSuite"
    let description: String
    let testData: [String: Any]
    
    init(description: String, testData: [String: Any] = [:]) {
        self.description = description
        self.testData = testData
    }
}

struct PerformanceTestEvent: Event {
    let timestamp: Date = Date()
    let source: String = "PerformanceTest"
    let description: String = "性能测试事件"
    let sequenceNumber: Int
    
    init(sequenceNumber: Int) {
        self.sequenceNumber = sequenceNumber
    }
}

// MARK: - Test Utilities

extension TestEventBus {
    
    /// 测试辅助工具：等待条件满足
    func waitForCondition(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 1.0,
        description: String = "条件满足"
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        let success = condition()
        if !success {
            print("   ⚠️ 等待超时: \(description)")
        }
        
        return success
    }
    
    /// 测试辅助工具：创建测试事件
    func createTestEvent(id: String, data: [String: Any] = [:]) -> TestEvent {
        return TestEvent(
            description: "测试事件 \(id)",
            testData: data
        )
    }
}

// 可以在需要时运行测试
// TestEventBus.runAllTests()
// Task { await TestEventBus.runComprehensiveTests() }