# EventBus 集成指南

## 概述

EventBus 是 CapsWriter-mac 项目的事件驱动架构核心，提供类型安全的事件发布和订阅机制，解耦组件间依赖关系。本文档详细说明如何使用和集成 EventBus。

## 核心特性

### 🎯 类型安全的事件系统
- 强类型事件定义，编译时检查
- 自动事件序列化和反序列化
- 丰富的事件元数据支持

### 🚀 高性能异步处理
- 并发队列处理，不阻塞主线程
- 事件优先级调度
- 内存高效的订阅管理

### 📊 完整的监控和调试
- 实时事件统计
- 事件历史追踪
- 性能指标监控

### 🔄 平滑迁移支持
- 与 NotificationCenter 的双向兼容
- 渐进式迁移策略
- 迁移进度追踪

## 快速开始

### 1. 基础事件发布和订阅

```swift
import Foundation

// 发布事件
let event = AppInitializationDidCompleteEvent(
    initializationTime: 2.5,
    configurationLoaded: true,
    permissionsGranted: true
)
EventBus.shared.publish(event, priority: .high)

// 订阅事件
let subscriptionId = EventBus.shared.subscribe(to: AppInitializationDidCompleteEvent.self) { event in
    print("应用初始化完成，耗时: \(event.initializationTime)s")
}

// 取消订阅
EventBus.shared.unsubscribe(subscriptionId)
```

### 2. 使用便捷发布器

```swift
// 应用状态事件
EventBus.appState.publishInitializationComplete(
    initializationTime: 2.5,
    configurationLoaded: true,
    permissionsGranted: true
)

EventBus.appState.publishStateChange(
    from: .initializing,
    to: .running,
    reason: "所有服务已就绪"
)

// 简单事件
EventBus.shared.publishSimpleEvent(
    source: "MyComponent",
    description: "组件状态已更新"
)
```

### 3. 异步事件处理

```swift
// 异步发布
await EventBus.shared.publishAsync(event)

// 等待特定事件
do {
    let event = try await EventBus.shared.waitForEvent(
        of: ASRServiceDidInitializeEvent.self,
        timeout: 10.0
    )
    print("ASR 服务初始化完成: \(event.description)")
} catch {
    print("等待事件超时: \(error)")
}
```

## 事件类型详解

### 应用状态事件

#### AppInitializationDidCompleteEvent
应用初始化完成时发布

```swift
struct AppInitializationDidCompleteEvent: Event {
    let initializationTime: TimeInterval  // 初始化耗时
    let configurationLoaded: Bool         // 配置是否加载成功
    let permissionsGranted: Bool          // 权限是否全部授予
}
```

#### AppRunningStateDidChangeEvent
应用运行状态变更时发布

```swift
struct AppRunningStateDidChangeEvent: Event {
    let oldState: AppRunningState
    let newState: AppRunningState
    let reason: String?
}
```

#### AppErrorDidOccurEvent
应用错误发生时发布

```swift
struct AppErrorDidOccurEvent: Event {
    let error: AppError
    let context: [String: Any]
    let severity: ErrorHandler.ErrorSeverity
}
```

### 权限事件

#### AccessibilityPermissionDidChangeEvent
辅助功能权限变更时发布

```swift
struct AccessibilityPermissionDidChangeEvent: Event {
    let hasPermission: Bool
    let requestedByUser: Bool
}
```

#### MicrophonePermissionDidChangeEvent
麦克风权限变更时发布

```swift
struct MicrophonePermissionDidChangeEvent: Event {
    let hasPermission: Bool
    let authorizationStatus: String
}
```

### 音频事件

#### AudioRecordingDidStartEvent
音频录制开始时发布

```swift
struct AudioRecordingDidStartEvent: Event {
    let deviceInfo: AudioDeviceInfo
    let expectedDuration: TimeInterval?
    let recordingId: UUID
}
```

#### AudioRecordingDidStopEvent
音频录制停止时发布

```swift
struct AudioRecordingDidStopEvent: Event {
    let actualDuration: TimeInterval
    let recordingId: UUID
    let reason: StopReason
    let wasSuccessful: Bool
}
```

### 识别事件

#### ASRServiceStatusDidChangeEvent
ASR 服务状态变更时发布

```swift
struct ASRServiceStatusDidChangeEvent: Event {
    let isRunning: Bool
    let isInitialized: Bool
    let modelInfo: ModelInfo?
    let performanceMetrics: PerformanceMetrics?
}
```

#### RecognitionResultDidUpdateEvent
语音识别结果更新时发布

```swift
struct RecognitionResultDidUpdateEvent: Event {
    let text: String
    let confidence: Double
    let isFinal: Bool
    let languageDetected: String?
    let processingTime: TimeInterval
    let entry: RecognitionEntry?
}
```

### 键盘事件

#### HotkeyTriggeredEvent
快捷键触发时发布

```swift
struct HotkeyTriggeredEvent: Event {
    let keySequence: [String]
    let triggerCount: Int
    let timeSinceLastTrigger: TimeInterval?
    let action: HotkeyAction
}
```

### 配置事件

#### ConfigurationDidUpdateEvent
配置更新时发布

```swift
struct ConfigurationDidUpdateEvent: Event {
    let updatedCategories: [String]
    let changedKeys: [String]
    let isUserInitiated: Bool
    let validationPassed: Bool
}
```

### 错误处理事件

#### ErrorDidOccurEvent
错误发生时发布

```swift
struct ErrorDidOccurEvent: Event {
    let errorRecord: ErrorHandler.ErrorRecord
    let isRecoverable: Bool
    let affectedComponents: [String]
}
```

#### UserActionRequiredEvent
需要用户操作时发布

```swift
struct UserActionRequiredEvent: Event {
    let errorRecord: ErrorHandler.ErrorRecord
    let requiredActions: [UserAction]
    let urgency: Urgency
    let timeoutAfter: TimeInterval?
}
```

## 高级用法

### 1. 事件优先级

```swift
// 不同优先级的事件发布
EventBus.shared.publish(event, priority: .low)      // 低优先级
EventBus.shared.publish(event, priority: .normal)   // 普通优先级（默认）
EventBus.shared.publish(event, priority: .high)     // 高优先级
EventBus.shared.publish(event, priority: .critical) // 严重优先级
```

优先级高的事件会优先分发给订阅者。

### 2. 自定义队列处理

```swift
// 在后台队列处理事件
let backgroundQueue = DispatchQueue(label: "background-processor")
EventBus.shared.subscribe(
    to: RecognitionResultDidUpdateEvent.self,
    queue: backgroundQueue
) { event in
    // 在后台线程处理
    processRecognitionResult(event.text)
}

// 在主队列更新 UI
EventBus.shared.subscribe(
    to: AppRunningStateDidChangeEvent.self,
    queue: .main
) { event in
    // 在主线程更新 UI
    updateStatusIndicator(event.newState)
}
```

### 3. 条件订阅

```swift
// 只订阅高置信度的识别结果
EventBus.shared.subscribe(to: RecognitionResultDidUpdateEvent.self) { event in
    guard event.confidence > 0.8 else { return }
    handleHighConfidenceResult(event)
}

// 只关心权限被拒绝的情况
EventBus.shared.subscribe(to: MicrophonePermissionDidChangeEvent.self) { event in
    if !event.hasPermission {
        showPermissionDeniedAlert()
    }
}
```

### 4. 事件聚合和批处理

```swift
class EventAggregator {
    private var recognitionBuffer: [RecognitionResultDidUpdateEvent] = []
    private let bufferQueue = DispatchQueue(label: "event-buffer")
    
    init() {
        setupAggregation()
    }
    
    private func setupAggregation() {
        EventBus.shared.subscribe(to: RecognitionResultDidUpdateEvent.self) { [weak self] event in
            self?.bufferQueue.async {
                self?.recognitionBuffer.append(event)
                
                // 每收集 10 个事件或 1 秒后批处理
                if self?.recognitionBuffer.count ?? 0 >= 10 {
                    self?.processBatch()
                }
            }
        }
        
        // 定时处理缓冲区
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.processBatch()
        }
    }
    
    private func processBatch() {
        bufferQueue.async {
            guard !self.recognitionBuffer.isEmpty else { return }
            
            let batch = self.recognitionBuffer
            self.recognitionBuffer.removeAll()
            
            // 批量处理事件
            self.handleRecognitionBatch(batch)
        }
    }
    
    private func handleRecognitionBatch(_ events: [RecognitionResultDidUpdateEvent]) {
        // 批量处理逻辑
        print("处理 \(events.count) 个识别结果")
    }
}
```

## 与现有代码的集成

### 1. 渐进式迁移

EventBus 提供了与 NotificationCenter 的双向兼容：

```swift
// 设置适配器
let adapter = EventBusAdapter()
adapter.enableBackwardCompatibility()

// 现有的 NotificationCenter 代码继续工作
NotificationCenter.default.addObserver(/*...*/)

// 新代码使用 EventBus
EventBus.shared.subscribe(to: AppInitializationDidCompleteEvent.self) { /*...*/ }
```

### 2. 迁移现有观察者

**迁移前 (NotificationCenter):**
```swift
NotificationCenter.default.addObserver(
    forName: .audioRecordingDidStart,
    object: nil,
    queue: .main
) { notification in
    handleRecordingStart()
}
```

**迁移后 (EventBus):**
```swift
EventBus.shared.subscribe(to: AudioRecordingDidStartEvent.self) { event in
    handleRecordingStart(event.deviceInfo, recordingId: event.recordingId)
}
```

### 3. 在状态管理类中使用

```swift
class AudioState: ObservableObject {
    private var eventSubscriptions: [UUID] = []
    
    init() {
        setupEventSubscriptions()
    }
    
    private func setupEventSubscriptions() {
        // 订阅权限变更事件
        let permissionSub = EventBus.shared.subscribe(to: MicrophonePermissionDidChangeEvent.self) { [weak self] event in
            DispatchQueue.main.async {
                self?.hasMicrophonePermission = event.hasPermission
            }
        }
        eventSubscriptions.append(permissionSub)
    }
    
    func startRecording() {
        // 发布录音开始事件
        let event = AudioRecordingDidStartEvent(
            deviceInfo: AudioDeviceInfo.current()
        )
        EventBus.shared.publish(event)
        
        // 更新本地状态
        isRecording = true
    }
    
    deinit {
        eventSubscriptions.forEach { EventBus.shared.unsubscribe($0) }
    }
}
```

### 4. SwiftUI 集成

```swift
struct AudioStatusView: View {
    @State private var isRecording = false
    @State private var deviceInfo: AudioDeviceInfo?
    
    var body: some View {
        VStack {
            Text(isRecording ? "录音中..." : "待机")
                .foregroundColor(isRecording ? .red : .primary)
            
            if let device = deviceInfo {
                Text("设备: \(device.inputDeviceName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            setupEventSubscriptions()
        }
    }
    
    private func setupEventSubscriptions() {
        EventBus.shared.subscribe(to: AudioRecordingDidStartEvent.self) { event in
            DispatchQueue.main.async {
                isRecording = true
                deviceInfo = event.deviceInfo
            }
        }
        
        EventBus.shared.subscribe(to: AudioRecordingDidStopEvent.self) { _ in
            DispatchQueue.main.async {
                isRecording = false
            }
        }
    }
}
```

## 调试和监控

### 1. 事件统计

```swift
// 获取事件统计信息
let stats = EventBus.shared.statistics
print("已发布事件: \(stats.totalPublished)")
print("活跃订阅: \(EventBus.shared.activeSubscriptions)")

// 获取特定事件的订阅者数量
let subscriberCount = EventBus.shared.getSubscriberCount(for: AudioRecordingDidStartEvent.self)
print("音频录制事件订阅者: \(subscriberCount)")
```

### 2. 调试信息

```swift
// 打印详细调试信息
print(EventBus.shared.debugInfo)

// 获取最近的事件历史
let recentEvents = EventBus.shared.getRecentEvents(limit: 10)
for (eventType, timestamp) in recentEvents {
    print("\(timestamp): \(eventType)")
}
```

### 3. 性能监控

```swift
// 获取性能指标
let metrics = EventBus.shared.getPerformanceMetrics()
print(metrics.description)
```

### 4. 迁移进度

```swift
// 检查迁移进度
let adapter = EventBusAdapter()
let report = adapter.analyzeNotificationUsage()
print(report.description)
```

## 最佳实践

### 1. 事件设计原则

**✅ 好的事件设计:**
```swift
struct UserActionEvent: Event {
    let timestamp: Date = Date()
    let source: String = "UserInterface"
    let description: String
    
    let action: ActionType
    let targetComponent: String
    let context: [String: Any]
    let userInfo: UserInfo
    
    // 提供详细、有用的信息
    // 包含必要的上下文
    // 使用强类型而不是字典
}
```

**❌ 避免的设计:**
```swift
struct GenericEvent: Event {
    let data: [String: Any]  // 太泛化，失去类型安全
    let type: String         // 使用字符串而不是枚举
}
```

### 2. 订阅管理

**✅ 正确的生命周期管理:**
```swift
class MyComponent {
    private var subscriptions: [UUID] = []
    
    init() {
        let sub = EventBus.shared.subscribe(/*...*/) { /*...*/ }
        subscriptions.append(sub)
    }
    
    deinit {
        subscriptions.forEach { EventBus.shared.unsubscribe($0) }
    }
}
```

**❌ 避免内存泄漏:**
```swift
class MyComponent {
    init() {
        // 忘记保存订阅 ID 或取消订阅会导致内存泄漏
        EventBus.shared.subscribe(/*...*/) { /*...*/ }
    }
}
```

### 3. 事件频率控制

```swift
class ThrottledEventHandler {
    private var lastProcessTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1
    
    func setupThrottledSubscription() {
        EventBus.shared.subscribe(to: RecognitionResultDidUpdateEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            let now = Date()
            if now.timeIntervalSince(self.lastProcessTime) >= self.throttleInterval {
                self.processEvent(event)
                self.lastProcessTime = now
            }
        }
    }
}
```

### 4. 错误处理

```swift
EventBus.shared.subscribe(to: SomeEvent.self) { event in
    do {
        try processEvent(event)
    } catch {
        // 事件处理错误应该被捕获和记录
        ErrorHandler.shared.reportUnknownError(
            "EventProcessor", 
            operation: "处理\(type(of: event))",
            message: error.localizedDescription
        )
    }
}
```

## 性能优化

### 1. 选择合适的队列

```swift
// CPU 密集型任务使用后台队列
let processingQueue = DispatchQueue(label: "heavy-processing", qos: .utility)
EventBus.shared.subscribe(to: AudioDataEvent.self, queue: processingQueue) { event in
    performHeavyProcessing(event.audioData)
}

// UI 更新使用主队列
EventBus.shared.subscribe(to: StateChangeEvent.self, queue: .main) { event in
    updateUserInterface(event.newState)
}
```

### 2. 批量处理

```swift
// 对于高频事件，考虑批量处理
class BatchProcessor {
    private var eventBuffer: [HighFrequencyEvent] = []
    private let batchSize = 50
    
    func setupBatchProcessing() {
        EventBus.shared.subscribe(to: HighFrequencyEvent.self) { [weak self] event in
            self?.eventBuffer.append(event)
            
            if self?.eventBuffer.count ?? 0 >= self?.batchSize ?? 0 {
                self?.processBatch()
            }
        }
    }
}
```

### 3. 条件过滤

```swift
// 在订阅时进行条件过滤，避免不必要的处理
EventBus.shared.subscribe(to: DataUpdateEvent.self) { event in
    // 早期过滤，避免后续处理
    guard event.isRelevant && event.data.count > 0 else { return }
    
    processImportantData(event.data)
}
```

## 故障排除

### 常见问题

1. **事件未被接收**
   - 检查事件类型是否正确
   - 确认订阅在事件发布之前完成
   - 验证订阅者没有被意外取消

2. **内存泄漏**
   - 确保在 `deinit` 中取消订阅
   - 使用 `weak self` 避免循环引用
   - 检查订阅 ID 是否被正确管理

3. **性能问题**
   - 检查是否有过多的高频事件
   - 考虑使用适当的队列
   - 实施事件节流或批处理

4. **类型安全问题**
   - 确保事件类型实现了 `Event` 协议
   - 检查类型转换是否正确
   - 验证事件注册表

### 调试技巧

```swift
// 启用详细日志
EventBus.shared.subscribe(to: BaseEvent.self, priority: .low) { event in
    print("🎯 Event: \(type(of: event)) from \(event.source)")
}

// 监控订阅变化
EventBus.shared.$activeSubscriptions.sink { count in
    print("📊 Active subscriptions: \(count)")
}

// 检查特定事件是否有订阅者
if !EventBus.shared.hasSubscribers(for: MyEvent.self) {
    print("⚠️ No subscribers for MyEvent")
}
```

## 总结

EventBus 为 CapsWriter-mac 提供了强大的事件驱动架构基础：

1. **类型安全**: 编译时检查，避免运行时错误
2. **高性能**: 异步处理，支持优先级调度
3. **易于调试**: 完整的监控和统计功能
4. **平滑迁移**: 与现有代码兼容，支持渐进式重构
5. **扩展性**: 易于添加新事件类型和处理器

通过遵循本指南的最佳实践，可以构建出更加松耦合、易于维护和扩展的应用架构。