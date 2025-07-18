//
//  PermissionMonitorService.swift
//  CapsWriter-mac
//
//  Created by CapsWriter on 2025-07-18.
//

import Foundation
import Combine

/// 权限监控服务协议
protocol PermissionMonitorServiceProtocol {
    /// 初始化服务
    func initialize() throws
    
    /// 启动服务
    func start()
    
    /// 停止服务
    func stop()
    
    /// 清理服务
    func cleanup()
    
    /// 检查是否可以开始录音
    func canStartRecording() -> Bool
    
    /// 检查是否可以进行文本输入
    func canInputText() -> Bool
    
    /// 请求所有必需权限
    func requestRequiredPermissions() async -> Bool
    
    /// 权限状态变化回调
    var permissionChangeHandler: ((PermissionType, PermissionStatus) -> Void)? { get set }
}

/// 权限监控服务
/// 封装 PermissionStateManager，提供业务层面的权限检查和管理
class PermissionMonitorService: ObservableObject, PermissionMonitorServiceProtocol {
    
    // MARK: - Published Properties
    
    /// 服务运行状态
    @Published var isRunning: Bool = false
    
    /// 服务初始化状态
    @Published var isInitialized: Bool = false
    
    /// 权限监控状态
    @Published var monitoringStatus: MonitoringStatus = .stopped
    
    /// 最后的权限检查时间
    @Published var lastPermissionCheckTime: Date?
    
    // MARK: - Types
    
    enum MonitoringStatus {
        case stopped
        case starting
        case running
        case error(String)
        
        var description: String {
            switch self {
            case .stopped: return "已停止"
            case .starting: return "启动中"
            case .running: return "运行中"
            case .error(let message): return "错误: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let permissionManager = PermissionStateManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let serviceQueue = DispatchQueue(label: "com.capswriter.permission-monitor", qos: .userInitiated)
    
    /// 权限状态变化回调
    var permissionChangeHandler: ((PermissionType, PermissionStatus) -> Void)?
    
    // MARK: - Computed Properties
    
    /// 麦克风权限状态
    var microphonePermissionStatus: PermissionStatus {
        permissionManager.microphoneStatus
    }
    
    /// 辅助功能权限状态
    var accessibilityPermissionStatus: PermissionStatus {
        permissionManager.accessibilityStatus
    }
    
    /// 文本输入权限状态
    var textInputPermissionStatus: PermissionStatus {
        permissionManager.textInputStatus
    }
    
    /// 是否拥有麦克风权限
    var hasMicrophonePermission: Bool {
        permissionManager.microphoneStatus.isGranted
    }
    
    /// 是否拥有辅助功能权限
    var hasAccessibilityPermission: Bool {
        permissionManager.accessibilityStatus.isGranted
    }
    
    /// 是否拥有文本输入权限
    var hasTextInputPermission: Bool {
        permissionManager.textInputStatus.isGranted
    }
    
    /// 是否拥有所有必需权限
    var hasRequiredPermissions: Bool {
        permissionManager.areRequiredPermissionsGranted()
    }
    
    /// 是否拥有所有权限
    var hasAllPermissions: Bool {
        permissionManager.areAllPermissionsGranted()
    }
    
    // MARK: - Initialization
    
    init() {
        print("🔐 PermissionMonitorService 初始化")
    }
    
    // MARK: - ServiceProtocol Implementation
    
    func initialize() throws {
        print("🔧 PermissionMonitorService: 开始初始化")
        
        guard !isInitialized else {
            print("⚠️ PermissionMonitorService 已经初始化")
            return
        }
        
        do {
            setupPermissionObservers()
            isInitialized = true
            print("✅ PermissionMonitorService: 初始化完成")
        } catch {
            print("❌ PermissionMonitorService: 初始化失败 - \(error)")
            throw error
        }
    }
    
    func start() {
        print("🚀 PermissionMonitorService: 启动服务")
        
        guard isInitialized else {
            print("❌ PermissionMonitorService: 服务未初始化，无法启动")
            monitoringStatus = .error("服务未初始化")
            return
        }
        
        guard !isRunning else {
            print("⚠️ PermissionMonitorService: 服务已在运行")
            return
        }
        
        monitoringStatus = .starting
        
        serviceQueue.async { [weak self] in
            Task { @MainActor in
                self?.performServiceStart()
            }
        }
    }
    
    func stop() {
        print("⏹️ PermissionMonitorService: 停止服务")
        
        guard isRunning else {
            print("⚠️ PermissionMonitorService: 服务未在运行")
            return
        }
        
        isRunning = false
        monitoringStatus = .stopped
        
        print("✅ PermissionMonitorService: 服务已停止")
    }
    
    func cleanup() {
        print("🧹 PermissionMonitorService: 清理服务")
        
        stop()
        cancellables.removeAll()
        isInitialized = false
        permissionChangeHandler = nil
        
        print("✅ PermissionMonitorService: 清理完成")
    }
    
    // MARK: - Permission Checking Methods
    
    func canStartRecording() -> Bool {
        let canRecord = hasMicrophonePermission && hasAccessibilityPermission
        
        if !canRecord {
            print("❌ 无法开始录音:")
            if !hasMicrophonePermission {
                print("  - 缺少麦克风权限")
            }
            if !hasAccessibilityPermission {
                print("  - 缺少辅助功能权限")
            }
        }
        
        return canRecord
    }
    
    func canInputText() -> Bool {
        let canInput = hasTextInputPermission
        
        if !canInput {
            print("❌ 无法进行文本输入: 缺少文本输入权限")
        }
        
        return canInput
    }
    
    func requestRequiredPermissions() async -> Bool {
        print("🔐 请求必需权限")
        
        // 请求麦克风权限
        let microphoneStatus = await permissionManager.requestPermission(.microphone)
        print("🎤 麦克风权限请求结果: \(microphoneStatus.description)")
        
        // 请求辅助功能权限
        let accessibilityStatus = await permissionManager.requestPermission(.accessibility)
        print("🔐 辅助功能权限请求结果: \(accessibilityStatus.description)")
        
        // 请求文本输入权限
        let textInputStatus = await permissionManager.requestPermission(.textInput)
        print("📝 文本输入权限请求结果: \(textInputStatus.description)")
        
        let hasAllRequired = microphoneStatus.isGranted && accessibilityStatus.isGranted
        
        if hasAllRequired {
            print("✅ 所有必需权限已获得")
        } else {
            print("❌ 部分必需权限未获得")
        }
        
        return hasAllRequired
    }
    
    // MARK: - Private Methods
    
    private func setupPermissionObservers() {
        print("🔔 设置权限状态观察者")
        
        // 观察麦克风权限变化
        permissionManager.observePermission(.microphone) { [weak self] status in
            Task { @MainActor in
                self?.handlePermissionChange(.microphone, status: status)
            }
        }
        .store(in: &cancellables)
        
        // 观察辅助功能权限变化
        permissionManager.observePermission(.accessibility) { [weak self] status in
            Task { @MainActor in
                self?.handlePermissionChange(.accessibility, status: status)
            }
        }
        .store(in: &cancellables)
        
        // 观察文本输入权限变化
        permissionManager.observePermission(.textInput) { [weak self] status in
            Task { @MainActor in
                self?.handlePermissionChange(.textInput, status: status)
            }
        }
        .store(in: &cancellables)
        
        // 观察所有权限状态变化
        permissionManager.allPermissionsPublisher
            .sink { [weak self] permissionsDict in
                Task { @MainActor in
                    self?.handleAllPermissionsUpdate(permissionsDict)
                }
            }
            .store(in: &cancellables)
    }
    
    private func performServiceStart() {
        // 执行初始权限检查
        permissionManager.refreshAllPermissions()
        lastPermissionCheckTime = Date()
        
        isRunning = true
        monitoringStatus = .running
        
        print("✅ PermissionMonitorService: 服务启动完成")
    }
    
    private func handlePermissionChange(_ type: PermissionType, status: PermissionStatus) {
        print("🔄 权限变化: \(type.displayName) → \(status.description)")
        
        // 更新最后检查时间
        lastPermissionCheckTime = Date()
        
        // 调用外部处理器
        permissionChangeHandler?(type, status)
        
        // 处理特殊权限变化
        handleSpecialPermissionChange(type, status: status)
    }
    
    private func handleSpecialPermissionChange(_ type: PermissionType, status: PermissionStatus) {
        switch (type, status) {
        case (.microphone, .denied):
            print("⚠️ 麦克风权限被拒绝或撤销")
            // 可以在这里触发停止录音等操作
            
        case (.accessibility, .denied):
            print("⚠️ 辅助功能权限被拒绝或撤销")
            // 可以在这里触发停止键盘监听等操作
            
        case (.microphone, .authorized):
            print("✅ 麦克风权限已授权")
            
        case (.accessibility, .authorized):
            print("✅ 辅助功能权限已授权")
            
        default:
            break
        }
    }
    
    private func handleAllPermissionsUpdate(_ permissionsDict: [PermissionType: PermissionStatus]) {
        let summary = permissionsDict.map { "\($0.key.displayName): \($0.value.description)" }
            .joined(separator: ", ")
        
        print("📊 权限状态更新: \(summary)")
        
        // 检查是否所有必需权限都已获得
        if hasRequiredPermissions {
            print("✅ 所有必需权限都已获得")
        } else {
            print("⚠️ 仍有必需权限未获得")
        }
    }
}

// MARK: - Extensions

extension PermissionMonitorService {
    
    /// 获取权限状态摘要
    var permissionStatusSummary: String {
        return permissionManager.permissionSummary
    }
    
    /// 获取服务状态摘要
    var serviceStatusSummary: String {
        var components: [String] = []
        
        components.append("服务状态: \(monitoringStatus.description)")
        components.append("运行状态: \(isRunning ? "运行中" : "已停止")")
        components.append("初始化: \(isInitialized ? "已完成" : "未完成")")
        
        if let lastCheck = lastPermissionCheckTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            components.append("最后检查: \(formatter.string(from: lastCheck))")
        }
        
        return components.joined(separator: " | ")
    }
    
    /// 获取未授权的权限列表
    var missingPermissions: [PermissionType] {
        return PermissionType.allCases.filter { type in
            !permissionManager.getPermissionStatus(type).isGranted
        }
    }
    
    /// 获取权限检查建议
    var permissionCheckSuggestion: String? {
        let missing = missingPermissions
        
        if missing.isEmpty {
            return nil
        }
        
        let missingNames = missing.map { $0.displayName }.joined(separator: "、")
        return "请检查以下权限: \(missingNames)"
    }
}