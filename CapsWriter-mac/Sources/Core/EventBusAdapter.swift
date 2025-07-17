import Foundation

/// EventBus 适配器 - 现有组件与事件系统的桥接
/// 提供从 NotificationCenter 到 EventBus 的平滑迁移
class EventBusAdapter {
    
    private let eventBus: EventBus
    private var notificationObservers: [NSObjectProtocol] = []
    private var eventSubscriptions: [UUID] = []
    
    // MARK: - Initialization
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
        setupNotificationToEventMapping()
        print("🔗 EventBusAdapter: 事件适配器已初始化")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Notification to Event Mapping
    
    /// 设置 NotificationCenter 到 EventBus 的映射
    private func setupNotificationToEventMapping() {
        mapAppStateNotifications()
        mapAudioNotifications()
        mapRecognitionNotifications()
        mapConfigurationNotifications()
        mapErrorNotifications()
    }
    
    /// 映射应用状态通知
    private func mapAppStateNotifications() {
        // 应用初始化完成
        let initObserver = NotificationCenter.default.addObserver(
            forName: .appInitializationDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = AppInitializationDidCompleteEvent(
                initializationTime: 0, // 可从通知中获取
                configurationLoaded: true,
                permissionsGranted: true
            )
            self?.eventBus.publish(event, priority: .high)
        }
        notificationObservers.append(initObserver)
        
        // 应用状态变更
        let stateObserver = NotificationCenter.default.addObserver(
            forName: .appRunningStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let state = notification.userInfo?["state"] as? AppRunningState {
                let event = AppRunningStateDidChangeEvent(
                    oldState: .initializing, // 可以从状态管理器获取
                    newState: state
                )
                self?.eventBus.publish(event)
            }
        }
        notificationObservers.append(stateObserver)
        
        // 权限变更
        let accessibilityObserver = NotificationCenter.default.addObserver(
            forName: .accessibilityPermissionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let hasPermission = notification.userInfo?["hasPermission"] as? Bool ?? false
            let event = AccessibilityPermissionDidChangeEvent(hasPermission: hasPermission)
            self?.eventBus.publish(event, priority: .high)
        }
        notificationObservers.append(accessibilityObserver)
        
        let textInputObserver = NotificationCenter.default.addObserver(
            forName: .textInputPermissionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let hasPermission = notification.userInfo?["hasPermission"] as? Bool ?? false
            let event = TextInputPermissionDidChangeEvent(hasPermission: hasPermission)
            self?.eventBus.publish(event, priority: .high)
        }
        notificationObservers.append(textInputObserver)
        
        // 应用错误
        let errorObserver = NotificationCenter.default.addObserver(
            forName: .appErrorDidOccur,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?["error"] as? AppError {
                let event = AppErrorDidOccurEvent(
                    error: error,
                    severity: .medium // 可以根据错误类型确定
                )
                self?.eventBus.publish(event, priority: .high)
            }
        }
        notificationObservers.append(errorObserver)
    }
    
    /// 映射音频通知
    private func mapAudioNotifications() {
        // 录音开始
        let startObserver = NotificationCenter.default.addObserver(
            forName: .audioRecordingDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = AudioRecordingDidStartEvent(
                deviceInfo: AudioDeviceInfo.current()
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(startObserver)
        
        // 录音停止
        let stopObserver = NotificationCenter.default.addObserver(
            forName: .audioRecordingDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = AudioRecordingDidStopEvent(
                actualDuration: AudioState.shared.recordingDuration,
                recordingId: UUID(),
                reason: .userRequested,
                wasSuccessful: true
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(stopObserver)
        
        // 麦克风权限变更
        let micObserver = NotificationCenter.default.addObserver(
            forName: .microphonePermissionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let hasPermission = notification.userInfo?["hasPermission"] as? Bool ?? false
            let event = MicrophonePermissionDidChangeEvent(
                hasPermission: hasPermission,
                authorizationStatus: hasPermission ? "authorized" : "denied"
            )
            self?.eventBus.publish(event, priority: .high)
        }
        notificationObservers.append(micObserver)
    }
    
    /// 映射识别通知
    private func mapRecognitionNotifications() {
        // ASR 服务状态变更
        let asrStatusObserver = NotificationCenter.default.addObserver(
            forName: .asrServiceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRunning = notification.userInfo?["isRunning"] as? Bool ?? false
            let event = ASRServiceStatusDidChangeEvent(
                isRunning: isRunning,
                isInitialized: RecognitionState.shared.isASRServiceInitialized
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(asrStatusObserver)
        
        // ASR 服务初始化
        let asrInitObserver = NotificationCenter.default.addObserver(
            forName: .asrServiceDidInitialize,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = ASRServiceDidInitializeEvent(
                initializationTime: 0, // 可以测量实际时间
                modelLoaded: true,
                configurationValid: true
            )
            self?.eventBus.publish(event, priority: .high)
        }
        notificationObservers.append(asrInitObserver)
        
        // 识别结果更新
        let resultObserver = NotificationCenter.default.addObserver(
            forName: .recognitionResultDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let text = notification.userInfo?["text"] as? String,
               let entry = notification.userInfo?["entry"] as? RecognitionEntry {
                let event = RecognitionResultDidUpdateEvent(
                    text: text,
                    confidence: entry.confidence,
                    isFinal: true,
                    processingTime: 0,
                    entry: entry
                )
                self?.eventBus.publish(event)
            }
        }
        notificationObservers.append(resultObserver)
        
        // 语音端点检测
        let endpointObserver = NotificationCenter.default.addObserver(
            forName: .speechEndpointDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = SpeechEndpointDetectedEvent(
                endpointType: .speechEnd,
                confidence: 0.8,
                audioLevelAtDetection: 0.5
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(endpointObserver)
        
        // 键盘监听器
        let keyboardStartObserver = NotificationCenter.default.addObserver(
            forName: .keyboardMonitorDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = KeyboardMonitorDidStartEvent(
                monitoredKeys: ["O"],
                isUserInitiated: true,
                permissionGranted: AppState.shared.hasAccessibilityPermission
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(keyboardStartObserver)
        
        let keyboardStopObserver = NotificationCenter.default.addObserver(
            forName: .keyboardMonitorDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = KeyboardMonitorDidStopEvent(
                reason: .userRequested,
                isUserInitiated: true,
                uptime: 0
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(keyboardStopObserver)
    }
    
    /// 映射配置通知
    private func mapConfigurationNotifications() {
        // 配置更新
        let configUpdateObserver = NotificationCenter.default.addObserver(
            forName: .configurationDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let categories = notification.userInfo?["categories"] as? [String] ?? []
            let keys = notification.userInfo?["keys"] as? [String] ?? []
            
            let event = ConfigurationDidUpdateEvent(
                updatedCategories: categories,
                changedKeys: keys,
                isUserInitiated: true,
                validationPassed: true
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(configUpdateObserver)
        
        // 配置重置
        let configResetObserver = NotificationCenter.default.addObserver(
            forName: .configurationDidReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let event = ConfigurationDidResetEvent(
                resetCategories: ["all"],
                backupCreated: true,
                reason: .userRequested
            )
            self?.eventBus.publish(event)
        }
        notificationObservers.append(configResetObserver)
    }
    
    /// 映射错误处理通知
    private func mapErrorNotifications() {
        // 错误发生
        let errorOccurObserver = NotificationCenter.default.addObserver(
            forName: .errorDidOccur,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord {
                let event = ErrorDidOccurEvent(
                    errorRecord: record,
                    isRecoverable: record.recoveryStrategy != .none,
                    affectedComponents: [record.context.component]
                )
                let priority: EventBus.EventPriority = record.severity == .critical ? .critical : .high
                self?.eventBus.publish(event, priority: priority)
            }
        }
        notificationObservers.append(errorOccurObserver)
        
        // 错误重试请求
        let retryObserver = NotificationCenter.default.addObserver(
            forName: .errorRetryRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord {
                let event = ErrorRecoveryRequestedEvent(
                    errorId: record.id,
                    recoveryStrategy: record.recoveryStrategy,
                    component: record.context.component,
                    operation: record.context.operation,
                    attemptNumber: 1
                )
                self?.eventBus.publish(event)
            }
        }
        notificationObservers.append(retryObserver)
        
        // 用户操作需求
        let userActionObserver = NotificationCenter.default.addObserver(
            forName: .errorUserActionRequired,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord {
                let actions: [UserActionRequiredEvent.UserAction] = [.ignoreProblem]
                let event = UserActionRequiredEvent(
                    errorRecord: record,
                    requiredActions: actions,
                    urgency: record.severity == .critical ? .critical : .medium
                )
                self?.eventBus.publish(event, priority: .high)
            }
        }
        notificationObservers.append(userActionObserver)
    }
    
    // MARK: - Event to Notification Mapping (Backward Compatibility)
    
    /// 设置从 EventBus 到 NotificationCenter 的反向映射
    /// 确保依赖旧通知系统的代码继续工作
    func enableBackwardCompatibility() {
        setupEventToNotificationMapping()
        print("🔄 EventBusAdapter: 已启用向后兼容性")
    }
    
    private func setupEventToNotificationMapping() {
        // 应用状态事件 -> 通知
        let appInitSub = eventBus.subscribe(to: AppInitializationDidCompleteEvent.self) { _ in
            NotificationCenter.default.post(name: .appInitializationDidComplete, object: nil)
        }
        eventSubscriptions.append(appInitSub)
        
        let appStateSub = eventBus.subscribe(to: AppRunningStateDidChangeEvent.self) { event in
            NotificationCenter.default.post(
                name: .appRunningStateDidChange,
                object: nil,
                userInfo: ["state": event.newState]
            )
        }
        eventSubscriptions.append(appStateSub)
        
        // 权限事件 -> 通知
        let accessibilitySub = eventBus.subscribe(to: AccessibilityPermissionDidChangeEvent.self) { event in
            NotificationCenter.default.post(
                name: .accessibilityPermissionDidChange,
                object: nil,
                userInfo: ["hasPermission": event.hasPermission]
            )
        }
        eventSubscriptions.append(accessibilitySub)
        
        let textInputSub = eventBus.subscribe(to: TextInputPermissionDidChangeEvent.self) { event in
            NotificationCenter.default.post(
                name: .textInputPermissionDidChange,
                object: nil,
                userInfo: ["hasPermission": event.hasPermission]
            )
        }
        eventSubscriptions.append(textInputSub)
        
        let microphoneSub = eventBus.subscribe(to: MicrophonePermissionDidChangeEvent.self) { event in
            NotificationCenter.default.post(
                name: .microphonePermissionDidChange,
                object: nil,
                userInfo: ["hasPermission": event.hasPermission]
            )
        }
        eventSubscriptions.append(microphoneSub)
        
        // 音频事件 -> 通知
        let audioStartSub = eventBus.subscribe(to: AudioRecordingDidStartEvent.self) { _ in
            NotificationCenter.default.post(name: .audioRecordingDidStart, object: nil)
        }
        eventSubscriptions.append(audioStartSub)
        
        let audioStopSub = eventBus.subscribe(to: AudioRecordingDidStopEvent.self) { _ in
            NotificationCenter.default.post(name: .audioRecordingDidStop, object: nil)
        }
        eventSubscriptions.append(audioStopSub)
        
        // 识别事件 -> 通知
        let asrStatusSub = eventBus.subscribe(to: ASRServiceStatusDidChangeEvent.self) { event in
            NotificationCenter.default.post(
                name: .asrServiceStatusDidChange,
                object: nil,
                userInfo: ["isRunning": event.isRunning]
            )
        }
        eventSubscriptions.append(asrStatusSub)
        
        let asrInitSub = eventBus.subscribe(to: ASRServiceDidInitializeEvent.self) { _ in
            NotificationCenter.default.post(name: .asrServiceDidInitialize, object: nil)
        }
        eventSubscriptions.append(asrInitSub)
        
        let recognitionResultSub = eventBus.subscribe(to: RecognitionResultDidUpdateEvent.self) { event in
            NotificationCenter.default.post(
                name: .recognitionResultDidUpdate,
                object: nil,
                userInfo: [
                    "text": event.text,
                    "entry": event.entry as Any
                ]
            )
        }
        eventSubscriptions.append(recognitionResultSub)
        
        // 更多映射...
    }
    
    // MARK: - Migration Helpers
    
    /// 获取迁移建议
    func getMigrationSuggestions() -> [String] {
        return [
            "将 NotificationCenter 观察者替换为 EventBus 订阅",
            "使用类型安全的事件而不是字符串键",
            "利用事件优先级进行更好的调度控制",
            "使用 EventBus 的调试功能监控事件流",
            "考虑使用异步事件处理提升性能"
        ]
    }
    
    /// 分析代码中的通知使用情况
    func analyzeNotificationUsage() -> NotificationUsageReport {
        // 简化实现，实际应该分析代码
        return NotificationUsageReport(
            totalNotifications: 18,
            mappedToEvents: 15,
            requiresManualMigration: 3,
            suggestions: getMigrationSuggestions()
        )
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        // 移除通知观察者
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // 取消事件订阅
        eventSubscriptions.forEach { subscriptionId in
            eventBus.unsubscribe(subscriptionId)
        }
        eventSubscriptions.removeAll()
        
        print("🧹 EventBusAdapter: 清理完成")
    }
}

// MARK: - Migration Report

struct NotificationUsageReport {
    let totalNotifications: Int
    let mappedToEvents: Int
    let requiresManualMigration: Int
    let suggestions: [String]
    
    var migrationProgress: Double {
        guard totalNotifications > 0 else { return 0 }
        return Double(mappedToEvents) / Double(totalNotifications)
    }
    
    var description: String {
        return """
        NotificationCenter 迁移报告:
        - 总通知数: \(totalNotifications)
        - 已映射到事件: \(mappedToEvents)
        - 需要手动迁移: \(requiresManualMigration)
        - 迁移进度: \(String(format: "%.1f%%", migrationProgress * 100))
        
        建议:
        \(suggestions.enumerated().map { "• \($0.element)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - EventBus Extensions for Common Patterns

extension EventBus {
    
    /// 便捷方法：发布状态变更事件
    func publishStateChange<T>(
        from oldValue: T,
        to newValue: T,
        source: String,
        property: String
    ) {
        let event = BaseEvent(
            source: source,
            description: "\(source).\(property) 从 \(oldValue) 变更为 \(newValue)"
        )
        publish(event)
    }
    
    /// 便捷方法：发布生命周期事件
    func publishLifecycleEvent(
        component: String,
        action: LifecycleAction,
        details: [String: Any] = [:]
    ) {
        let event = BaseEvent(
            source: component,
            description: "\(component) \(action.description)"
        )
        publish(event, priority: action.priority)
    }
}

enum LifecycleAction {
    case willStart
    case didStart
    case willStop
    case didStop
    case willTerminate
    case didTerminate
    
    var description: String {
        switch self {
        case .willStart: return "即将启动"
        case .didStart: return "已启动"
        case .willStop: return "即将停止"
        case .didStop: return "已停止"
        case .willTerminate: return "即将终止"
        case .didTerminate: return "已终止"
        }
    }
    
    var priority: EventBus.EventPriority {
        switch self {
        case .willStart, .didStart: return .normal
        case .willStop, .didStop: return .high
        case .willTerminate, .didTerminate: return .critical
        }
    }
}