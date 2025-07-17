//
//  AppState.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-17.
//

import Foundation
import Combine

/// 应用程序整体状态管理
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 应用运行状态
    @Published var appStatus: AppStatus = .launching
    
    /// 当前活跃的功能模式
    @Published var activeMode: AppMode = .voiceInput
    
    /// 权限状态
    @Published var permissions: PermissionStatus = PermissionStatus()
    
    /// 网络连接状态
    @Published var networkStatus: NetworkStatus = .unknown
    
    /// 应用设置状态
    @Published var isSettingsVisible: Bool = false
    
    /// 关于页面状态
    @Published var isAboutVisible: Bool = false
    
    /// 错误信息显示
    @Published var errorMessage: String? = nil
    
    /// 通知信息显示
    @Published var notificationMessage: String? = nil
    
    /// 应用性能信息
    @Published var performanceInfo: PerformanceInfo = PerformanceInfo()
    
    // MARK: - Enums
    
    enum AppStatus {
        case launching
        case initializing
        case ready
        case error(String)
        case shuttingDown
        
        var description: String {
            switch self {
            case .launching: return "启动中"
            case .initializing: return "初始化中"
            case .ready: return "就绪"
            case .error(let message): return "错误: \(message)"
            case .shuttingDown: return "关闭中"
            }
        }
        
        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    enum AppMode {
        case voiceInput      // 语音输入模式
        case fileTranscription // 文件转录模式
        case settings        // 设置模式
        
        var title: String {
            switch self {
            case .voiceInput: return "语音输入"
            case .fileTranscription: return "文件转录"
            case .settings: return "设置"
            }
        }
        
        var icon: String {
            switch self {
            case .voiceInput: return "mic.fill"
            case .fileTranscription: return "doc.text.fill"
            case .settings: return "gear"
            }
        }
    }
    
    enum NetworkStatus {
        case unknown
        case connected
        case disconnected
        case limited
        
        var description: String {
            switch self {
            case .unknown: return "网络状态未知"
            case .connected: return "网络已连接"
            case .disconnected: return "网络已断开"
            case .limited: return "网络受限"
            }
        }
    }
    
    // MARK: - Data Models
    
    struct PermissionStatus {
        var microphone: PermissionState = .notDetermined
        var accessibility: PermissionState = .notDetermined
        var fileAccess: PermissionState = .notDetermined
        
        enum PermissionState {
            case notDetermined
            case granted
            case denied
            case restricted
            
            var description: String {
                switch self {
                case .notDetermined: return "未确定"
                case .granted: return "已授权"
                case .denied: return "已拒绝"
                case .restricted: return "受限制"
                }
            }
            
            var isGranted: Bool {
                return self == .granted
            }
        }
        
        var allGranted: Bool {
            return microphone.isGranted && accessibility.isGranted && fileAccess.isGranted
        }
        
        var hasRequiredPermissions: Bool {
            // 麦克风权限是必需的，其他可选
            return microphone.isGranted
        }
    }
    
    struct PerformanceInfo {
        var memoryUsage: Double = 0.0      // MB
        var cpuUsage: Double = 0.0         // 百分比
        var lastUpdateTime: Date = Date()
        
        var memoryUsageDescription: String {
            return String(format: "%.1f MB", memoryUsage)
        }
        
        var cpuUsageDescription: String {
            return String(format: "%.1f%%", cpuUsage)
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var errorTimer: Timer?
    private var notificationTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupErrorHandling()
    }
    
    // MARK: - Public Methods
    
    /// 更新应用状态
    func updateAppStatus(_ status: AppStatus) {
        appStatus = status
    }
    
    /// 切换应用模式
    func switchMode(to mode: AppMode) {
        activeMode = mode
        
        // 根据模式调整界面状态
        if mode != .settings {
            isSettingsVisible = false
        }
    }
    
    /// 更新权限状态
    func updatePermission(_ permission: KeyPath<PermissionStatus, PermissionStatus.PermissionState>, 
                         state: PermissionStatus.PermissionState) {
        switch permission {
        case \PermissionStatus.microphone:
            permissions.microphone = state
        case \PermissionStatus.accessibility:
            permissions.accessibility = state
        case \PermissionStatus.fileAccess:
            permissions.fileAccess = state
        default:
            break
        }
    }
    
    /// 更新网络状态
    func updateNetworkStatus(_ status: NetworkStatus) {
        networkStatus = status
    }
    
    /// 显示错误信息
    func showError(_ message: String, duration: TimeInterval = 5.0) {
        errorMessage = message
        
        // 自动清除错误信息
        errorTimer?.invalidate()
        errorTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearError()
            }
        }
    }
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
        errorTimer?.invalidate()
        errorTimer = nil
    }
    
    /// 显示通知信息
    func showNotification(_ message: String, duration: TimeInterval = 3.0) {
        notificationMessage = message
        
        // 自动清除通知信息
        notificationTimer?.invalidate()
        notificationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearNotification()
            }
        }
    }
    
    /// 清除通知信息
    func clearNotification() {
        notificationMessage = nil
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
    
    /// 更新性能信息
    func updatePerformanceInfo(memoryUsage: Double, cpuUsage: Double) {
        performanceInfo.memoryUsage = memoryUsage
        performanceInfo.cpuUsage = cpuUsage
        performanceInfo.lastUpdateTime = Date()
    }
    
    /// 显示设置界面
    func showSettings() {
        isSettingsVisible = true
        activeMode = .settings
    }
    
    /// 隐藏设置界面
    func hideSettings() {
        isSettingsVisible = false
        if activeMode == .settings {
            activeMode = .voiceInput
        }
    }
    
    /// 显示关于页面
    func showAbout() {
        isAboutVisible = true
    }
    
    /// 隐藏关于页面
    func hideAbout() {
        isAboutVisible = false
    }
    
    /// 准备关闭应用
    func prepareShutdown() {
        appStatus = .shuttingDown
        clearError()
        clearNotification()
    }
    
    /// 重置应用状态
    func reset() {
        appStatus = .ready
        activeMode = .voiceInput
        clearError()
        clearNotification()
        isSettingsVisible = false
        isAboutVisible = false
    }
    
    // MARK: - Private Methods
    
    private func setupErrorHandling() {
        // 监听应用状态变化
        $appStatus
            .sink { [weak self] status in
                if case .error(let message) = status {
                    self?.showError(message)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Extensions

extension AppState {
    
    /// 获取状态指示器颜色
    var statusIndicatorColor: String {
        switch appStatus {
        case .launching, .initializing:
            return "yellow"
        case .ready:
            return "green"
        case .error:
            return "red"
        case .shuttingDown:
            return "gray"
        }
    }
    
    /// 检查是否可以使用应用功能
    var canUseApp: Bool {
        return appStatus.isReady && permissions.hasRequiredPermissions
    }
    
    /// 获取应用状态摘要
    var statusSummary: String {
        var summary = appStatus.description
        
        if !permissions.hasRequiredPermissions {
            summary += " (权限不足)"
        }
        
        if networkStatus == .disconnected {
            summary += " (网络断开)"
        }
        
        return summary
    }
    
    /// 获取权限状态摘要
    var permissionSummary: String {
        return """
        麦克风: \(permissions.microphone.description)
        辅助功能: \(permissions.accessibility.description)
        文件访问: \(permissions.fileAccess.description)
        """
    }
}