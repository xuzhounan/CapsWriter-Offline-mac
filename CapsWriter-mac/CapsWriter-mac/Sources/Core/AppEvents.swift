import Foundation

/// CapsWriter-mac 应用事件定义
/// 将原有的 NotificationCenter 通知转换为类型安全的事件系统

// MARK: - Application State Events

/// 应用初始化完成事件
struct AppInitializationDidCompleteEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AppState"
    let description: String = "应用初始化已完成"
    
    let initializationTime: TimeInterval
    let configurationLoaded: Bool
    let permissionsGranted: Bool
    
    init(initializationTime: TimeInterval, configurationLoaded: Bool, permissionsGranted: Bool) {
        self.initializationTime = initializationTime
        self.configurationLoaded = configurationLoaded
        self.permissionsGranted = permissionsGranted
    }
}

/// 应用运行状态变更事件
struct AppRunningStateDidChangeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AppState"
    let description: String
    
    let oldState: AppRunningState
    let newState: AppRunningState
    let reason: String?
    
    init(oldState: AppRunningState, newState: AppRunningState, reason: String? = nil) {
        self.oldState = oldState
        self.newState = newState
        self.reason = reason
        self.description = "应用状态从 \(oldState.rawValue) 变更为 \(newState.rawValue)"
    }
}

/// 应用错误事件
struct AppErrorDidOccurEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AppState"
    let description: String
    
    let error: AppError
    let context: [String: Any]
    let severity: ErrorHandler.ErrorSeverity
    
    init(error: AppError, context: [String: Any] = [:], severity: ErrorHandler.ErrorSeverity) {
        self.error = error
        self.context = context
        self.severity = severity
        self.description = "应用错误: \(error.localizedDescription)"
    }
}

// MARK: - Permission Events

/// 辅助功能权限变更事件
struct AccessibilityPermissionDidChangeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "PermissionManager"
    let description: String
    
    let hasPermission: Bool
    let requestedByUser: Bool
    
    init(hasPermission: Bool, requestedByUser: Bool = false) {
        self.hasPermission = hasPermission
        self.requestedByUser = requestedByUser
        self.description = "辅助功能权限\(hasPermission ? "已授予" : "被拒绝")"
    }
}

/// 文本输入权限变更事件
struct TextInputPermissionDidChangeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "PermissionManager"
    let description: String
    
    let hasPermission: Bool
    let dependsOnAccessibility: Bool
    
    init(hasPermission: Bool, dependsOnAccessibility: Bool = true) {
        self.hasPermission = hasPermission
        self.dependsOnAccessibility = dependsOnAccessibility
        self.description = "文本输入权限\(hasPermission ? "已授予" : "被拒绝")"
    }
}

/// 麦克风权限变更事件
struct MicrophonePermissionDidChangeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AudioState"
    let description: String
    
    let hasPermission: Bool
    let authorizationStatus: String
    
    init(hasPermission: Bool, authorizationStatus: String) {
        self.hasPermission = hasPermission
        self.authorizationStatus = authorizationStatus
        self.description = "麦克风权限\(hasPermission ? "已授予" : "被拒绝") (\(authorizationStatus))"
    }
}

// MARK: - Audio Events

/// 音频录制开始事件
struct AudioRecordingDidStartEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AudioState"
    let description: String = "音频录制已开始"
    
    let deviceInfo: AudioDeviceInfo
    let expectedDuration: TimeInterval?
    let recordingId: UUID
    
    init(deviceInfo: AudioDeviceInfo, expectedDuration: TimeInterval? = nil) {
        self.deviceInfo = deviceInfo
        self.expectedDuration = expectedDuration
        self.recordingId = UUID()
    }
}

/// 音频录制停止事件
struct AudioRecordingDidStopEvent: Event {
    let timestamp: Date = Date()
    let source: String = "AudioState"
    let description: String
    
    let actualDuration: TimeInterval
    let recordingId: UUID
    let reason: StopReason
    let wasSuccessful: Bool
    
    enum StopReason {
        case userRequested
        case endpointDetected
        case timeout
        case error
        case systemInterruption
    }
    
    init(actualDuration: TimeInterval, recordingId: UUID, reason: StopReason, wasSuccessful: Bool) {
        self.actualDuration = actualDuration
        self.recordingId = recordingId
        self.reason = reason
        self.wasSuccessful = wasSuccessful
        self.description = "音频录制已停止 (时长: \(String(format: "%.1f", actualDuration))s, 原因: \(reason))"
    }
}

// MARK: - Recognition Events

/// ASR 服务状态变更事件
struct ASRServiceStatusDidChangeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "RecognitionState"
    let description: String
    
    let isRunning: Bool
    let isInitialized: Bool
    let modelInfo: ModelInfo?
    let performanceMetrics: PerformanceMetrics?
    
    struct ModelInfo {
        let name: String
        let version: String
        let language: String
        let size: Int64 // 字节
    }
    
    struct PerformanceMetrics {
        let averageLatency: TimeInterval
        let cpuUsage: Double
        let memoryUsage: Int64
    }
    
    init(isRunning: Bool, isInitialized: Bool, modelInfo: ModelInfo? = nil, performanceMetrics: PerformanceMetrics? = nil) {
        self.isRunning = isRunning
        self.isInitialized = isInitialized
        self.modelInfo = modelInfo
        self.performanceMetrics = performanceMetrics
        self.description = "ASR服务状态: \(isRunning ? "运行中" : "已停止"), \(isInitialized ? "已初始化" : "未初始化")"
    }
}

/// ASR 服务初始化完成事件
struct ASRServiceDidInitializeEvent: Event {
    let timestamp: Date = Date()
    let source: String = "RecognitionState"
    let description: String = "ASR服务初始化完成"
    
    let initializationTime: TimeInterval
    let modelLoaded: Bool
    let configurationValid: Bool
    
    init(initializationTime: TimeInterval, modelLoaded: Bool, configurationValid: Bool) {
        self.initializationTime = initializationTime
        self.modelLoaded = modelLoaded
        self.configurationValid = configurationValid
    }
}

/// 语音识别结果更新事件
struct RecognitionResultDidUpdateEvent: Event {
    let timestamp: Date = Date()
    let source: String = "RecognitionState"
    let description: String
    
    let text: String
    let confidence: Double
    let isFinal: Bool
    let languageDetected: String?
    let processingTime: TimeInterval
    let entry: RecognitionEntry?
    
    init(text: String, confidence: Double, isFinal: Bool, languageDetected: String? = nil, processingTime: TimeInterval, entry: RecognitionEntry? = nil) {
        self.text = text
        self.confidence = confidence
        self.isFinal = isFinal
        self.languageDetected = languageDetected
        self.processingTime = processingTime
        self.entry = entry
        self.description = "\(isFinal ? "最终" : "部分")识别结果: \(text.prefix(50))\(text.count > 50 ? "..." : "")"
    }
}

/// 语音端点检测事件
struct SpeechEndpointDetectedEvent: Event {
    let timestamp: Date = Date()
    let source: String = "RecognitionState"
    let description: String = "检测到语音端点"
    
    let endpointType: EndpointType
    let confidence: Double
    let audioLevelAtDetection: Double
    
    enum EndpointType {
        case speechStart
        case speechEnd
        case silenceDetected
    }
    
    init(endpointType: EndpointType, confidence: Double, audioLevelAtDetection: Double) {
        self.endpointType = endpointType
        self.confidence = confidence
        self.audioLevelAtDetection = audioLevelAtDetection
    }
}

// MARK: - Keyboard Monitor Events

/// 键盘监听器启动事件
struct KeyboardMonitorDidStartEvent: Event {
    let timestamp: Date = Date()
    let source: String = "KeyboardMonitor"
    let description: String = "键盘监听器已启动"
    
    let monitoredKeys: [String]
    let isUserInitiated: Bool
    let permissionGranted: Bool
    
    init(monitoredKeys: [String], isUserInitiated: Bool, permissionGranted: Bool) {
        self.monitoredKeys = monitoredKeys
        self.isUserInitiated = isUserInitiated
        self.permissionGranted = permissionGranted
    }
}

/// 键盘监听器停止事件
struct KeyboardMonitorDidStopEvent: Event {
    let timestamp: Date = Date()
    let source: String = "KeyboardMonitor"
    let description: String
    
    let reason: StopReason
    let isUserInitiated: Bool
    let uptime: TimeInterval
    
    enum StopReason {
        case userRequested
        case permissionLost
        case systemError
        case applicationTerminating
    }
    
    init(reason: StopReason, isUserInitiated: Bool, uptime: TimeInterval) {
        self.reason = reason
        self.isUserInitiated = isUserInitiated
        self.uptime = uptime
        self.description = "键盘监听器已停止 (原因: \(reason), 运行时长: \(String(format: "%.1f", uptime))s)"
    }
}

/// 快捷键触发事件
struct HotkeyTriggeredEvent: Event {
    let timestamp: Date = Date()
    let source: String = "KeyboardMonitor"
    let description: String
    
    let keySequence: [String]
    let triggerCount: Int
    let timeSinceLastTrigger: TimeInterval?
    let action: HotkeyAction
    
    enum HotkeyAction {
        case startRecording
        case stopRecording
        case toggleRecording
        case showInterface
        case hideInterface
        case custom(String)
    }
    
    init(keySequence: [String], triggerCount: Int, timeSinceLastTrigger: TimeInterval?, action: HotkeyAction) {
        self.keySequence = keySequence
        self.triggerCount = triggerCount
        self.timeSinceLastTrigger = timeSinceLastTrigger
        self.action = action
        self.description = "快捷键触发: \(keySequence.joined(separator: "+"))"
    }
}

// MARK: - Configuration Events

/// 配置更新事件
struct ConfigurationDidUpdateEvent: Event {
    let timestamp: Date = Date()
    let source: String = "ConfigurationManager"
    let description: String
    
    let updatedCategories: [String]
    let changedKeys: [String]
    let isUserInitiated: Bool
    let validationPassed: Bool
    
    init(updatedCategories: [String], changedKeys: [String], isUserInitiated: Bool, validationPassed: Bool) {
        self.updatedCategories = updatedCategories
        self.changedKeys = changedKeys
        self.isUserInitiated = isUserInitiated
        self.validationPassed = validationPassed
        self.description = "配置已更新: \(updatedCategories.joined(separator: ", "))"
    }
}

/// 配置重置事件
struct ConfigurationDidResetEvent: Event {
    let timestamp: Date = Date()
    let source: String = "ConfigurationManager"
    let description: String = "配置已重置为默认值"
    
    let resetCategories: [String]
    let backupCreated: Bool
    let reason: ResetReason
    
    enum ResetReason {
        case userRequested
        case corruptedConfig
        case migrationFailed
        case errorRecovery
    }
    
    init(resetCategories: [String], backupCreated: Bool, reason: ResetReason) {
        self.resetCategories = resetCategories
        self.backupCreated = backupCreated
        self.reason = reason
    }
}

// MARK: - Error Handling Events

/// 错误发生事件
struct ErrorDidOccurEvent: Event {
    let timestamp: Date = Date()
    let source: String = "ErrorHandler"
    let description: String
    
    let errorRecord: ErrorHandler.ErrorRecord
    let isRecoverable: Bool
    let affectedComponents: [String]
    
    init(errorRecord: ErrorHandler.ErrorRecord, isRecoverable: Bool, affectedComponents: [String]) {
        self.errorRecord = errorRecord
        self.isRecoverable = isRecoverable
        self.affectedComponents = affectedComponents
        self.description = "错误发生: \(errorRecord.error.localizedDescription)"
    }
}

/// 错误恢复请求事件
struct ErrorRecoveryRequestedEvent: Event {
    let timestamp: Date = Date()
    let source: String = "ErrorHandler"
    let description: String
    
    let errorId: UUID
    let recoveryStrategy: ErrorHandler.RecoveryStrategy
    let component: String
    let operation: String
    let attemptNumber: Int
    
    init(errorId: UUID, recoveryStrategy: ErrorHandler.RecoveryStrategy, component: String, operation: String, attemptNumber: Int) {
        self.errorId = errorId
        self.recoveryStrategy = recoveryStrategy
        self.component = component
        self.operation = operation
        self.attemptNumber = attemptNumber
        self.description = "错误恢复请求: \(component).\(operation) (策略: \(recoveryStrategy), 尝试: \(attemptNumber))"
    }
}

/// 用户操作需求事件
struct UserActionRequiredEvent: Event {
    let timestamp: Date = Date()
    let source: String = "ErrorHandler"
    let description: String
    
    let errorRecord: ErrorHandler.ErrorRecord
    let requiredActions: [UserAction]
    let urgency: Urgency
    let timeoutAfter: TimeInterval?
    
    enum UserAction {
        case grantPermission(String)
        case installDependency(String)
        case updateConfiguration(String)
        case restartApplication
        case contactSupport
        case ignoreProblem
    }
    
    enum Urgency {
        case low
        case medium
        case high
        case critical
    }
    
    init(errorRecord: ErrorHandler.ErrorRecord, requiredActions: [UserAction], urgency: Urgency, timeoutAfter: TimeInterval? = nil) {
        self.errorRecord = errorRecord
        self.requiredActions = requiredActions
        self.urgency = urgency
        self.timeoutAfter = timeoutAfter
        self.description = "需要用户操作: \(errorRecord.error.localizedDescription)"
    }
}

// MARK: - Service Lifecycle Events

/// 服务启动事件
struct ServiceDidStartEvent: Event {
    let timestamp: Date = Date()
    let source: String
    let description: String
    
    let serviceName: String
    let version: String?
    let startupTime: TimeInterval
    let dependencies: [String]
    
    init(serviceName: String, version: String? = nil, startupTime: TimeInterval, dependencies: [String] = []) {
        self.serviceName = serviceName
        self.version = version
        self.startupTime = startupTime
        self.dependencies = dependencies
        self.source = serviceName
        self.description = "服务 \(serviceName) 已启动"
    }
}

/// 服务停止事件
struct ServiceDidStopEvent: Event {
    let timestamp: Date = Date()
    let source: String
    let description: String
    
    let serviceName: String
    let uptime: TimeInterval
    let reason: StopReason
    let cleanShutdown: Bool
    
    enum StopReason {
        case requested
        case error
        case dependency
        case system
    }
    
    init(serviceName: String, uptime: TimeInterval, reason: StopReason, cleanShutdown: Bool) {
        self.serviceName = serviceName
        self.uptime = uptime
        self.reason = reason
        self.cleanShutdown = cleanShutdown
        self.source = serviceName
        self.description = "服务 \(serviceName) 已停止"
    }
}

// MARK: - Event Publishing Helpers

extension EventBus {
    
    /// 应用状态事件发布器
    struct AppStateEventPublisher {
        private let eventBus: EventBus
        
        init(eventBus: EventBus = .shared) {
            self.eventBus = eventBus
        }
        
        func publishInitializationComplete(
            initializationTime: TimeInterval,
            configurationLoaded: Bool,
            permissionsGranted: Bool
        ) {
            let event = AppInitializationDidCompleteEvent(
                initializationTime: initializationTime,
                configurationLoaded: configurationLoaded,
                permissionsGranted: permissionsGranted
            )
            eventBus.publish(event, priority: .high)
        }
        
        func publishStateChange(
            from oldState: AppRunningState,
            to newState: AppRunningState,
            reason: String? = nil
        ) {
            let event = AppRunningStateDidChangeEvent(
                oldState: oldState,
                newState: newState,
                reason: reason
            )
            eventBus.publish(event)
        }
        
        func publishError(
            _ error: AppError,
            context: [String: Any] = [:],
            severity: ErrorHandler.ErrorSeverity
        ) {
            let event = AppErrorDidOccurEvent(
                error: error,
                context: context,
                severity: severity
            )
            eventBus.publish(event, priority: severity == .critical ? .critical : .high)
        }
    }
    
    /// 获取应用状态事件发布器
    static var appState: AppStateEventPublisher {
        return AppStateEventPublisher()
    }
}

// MARK: - Event Type Registry

/// 事件类型注册表，用于运行时事件类型管理
class EventTypeRegistry {
    static let shared = EventTypeRegistry()
    
    private var registeredTypes: Set<String> = []
    
    private init() {
        registerBuiltInTypes()
    }
    
    private func registerBuiltInTypes() {
        register(AppInitializationDidCompleteEvent.self)
        register(AppRunningStateDidChangeEvent.self)
        register(AppErrorDidOccurEvent.self)
        register(AccessibilityPermissionDidChangeEvent.self)
        register(TextInputPermissionDidChangeEvent.self)
        register(MicrophonePermissionDidChangeEvent.self)
        register(AudioRecordingDidStartEvent.self)
        register(AudioRecordingDidStopEvent.self)
        register(ASRServiceStatusDidChangeEvent.self)
        register(ASRServiceDidInitializeEvent.self)
        register(RecognitionResultDidUpdateEvent.self)
        register(SpeechEndpointDetectedEvent.self)
        register(KeyboardMonitorDidStartEvent.self)
        register(KeyboardMonitorDidStopEvent.self)
        register(HotkeyTriggeredEvent.self)
        register(ConfigurationDidUpdateEvent.self)
        register(ConfigurationDidResetEvent.self)
        register(ErrorDidOccurEvent.self)
        register(ErrorRecoveryRequestedEvent.self)
        register(UserActionRequiredEvent.self)
        register(ServiceDidStartEvent.self)
        register(ServiceDidStopEvent.self)
    }
    
    func register<T: Event>(_ eventType: T.Type) {
        let typeName = String(describing: eventType)
        registeredTypes.insert(typeName)
    }
    
    func isRegistered<T: Event>(_ eventType: T.Type) -> Bool {
        let typeName = String(describing: eventType)
        return registeredTypes.contains(typeName)
    }
    
    var allRegisteredTypes: [String] {
        return Array(registeredTypes).sorted()
    }
}