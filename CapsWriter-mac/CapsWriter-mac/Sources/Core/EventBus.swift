import Foundation
import Combine
import SwiftUI

/// 事件驱动架构核心 - CapsWriter-mac 第一阶段任务 1.4
/// 提供类型安全的事件发布和订阅机制，解耦组件间依赖
class EventBus: ObservableObject {
    
    // MARK: - Types
    
    /// 事件优先级
    enum EventPriority: Int, CaseIterable {
        case low = 1
        case normal = 2
        case high = 3
        case critical = 4
    }
    
    /// 事件订阅者信息
    private struct Subscription {
        let id: UUID
        let priority: EventPriority
        let handler: (any Event) -> Void
        let queue: DispatchQueue
        
        init<T: Event>(
            id: UUID = UUID(),
            priority: EventPriority,
            handler: @escaping (T) -> Void,
            queue: DispatchQueue
        ) {
            self.id = id
            self.priority = priority
            self.queue = queue
            self.handler = { event in
                if let typedEvent = event as? T {
                    handler(typedEvent)
                }
            }
        }
    }
    
    /// 事件统计信息
    struct EventStatistics {
        var totalPublished: Int = 0
        var totalSubscribed: Int = 0
        var eventCounts: [String: Int] = [:]
        var lastEventTime: Date?
        
        mutating func recordPublication(eventType: String) {
            totalPublished += 1
            eventCounts[eventType, default: 0] += 1
            lastEventTime = Date()
        }
        
        mutating func recordSubscription() {
            totalSubscribed += 1
        }
        
        mutating func reset() {
            totalPublished = 0
            totalSubscribed = 0
            eventCounts.removeAll()
            lastEventTime = nil
        }
    }
    
    // MARK: - Published Properties
    
    /// 事件统计信息
    @Published var statistics: EventStatistics = EventStatistics()
    
    /// 当前活跃订阅者数量
    @Published var activeSubscriptions: Int = 0
    
    /// 最近发布的事件类型
    @Published var lastPublishedEventType: String = ""
    
    // MARK: - Private Properties
    
    private var subscriptions: [String: [Subscription]] = [:]
    private let subscriptionQueue = DispatchQueue(label: "com.capswriter.eventbus", attributes: .concurrent)
    private let statisticsQueue = DispatchQueue(label: "com.capswriter.eventbus.stats")
    
    // 事件缓存用于调试
    private var recentEvents: [(event: any Event, timestamp: Date)] = []
    private let maxRecentEvents = 100
    
    // MARK: - Singleton
    
    static let shared = EventBus()
    
    private init() {
        print("🚌 EventBus: 事件总线已初始化")
    }
    
    // MARK: - Public Interface
    
    /// 发布事件
    func publish<T: Event>(_ event: T, priority: EventPriority = .normal) {
        let eventType = String(describing: T.self)
        
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.processEvent(event, eventType: eventType, priority: priority)
        }
        
        // 更新统计信息
        statisticsQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.statistics.recordPublication(eventType: eventType)
                self?.lastPublishedEventType = eventType
            }
        }
        
        print("📡 EventBus: 发布事件 \(eventType) (优先级: \(priority.description))")
    }
    
    /// 订阅事件
    @discardableResult
    func subscribe<T: Event>(
        to eventType: T.Type,
        priority: EventPriority = .normal,
        queue: DispatchQueue = .main,
        handler: @escaping (T) -> Void
    ) -> UUID {
        let subscription = Subscription(
            priority: priority,
            handler: handler,
            queue: queue
        )
        let eventTypeName = String(describing: eventType)
        
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.addSubscription(subscription, for: eventTypeName)
        }
        
        // 更新统计信息
        statisticsQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.statistics.recordSubscription()
                self?.updateActiveSubscriptionsCount()
            }
        }
        
        print("📝 EventBus: 订阅事件 \(eventTypeName) (订阅ID: \(subscription.id))")
        return subscription.id
    }
    
    /// 取消订阅
    func unsubscribe(_ subscriptionId: UUID) {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.removeSubscription(subscriptionId)
        }
        
        // 更新统计信息
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveSubscriptionsCount()
        }
        
        print("❌ EventBus: 取消订阅 \(subscriptionId)")
    }
    
    /// 取消所有订阅
    func unsubscribeAll() {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.subscriptions.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.activeSubscriptions = 0
        }
        
        print("🗑️ EventBus: 已取消所有订阅")
    }
    
    /// 获取事件类型的订阅者数量
    func getSubscriberCount<T: Event>(for eventType: T.Type) -> Int {
        return subscriptionQueue.sync {
            let eventTypeName = String(describing: eventType)
            return subscriptions[eventTypeName]?.count ?? 0
        }
    }
    
    /// 检查是否有事件类型的订阅者
    func hasSubscribers<T: Event>(for eventType: T.Type) -> Bool {
        return getSubscriberCount(for: eventType) > 0
    }
    
    // MARK: - Event Processing
    
    private func processEvent(_ event: any Event, eventType: String, priority: EventPriority) {
        // 缓存最近事件用于调试
        recentEvents.append((event: event, timestamp: Date()))
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst(recentEvents.count - maxRecentEvents)
        }
        
        // 获取订阅者并按优先级排序
        guard let eventSubscriptions = subscriptions[eventType] else {
            print("⚠️ EventBus: 没有找到事件 \(eventType) 的订阅者")
            return
        }
        
        let sortedSubscriptions = eventSubscriptions.sorted { lhs, rhs in
            lhs.priority.rawValue > rhs.priority.rawValue
        }
        
        // 分发事件给订阅者
        for subscription in sortedSubscriptions {
            subscription.queue.async {
                subscription.handler(event)
            }
        }
        
        print("📬 EventBus: 事件 \(eventType) 已分发给 \(sortedSubscriptions.count) 个订阅者")
    }
    
    private func addSubscription(_ subscription: Subscription, for eventType: String) {
        if subscriptions[eventType] == nil {
            subscriptions[eventType] = []
        }
        subscriptions[eventType]?.append(subscription)
    }
    
    private func removeSubscription(_ subscriptionId: UUID) {
        for (eventType, subs) in subscriptions {
            subscriptions[eventType] = subs.filter { $0.id != subscriptionId }
            
            // 如果该事件类型没有订阅者了，移除该条目
            if subscriptions[eventType]?.isEmpty == true {
                subscriptions.removeValue(forKey: eventType)
            }
        }
    }
    
    private func updateActiveSubscriptionsCount() {
        let count = subscriptions.values.reduce(0) { $0 + $1.count }
        activeSubscriptions = count
    }
    
    // MARK: - Debug and Diagnostics
    
    /// 获取调试信息
    var debugInfo: String {
        return subscriptionQueue.sync {
            var info = "EventBus Debug Info:\n"
            info += "- 活跃订阅: \(activeSubscriptions)\n"
            info += "- 已发布事件: \(statistics.totalPublished)\n"
            info += "- 事件类型数: \(subscriptions.count)\n"
            
            if !subscriptions.isEmpty {
                info += "- 订阅详情:\n"
                for (eventType, subs) in subscriptions.sorted(by: { $0.key < $1.key }) {
                    info += "  • \(eventType): \(subs.count) 个订阅者\n"
                }
            }
            
            return info
        }
    }
    
    /// 获取最近事件历史
    func getRecentEvents(limit: Int = 10) -> [(eventType: String, timestamp: Date)] {
        return Array(recentEvents.suffix(limit)).map { item in
            (eventType: String(describing: type(of: item.event)), timestamp: item.timestamp)
        }
    }
    
    /// 清除事件历史和统计
    func clearHistory() {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.recentEvents.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.statistics.reset()
        }
        
        print("🧹 EventBus: 历史记录和统计已清除")
    }
}

// MARK: - Event Protocol

/// 事件协议 - 所有事件必须实现此协议
protocol Event {
    /// 事件时间戳
    var timestamp: Date { get }
    
    /// 事件源组件
    var source: String { get }
    
    /// 事件描述
    var description: String { get }
}

// MARK: - Base Event Implementation

/// 基础事件实现
struct BaseEvent: Event {
    let timestamp: Date
    let source: String
    let description: String
    
    init(source: String, description: String) {
        self.timestamp = Date()
        self.source = source
        self.description = description
    }
}

// MARK: - Convenience Extensions

extension EventBus {
    
    /// 便捷方法：发布简单事件
    func publishSimpleEvent(
        source: String,
        description: String,
        priority: EventPriority = .normal
    ) {
        let event = BaseEvent(source: source, description: description)
        publish(event, priority: priority)
    }
    
    /// 便捷方法：订阅基础事件
    @discardableResult
    func subscribeToBaseEvents(
        priority: EventPriority = .normal,
        queue: DispatchQueue = .main,
        handler: @escaping (BaseEvent) -> Void
    ) -> UUID {
        return subscribe(to: BaseEvent.self, priority: priority, queue: queue, handler: handler)
    }
}

// MARK: - EventPriority Extensions

extension EventBus.EventPriority {
    var description: String {
        switch self {
        case .low: return "低"
        case .normal: return "普通"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
}

// MARK: - Async Support

extension EventBus {
    
    /// 异步发布事件
    func publishAsync<T: Event>(_ event: T, priority: EventPriority = .normal) async {
        await withCheckedContinuation { continuation in
            publish(event, priority: priority)
            continuation.resume()
        }
    }
    
    /// 等待特定事件
    func waitForEvent<T: Event>(
        of type: T.Type,
        timeout: TimeInterval = 5.0
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    let subscriptionId = self.subscribe(to: type) { event in
                        continuation.resume(returning: event)
                    }
                    
                    // 设置超时清理
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                        self.unsubscribe(subscriptionId)
                    }
                }
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw EventBusError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Error Types

enum EventBusError: LocalizedError {
    case timeout
    case subscriptionNotFound
    case invalidEvent
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "等待事件超时"
        case .subscriptionNotFound:
            return "未找到指定的订阅"
        case .invalidEvent:
            return "无效的事件类型"
        }
    }
}

// MARK: - Performance Monitoring

extension EventBus {
    
    /// 性能监控信息
    struct PerformanceMetrics {
        let averageEventProcessingTime: TimeInterval
        let peakSubscriberCount: Int
        let totalEventTypes: Int
        let memoryUsage: Int // 事件缓存占用内存估算
        
        var description: String {
            return """
            EventBus Performance Metrics:
            - 平均事件处理时间: \(String(format: "%.2f", averageEventProcessingTime * 1000))ms
            - 峰值订阅者数: \(peakSubscriberCount)
            - 事件类型总数: \(totalEventTypes)
            - 内存使用(估算): \(memoryUsage) bytes
            """
        }
    }
    
    /// 获取性能指标
    func getPerformanceMetrics() -> PerformanceMetrics {
        return subscriptionQueue.sync {
            let subscriberCount = subscriptions.values.reduce(0) { $0 + $1.count }
            
            return PerformanceMetrics(
                averageEventProcessingTime: 0.001, // 简化实现，实际应该测量
                peakSubscriberCount: subscriberCount,
                totalEventTypes: subscriptions.count,
                memoryUsage: recentEvents.count * 64 // 粗略估算
            )
        }
    }
}