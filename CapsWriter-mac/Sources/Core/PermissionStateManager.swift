//
//  PermissionStateManager.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-18.
//

import Foundation
import Combine
import AVFoundation
import ApplicationServices

/// 权限类型枚举
enum PermissionType: String, CaseIterable {
    case microphone = "microphone"
    case accessibility = "accessibility"
    case textInput = "textInput"
    
    var displayName: String {
        switch self {
        case .microphone: return "麦克风"
        case .accessibility: return "辅助功能"
        case .textInput: return "文本输入"
        }
    }
}

/// 权限状态枚举
enum PermissionStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case restricted
    
    var description: String {
        switch self {
        case .notDetermined: return "未确定"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        case .restricted: return "受限制"
        }
    }
    
    var isGranted: Bool {
        return self == .authorized
    }
}

/// 响应式权限状态管理器
/// 使用系统通知和回调机制替代轮询，提供实时权限状态监控
@MainActor
class PermissionStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 各权限状态的 Publisher
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var textInputStatus: PermissionStatus = .notDetermined
    
    /// 权限变化事件 Publisher
    @Published var lastPermissionChange: (PermissionType, PermissionStatus)?
    
    // MARK: - Combine Publishers
    
    /// 麦克风权限状态流
    lazy var microphoneStatusPublisher: AnyPublisher<PermissionStatus, Never> = {
        $microphoneStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
    
    /// 辅助功能权限状态流
    lazy var accessibilityStatusPublisher: AnyPublisher<PermissionStatus, Never> = {
        $accessibilityStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
    
    /// 文本输入权限状态流
    lazy var textInputStatusPublisher: AnyPublisher<PermissionStatus, Never> = {
        $textInputStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
    
    /// 所有权限状态合并流
    lazy var allPermissionsPublisher: AnyPublisher<[PermissionType: PermissionStatus], Never> = {
        Publishers.CombineLatest3(
            microphoneStatusPublisher,
            accessibilityStatusPublisher,
            textInputStatusPublisher
        )
        .map { mic, accessibility, textInput in
            [
                .microphone: mic,
                .accessibility: accessibility,
                .textInput: textInput
            ]
        }
        .eraseToAnyPublisher()
    }()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let permissionQueue = DispatchQueue(label: "com.capswriter.permission-manager", qos: .userInitiated)
    
    // 应用生命周期监听
    private var applicationDidBecomeActiveObserver: NSObjectProtocol?
    private var applicationWillResignActiveObserver: NSObjectProtocol?
    
    // 权限检查计时器（仅在特殊情况下使用）
    private var emergencyPermissionCheckTimer: Timer?
    
    // MARK: - Singleton
    
    static let shared = PermissionStateManager()
    
    private init() {
        print("🔐 PermissionStateManager 初始化")
        setupSystemNotificationMonitoring()
        performInitialPermissionCheck()
    }
    
    // MARK: - Public Interface
    
    /// 获取指定权限的当前状态
    func getPermissionStatus(_ type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:
            return microphoneStatus
        case .accessibility:
            return accessibilityStatus
        case .textInput:
            return textInputStatus
        }
    }
    
    /// 请求指定权限
    func requestPermission(_ type: PermissionType) async -> PermissionStatus {
        print("🔐 请求权限: \(type.displayName)")
        
        switch type {
        case .microphone:
            return await requestMicrophonePermission()
        case .accessibility:
            return await requestAccessibilityPermission()
        case .textInput:
            return await requestTextInputPermission()
        }
    }
    
    /// 检查所有权限是否已授权
    func areAllPermissionsGranted() -> Bool {
        return microphoneStatus.isGranted && 
               accessibilityStatus.isGranted && 
               textInputStatus.isGranted
    }
    
    /// 检查关键权限是否已授权（麦克风权限必需）
    func areRequiredPermissionsGranted() -> Bool {
        return microphoneStatus.isGranted
    }
    
    /// 手动刷新所有权限状态（用于特殊情况）
    func refreshAllPermissions() {
        print("🔄 手动刷新所有权限状态")
        performPermissionCheck()
    }
    
    /// 监听特定权限状态变化
    func observePermission(_ type: PermissionType, handler: @escaping (PermissionStatus) -> Void) -> AnyCancellable {
        switch type {
        case .microphone:
            return microphoneStatusPublisher.sink(receiveValue: handler)
        case .accessibility:
            return accessibilityStatusPublisher.sink(receiveValue: handler)
        case .textInput:
            return textInputStatusPublisher.sink(receiveValue: handler)
        }
    }
    
    // MARK: - System Notification Monitoring
    
    private func setupSystemNotificationMonitoring() {
        print("🔔 设置系统通知监听")
        
        // 监听应用前台/后台切换
        applicationDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 应用进入前台，检查权限状态")
            self?.handleApplicationDidBecomeActive()
        }
        
        applicationWillResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 应用进入后台")
            self?.handleApplicationWillResignActive()
        }
        
        // 监听音频会话中断通知
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
            .store(in: &cancellables)
        
        // 监听音频路由变化通知
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permission Checking Methods
    
    private func performInitialPermissionCheck() {
        print("🔍 执行初始权限检查")
        performPermissionCheck()
    }
    
    private func performPermissionCheck() {
        permissionQueue.async { [weak self] in
            self?.checkMicrophonePermissionAsync()
            self?.checkAccessibilityPermissionAsync()
            self?.checkTextInputPermissionAsync()
        }
    }
    
    private func checkMicrophonePermissionAsync() {
        let status: PermissionStatus
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            status = .authorized
        case .denied:
            status = .denied
        case .undetermined:
            status = .notDetermined
        @unknown default:
            status = .notDetermined
        }
        
        Task { @MainActor in
            updatePermissionStatus(.microphone, status: status)
        }
    }
    
    private func checkAccessibilityPermissionAsync() {
        let trusted = AXIsProcessTrusted()
        let status: PermissionStatus = trusted ? .authorized : .denied
        
        Task { @MainActor in
            updatePermissionStatus(.accessibility, status: status)
        }
    }
    
    private func checkTextInputPermissionAsync() {
        // 文本输入权限通常与辅助功能权限相关
        // 这里可以根据具体需求实现更精确的检查
        let status: PermissionStatus = accessibilityStatus
        
        Task { @MainActor in
            updatePermissionStatus(.textInput, status: status)
        }
    }
    
    // MARK: - Permission Request Methods
    
    private func requestMicrophonePermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: .authorized)
            case .denied:
                continuation.resume(returning: .denied)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    let status: PermissionStatus = granted ? .authorized : .denied
                    Task { @MainActor in
                        self.updatePermissionStatus(.microphone, status: status)
                    }
                    continuation.resume(returning: status)
                }
            @unknown default:
                continuation.resume(returning: .denied)
            }
        }
    }
    
    private func requestAccessibilityPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            if AXIsProcessTrusted() {
                continuation.resume(returning: .authorized)
                return
            }
            
            // 显示权限请求对话框
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            
            let status: PermissionStatus = trusted ? .authorized : .denied
            
            Task { @MainActor in
                self.updatePermissionStatus(.accessibility, status: status)
            }
            
            continuation.resume(returning: status)
        }
    }
    
    private func requestTextInputPermission() async -> PermissionStatus {
        // 文本输入权限通常依赖于辅助功能权限
        let accessibilityStatus = await requestAccessibilityPermission()
        
        Task { @MainActor in
            updatePermissionStatus(.textInput, status: accessibilityStatus)
        }
        
        return accessibilityStatus
    }
    
    // MARK: - State Update Methods
    
    private func updatePermissionStatus(_ type: PermissionType, status: PermissionStatus) {
        let oldStatus = getPermissionStatus(type)
        
        switch type {
        case .microphone:
            microphoneStatus = status
        case .accessibility:
            accessibilityStatus = status
        case .textInput:
            textInputStatus = status
        }
        
        // 记录权限变化
        if oldStatus != status {
            lastPermissionChange = (type, status)
            print("🔄 权限状态变化: \(type.displayName) \(oldStatus.description) → \(status.description)")
            
            // 发布权限变化事件
            publishPermissionChangeEvent(type: type, oldStatus: oldStatus, newStatus: status)
        }
    }
    
    private func publishPermissionChangeEvent(type: PermissionType, oldStatus: PermissionStatus, newStatus: PermissionStatus) {
        // 如果有事件总线，可以在此发布权限变化事件
        // EventBus.shared.publish(PermissionChangeEvent(type: type, oldStatus: oldStatus, newStatus: newStatus))
        
        // 特殊情况处理
        if type == .microphone && newStatus == .denied && oldStatus == .authorized {
            print("⚠️ 麦克风权限被撤销！")
            // 可以触发停止录音等操作
        }
        
        if type == .accessibility && newStatus == .denied && oldStatus == .authorized {
            print("⚠️ 辅助功能权限被撤销！")
            // 可以触发停止键盘监听等操作
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleApplicationDidBecomeActive() {
        // 应用进入前台时检查权限状态
        print("🔍 应用前台激活，检查权限状态")
        
        // 延迟一段时间执行检查，确保系统状态稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performPermissionCheck()
        }
    }
    
    private func handleApplicationWillResignActive() {
        // 应用进入后台时停止可能的紧急权限检查
        stopEmergencyPermissionCheck()
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        print("🎵 音频会话中断通知，检查麦克风权限")
        
        // 音频会话中断可能影响麦克风权限，需要重新检查
        permissionQueue.async { [weak self] in
            self?.checkMicrophonePermissionAsync()
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        print("🎵 音频路由变化通知")
        
        // 音频路由变化可能影响麦克风可用性
        permissionQueue.async { [weak self] in
            self?.checkMicrophonePermissionAsync()
        }
    }
    
    // MARK: - Emergency Permission Check (备用机制)
    
    /// 启动紧急权限检查计时器（仅在系统通知失效时使用）
    private func startEmergencyPermissionCheck() {
        stopEmergencyPermissionCheck()
        
        print("⚠️ 启动紧急权限检查计时器")
        emergencyPermissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            print("⏰ 紧急权限检查")
            self?.performPermissionCheck()
        }
    }
    
    /// 停止紧急权限检查计时器
    private func stopEmergencyPermissionCheck() {
        emergencyPermissionCheckTimer?.invalidate()
        emergencyPermissionCheckTimer = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopEmergencyPermissionCheck()
        
        if let observer = applicationDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let observer = applicationWillResignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("🧹 PermissionStateManager 已清理")
    }
}

// MARK: - Extensions

extension PermissionStateManager {
    
    /// 获取权限状态摘要
    var permissionSummary: String {
        return """
        权限状态摘要:
        - 麦克风: \(microphoneStatus.description)
        - 辅助功能: \(accessibilityStatus.description)
        - 文本输入: \(textInputStatus.description)
        """
    }
    
    /// 获取权限状态字典
    var permissionStatusDict: [PermissionType: PermissionStatus] {
        return [
            .microphone: microphoneStatus,
            .accessibility: accessibilityStatus,
            .textInput: textInputStatus
        ]
    }
    
    /// 检查是否有任何权限被拒绝
    var hasAnyDeniedPermissions: Bool {
        return microphoneStatus == .denied || 
               accessibilityStatus == .denied || 
               textInputStatus == .denied
    }
    
    /// 检查是否有任何权限未确定
    var hasAnyUndeterminedPermissions: Bool {
        return microphoneStatus == .notDetermined || 
               accessibilityStatus == .notDetermined || 
               textInputStatus == .notDetermined
    }
}