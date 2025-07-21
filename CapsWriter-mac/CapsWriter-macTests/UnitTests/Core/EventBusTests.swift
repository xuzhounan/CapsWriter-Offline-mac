import XCTest
import Combine
@testable import CapsWriter_mac

class EventBusTests: XCTestCase {

    var eventBus: EventBus!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        eventBus = EventBus()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        eventBus = nil
        super.tearDown()
    }

    // MARK: - 测试事件定义

    struct TestEvent {
        let message: String
        let timestamp: Date
        let priority: Int
        
        init(message: String, priority: Int = 0) {
            self.message = message
            self.timestamp = Date()
            self.priority = priority
        }
    }

    struct AnotherTestEvent {
        let value: Int
        let data: [String: Any]
    }

    struct EmptyTestEvent {}

    // MARK: - 基础功能测试

    func testBasicEventPublishAndSubscribe() {
        // Given
        let expectation = XCTestExpectation(description: "事件接收")
        let testMessage = "测试消息"
        var receivedEvent: TestEvent?

        // 订阅事件
        eventBus.subscribe(TestEvent.self) { event in
            receivedEvent = event
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // When - 发布事件
        let testEvent = TestEvent(message: testMessage)
        eventBus.publish(testEvent)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent, "应该接收到事件")
        XCTAssertEqual(receivedEvent?.message, testMessage, "事件消息应该匹配")
    }

    func testMultipleSubscribersForSameEvent() {
        // Given
        let expectation1 = XCTestExpectation(description: "订阅者1接收事件")
        let expectation2 = XCTestExpectation(description: "订阅者2接收事件")
        let testMessage = "广播消息"

        var received1: TestEvent?
        var received2: TestEvent?

        // 订阅事件 - 订阅者1
        eventBus.subscribe(TestEvent.self) { event in
            received1 = event
            expectation1.fulfill()
        }
        .store(in: &cancellables)

        // 订阅事件 - 订阅者2
        eventBus.subscribe(TestEvent.self) { event in
            received2 = event
            expectation2.fulfill()
        }
        .store(in: &cancellables)

        // When - 发布事件
        let testEvent = TestEvent(message: testMessage)
        eventBus.publish(testEvent)

        // Then
        wait(for: [expectation1, expectation2], timeout: 1.0)
        XCTAssertNotNil(received1, "订阅者1应该接收到事件")
        XCTAssertNotNil(received2, "订阅者2应该接收到事件")
        XCTAssertEqual(received1?.message, testMessage, "订阅者1消息应该匹配")
        XCTAssertEqual(received2?.message, testMessage, "订阅者2消息应该匹配")
    }

    func testMultipleEventTypes() {
        // Given
        let testExpectation = XCTestExpectation(description: "TestEvent接收")
        let anotherExpectation = XCTestExpectation(description: "AnotherTestEvent接收")

        var receivedTestEvent: TestEvent?
        var receivedAnotherEvent: AnotherTestEvent?

        // 订阅不同类型的事件
        eventBus.subscribe(TestEvent.self) { event in
            receivedTestEvent = event
            testExpectation.fulfill()
        }
        .store(in: &cancellables)

        eventBus.subscribe(AnotherTestEvent.self) { event in
            receivedAnotherEvent = event
            anotherExpectation.fulfill()
        }
        .store(in: &cancellables)

        // When - 发布不同类型的事件
        let testEvent = TestEvent(message: "测试")
        let anotherEvent = AnotherTestEvent(value: 42, data: ["key": "value"])

        eventBus.publish(testEvent)
        eventBus.publish(anotherEvent)

        // Then
        wait(for: [testExpectation, anotherExpectation], timeout: 1.0)
        XCTAssertNotNil(receivedTestEvent, "应该接收到TestEvent")
        XCTAssertNotNil(receivedAnotherEvent, "应该接收到AnotherTestEvent")
        XCTAssertEqual(receivedTestEvent?.message, "测试")
        XCTAssertEqual(receivedAnotherEvent?.value, 42)
    }

    // MARK: - 订阅管理测试

    func testSubscriptionCancellation() {
        // Given
        let shouldNotReceive = XCTestExpectation(description: "不应该接收到事件")
        shouldNotReceive.isInverted = true

        var cancellable: AnyCancellable?
        var eventReceived = false

        // 订阅事件
        cancellable = eventBus.subscribe(TestEvent.self) { _ in
            eventReceived = true
            shouldNotReceive.fulfill()
        }

        // When - 取消订阅后发布事件
        cancellable?.cancel()
        let testEvent = TestEvent(message: "应该不会接收到")
        eventBus.publish(testEvent)

        // Then
        wait(for: [shouldNotReceive], timeout: 0.5)
        XCTAssertFalse(eventReceived, "取消订阅后不应该接收到事件")
    }

    func testAutomaticSubscriptionCancellation() {
        // Given
        let shouldNotReceive = XCTestExpectation(description: "不应该接收到事件")
        shouldNotReceive.isInverted = true

        var eventReceived = false

        // 在作用域内订阅事件
        do {
            var localCancellables = Set<AnyCancellable>()
            eventBus.subscribe(TestEvent.self) { _ in
                eventReceived = true
                shouldNotReceive.fulfill()
            }
            .store(in: &localCancellables)
            // localCancellables 在这里超出作用域并自动取消
        }

        // When - 发布事件
        let testEvent = TestEvent(message: "应该不会接收到")
        eventBus.publish(testEvent)

        // Then
        wait(for: [shouldNotReceive], timeout: 0.5)
        XCTAssertFalse(eventReceived, "作用域外的订阅应该自动取消")
    }

    // MARK: - 异步事件处理测试

    func testAsyncEventHandling() {
        // Given
        let expectation = XCTestExpectation(description: "异步事件处理完成")
        var processedEvent: TestEvent?

        // 异步事件处理
        eventBus.subscribe(TestEvent.self) { event in
            DispatchQueue.global(qos: .background).async {
                // 模拟异步处理
                Thread.sleep(forTimeInterval: 0.1)
                
                DispatchQueue.main.async {
                    processedEvent = event
                    expectation.fulfill()
                }
            }
        }
        .store(in: &cancellables)

        // When
        let testEvent = TestEvent(message: "异步处理")
        eventBus.publish(testEvent)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(processedEvent, "异步处理应该完成")
        XCTAssertEqual(processedEvent?.message, "异步处理")
    }

    // MARK: - 高频事件测试

    func testHighFrequencyEventPublishing() {
        // Given
        let expectation = XCTestExpectation(description: "高频事件处理")
        let eventCount = 1000
        var receivedCount = 0

        eventBus.subscribe(TestEvent.self) { _ in
            receivedCount += 1
            if receivedCount == eventCount {
                expectation.fulfill()
            }
        }
        .store(in: &cancellables)

        // When - 发布大量事件
        for i in 0..<eventCount {
            let event = TestEvent(message: "事件\(i)")
            eventBus.publish(event)
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(receivedCount, eventCount, "应该接收到所有事件")
    }

    // MARK: - 并发测试

    func testConcurrentEventPublishing() {
        // Given
        let expectation = XCTestExpectation(description: "并发事件处理完成")
        let publisherCount = 10
        let eventsPerPublisher = 100
        let totalExpectedEvents = publisherCount * eventsPerPublisher

        var receivedEvents: [TestEvent] = []
        let receivedEventsQueue = DispatchQueue(label: "receivedEventsQueue")

        eventBus.subscribe(TestEvent.self) { event in
            receivedEventsQueue.async {
                receivedEvents.append(event)
                if receivedEvents.count == totalExpectedEvents {
                    expectation.fulfill()
                }
            }
        }
        .store(in: &cancellables)

        // When - 并发发布事件
        let concurrentQueue = DispatchQueue(label: "testQueue", attributes: .concurrent)
        
        for publisherId in 0..<publisherCount {
            concurrentQueue.async {
                for eventId in 0..<eventsPerPublisher {
                    let event = TestEvent(message: "Publisher\(publisherId)-Event\(eventId)")
                    self.eventBus.publish(event)
                }
            }
        }

        // Then
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(receivedEvents.count, totalExpectedEvents, "应该接收到所有并发事件")
        
        // 验证事件不重复
        let uniqueMessages = Set(receivedEvents.map { $0.message })
        XCTAssertEqual(uniqueMessages.count, totalExpectedEvents, "所有事件应该是唯一的")
    }

    func testConcurrentSubscriptionAndUnsubscription() {
        // Given
        let expectation = XCTestExpectation(description: "并发订阅测试完成")
        let subscriberCount = 50
        
        var cancellables: [AnyCancellable] = []
        let cancellablesQueue = DispatchQueue(label: "cancellablesQueue")
        let concurrentQueue = DispatchQueue(label: "testQueue", attributes: .concurrent)
        
        // When - 并发订阅和取消订阅
        for i in 0..<subscriberCount {
            concurrentQueue.async {
                let cancellable = self.eventBus.subscribe(TestEvent.self) { event in
                    // 处理事件
                }
                
                cancellablesQueue.async {
                    cancellables.append(cancellable)
                    
                    // 随机取消一些订阅
                    if i % 3 == 0 {
                        cancellable.cancel()
                    }
                    
                    if cancellables.count == subscriberCount {
                        expectation.fulfill()
                    }
                }
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(cancellables.count, subscriberCount, "应该创建所有订阅")
    }

    // MARK: - 内存管理测试

    func testEventBusMemoryManagement() {
        weak var weakEventBus: EventBus?
        
        // Given - 创建事件总线并订阅事件
        autoreleasepool {
            let localEventBus = EventBus()
            weakEventBus = localEventBus
            
            var cancellable: AnyCancellable?
            cancellable = localEventBus.subscribe(TestEvent.self) { _ in
                // 处理事件
            }
            
            // 发布事件
            localEventBus.publish(TestEvent(message: "测试"))
            
            // 取消订阅
            cancellable?.cancel()
            cancellable = nil
        }

        // Then - 验证内存释放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakEventBus, "EventBus 应该被释放")
        }
    }

    func testSubscriberMemoryManagement() {
        // Given
        class TestSubscriber {
            var receivedEvents: [TestEvent] = []
            
            func handleEvent(_ event: TestEvent) {
                receivedEvents.append(event)
            }
        }
        
        weak var weakSubscriber: TestSubscriber?
        var cancellable: AnyCancellable?

        autoreleasepool {
            let subscriber = TestSubscriber()
            weakSubscriber = subscriber
            
            // 订阅事件（使用 weak 引用避免循环引用）
            cancellable = eventBus.subscribe(TestEvent.self) { [weak subscriber] event in
                subscriber?.handleEvent(event)
            }
            
            // 发布事件
            eventBus.publish(TestEvent(message: "测试"))
        }

        // When - 取消订阅
        cancellable?.cancel()
        cancellable = nil

        // Then - 验证订阅者被释放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakSubscriber, "订阅者应该被释放")
        }
    }

    // MARK: - 错误处理测试

    func testSubscriberErrorHandling() {
        // Given
        let expectation = XCTestExpectation(description: "错误处理完成")
        var errorOccurred = false

        // 订阅会抛出错误的事件处理器
        eventBus.subscribe(TestEvent.self) { event in
            defer { expectation.fulfill() }
            
            do {
                // 模拟处理过程中的错误
                if event.message.contains("错误") {
                    throw NSError(domain: "TestError", code: 1, userInfo: nil)
                }
            } catch {
                errorOccurred = true
            }
        }
        .store(in: &cancellables)

        // When
        eventBus.publish(TestEvent(message: "包含错误的消息"))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(errorOccurred, "应该处理错误情况")
    }

    // MARK: - 性能测试

    func testEventPublishingPerformance() {
        // Given
        let eventCount = 10000
        
        eventBus.subscribe(TestEvent.self) { _ in
            // 简单的事件处理
        }
        .store(in: &cancellables)

        // When & Then
        measure {
            for i in 0..<eventCount {
                eventBus.publish(TestEvent(message: "事件\(i)"))
            }
        }
    }

    func testSubscriptionPerformance() {
        // Given & When & Then
        measure {
            let tempCancellables = (0..<1000).map { _ in
                eventBus.subscribe(TestEvent.self) { _ in
                    // 简单处理
                }
            }
            
            // 清理
            tempCancellables.forEach { $0.cancel() }
        }
    }

    // MARK: - 边界条件测试

    func testEmptyEventHandling() {
        // Given
        let expectation = XCTestExpectation(description: "空事件处理")
        var receivedEvent: EmptyTestEvent?

        eventBus.subscribe(EmptyTestEvent.self) { event in
            receivedEvent = event
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // When
        eventBus.publish(EmptyTestEvent())

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent, "应该能处理空事件")
    }

    func testEventWithComplexData() {
        // Given
        let expectation = XCTestExpectation(description: "复杂数据事件处理")
        let complexData: [String: Any] = [
            "string": "测试字符串",
            "number": 42,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]

        var receivedEvent: AnotherTestEvent?

        eventBus.subscribe(AnotherTestEvent.self) { event in
            receivedEvent = event
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // When
        eventBus.publish(AnotherTestEvent(value: 100, data: complexData))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent, "应该处理复杂数据事件")
        XCTAssertEqual(receivedEvent?.value, 100)
        XCTAssertEqual(receivedEvent?.data["string"] as? String, "测试字符串")
    }
}

// MARK: - 测试扩展

extension EventBusTests {
    
    /// 测试事件过滤
    func testEventFiltering() {
        // Given
        let expectation = XCTestExpectation(description: "事件过滤")
        var receivedHighPriorityEvents: [TestEvent] = []

        // 只订阅高优先级事件
        eventBus.subscribe(TestEvent.self) { event in
            if event.priority > 5 {
                receivedHighPriorityEvents.append(event)
                if receivedHighPriorityEvents.count == 2 {
                    expectation.fulfill()
                }
            }
        }
        .store(in: &cancellables)

        // When - 发布不同优先级的事件
        eventBus.publish(TestEvent(message: "低优先级", priority: 1))
        eventBus.publish(TestEvent(message: "高优先级1", priority: 10))
        eventBus.publish(TestEvent(message: "中优先级", priority: 3))
        eventBus.publish(TestEvent(message: "高优先级2", priority: 8))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHighPriorityEvents.count, 2, "应该只接收高优先级事件")
        XCTAssertTrue(receivedHighPriorityEvents.allSatisfy { $0.priority > 5 })
    }

    /// 测试事件转换
    func testEventTransformation() {
        // Given
        let expectation = XCTestExpectation(description: "事件转换")
        var transformedMessages: [String] = []

        eventBus.subscribe(TestEvent.self) { event in
            let transformedMessage = event.message.uppercased()
            transformedMessages.append(transformedMessage)
            if transformedMessages.count == 3 {
                expectation.fulfill()
            }
        }
        .store(in: &cancellables)

        // When
        eventBus.publish(TestEvent(message: "hello"))
        eventBus.publish(TestEvent(message: "world"))
        eventBus.publish(TestEvent(message: "swift"))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(transformedMessages, ["HELLO", "WORLD", "SWIFT"])
    }
}