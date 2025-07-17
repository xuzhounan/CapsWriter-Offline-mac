import SwiftUI
import Combine
import AVFoundation

/// 应用级状态管理
/// 负责管理权限状态、初始化进度和应用整体状态
class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 应用初始化进度
    @Published var initializationProgress: String = "正在启动..."
    
    /// 应用初始化是否完成
    @Published var isInitializationComplete: Bool = false
    
    /// 辅助功能权限状态
    @Published var hasAccessibilityPermission: Bool = false
    
    /// 文本输入权限状态
    @Published var hasTextInputPermission: Bool = false
    
    /// 应用整体运行状态
    @Published var appRunningState: AppRunningState = .initializing
    
    /// 权限检查状态
    @Published var permissionCheckStatus: PermissionCheckStatus = .checking
    
    /// 错误信息
    @Published var lastError: AppError?
    
    /// 应用配置是否已加载
    @Published var isConfigurationLoaded: Bool = false
    
    /// 是否显示主窗口
    @Published var shouldShowMainWindow: Bool = false
    
    /// 是否运行在后台模式
    @Published var isBackgroundMode: Bool = false
    
    // MARK: - Private Properties
    
    private let stateQueue = DispatchQueue(label: "com.capswriter.app-state", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    private var permissionCheckTimer: Timer?
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    private init() {
        setupPermissionMonitoring()
        updateInitializationProgress("应用状态管理器已启动")
    }
    
    // MARK: - Initialization Progress
    
    /// 更新初始化进度
    func updateInitializationProgress(_ progress: String) {
        DispatchQueue.main.async {
            self.initializationProgress = progress
        }
        
        print("🚀 AppState: \(progress)")
    }
    
    /// 标记初始化完成
    func markInitializationComplete() {
        DispatchQueue.main.async {
            self.isInitializationComplete = true
            self.appRunningState = .running
            self.updateInitializationProgress("应用启动完成")
        }
        
        // 发送初始化完成通知
        NotificationCenter.default.post(
            name: .appInitializationDidComplete,
            object: self
        )
    }
    
    /// 标记配置已加载
    func markConfigurationLoaded() {
        DispatchQueue.main.async {
            self.isConfigurationLoaded = true
        }
        
        updateInitializationProgress("配置已加载")
    }
    
    // MARK: - Permission Management
    
    /// 更新辅助功能权限状态
    func updateAccessibilityPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = hasPermission
        }
        
        // 发送权限状态变更通知
        NotificationCenter.default.post(
            name: .accessibilityPermissionDidChange,
            object: self,
            userInfo: ["hasPermission": hasPermission]
        )
        
        updatePermissionCheckStatus()
    }
    
    /// 更新文本输入权限状态
    func updateTextInputPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasTextInputPermission = hasPermission
        }
        
        // 发送权限状态变更通知
        NotificationCenter.default.post(
            name: .textInputPermissionDidChange,
            object: self,
            userInfo: ["hasPermission": hasPermission]
        )
        
        updatePermissionCheckStatus()
    }
    
    /// 刷新所有权限状态
    func refreshAllPermissions() {
        updateInitializationProgress("正在检查权限...")
        
        // 检查辅助功能权限
        let hasAccessibilityPermission = KeyboardMonitor.checkAccessibilityPermission()
        updateAccessibilityPermission(hasAccessibilityPermission)
        
        // 检查麦克风权限
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let hasMicrophonePermission = (microphoneStatus == .authorized)
        AudioState.shared.updateMicrophonePermission(hasMicrophonePermission)
        
        // 检查文本输入权限（依赖辅助功能权限）
        let hasTextInputPermission = TextInputService.shared.checkAccessibilityPermission()
        updateTextInputPermission(hasTextInputPermission)
        
        updateInitializationProgress("权限检查完成")
    }
    
    /// 更新权限检查状态
    private func updatePermissionCheckStatus() {
        let audioPermission = AudioState.shared.hasMicrophonePermission
        
        DispatchQueue.main.async {
            if self.hasAccessibilityPermission && audioPermission && self.hasTextInputPermission {
                self.permissionCheckStatus = .allGranted
            } else if !self.hasAccessibilityPermission || !audioPermission {
                self.permissionCheckStatus = .missingCritical
            } else {
                self.permissionCheckStatus = .partialGranted
            }
        }
    }
    
    /// 请求所有必要权限
    func requestAllPermissions() async {
        updateInitializationProgress("正在请求权限...")
        appRunningState = .requestingPermissions
        
        // 请求麦克风权限
        let microphoneGranted = await AudioState.shared.requestMicrophonePermission()
        
        // 请求辅助功能权限（需要用户手动授权）
        if !hasAccessibilityPermission {
            KeyboardMonitor.requestAccessibilityPermission()
        }
        
        // 等待一段时间让用户有机会授权
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒
        
        // 刷新权限状态
        refreshAllPermissions()
        
        if permissionCheckStatus == .allGranted {
            updateInitializationProgress("所有权限已获取")
        } else {
            updateInitializationProgress("部分权限待授权")
        }
    }
    
    // MARK: - App State Management
    
    /// 更新应用运行状态
    func updateAppRunningState(_ state: AppRunningState) {
        DispatchQueue.main.async {
            self.appRunningState = state
        }
        
        // 发送状态变更通知
        NotificationCenter.default.post(
            name: .appRunningStateDidChange,
            object: self,
            userInfo: ["state": state]
        )
    }
    
    /// 切换主窗口显示状态
    func toggleMainWindow() {
        DispatchQueue.main.async {
            self.shouldShowMainWindow.toggle()
        }
    }
    
    /// 设置后台模式
    func setBackgroundMode(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.isBackgroundMode = enabled
        }
        
        updateInitializationProgress(enabled ? "切换到后台模式" : "切换到前台模式")
    }
    
    // MARK: - Error Management
    
    /// 报告错误
    func reportError(_ error: AppError) {
        DispatchQueue.main.async {
            self.lastError = error
            self.appRunningState = .error
        }
        
        print("❌ AppState: 错误 - \(error.localizedDescription)")
        
        // 发送错误通知
        NotificationCenter.default.post(
            name: .appErrorDidOccur,
            object: self,
            userInfo: ["error": error]
        )
    }
    
    /// 清除错误状态
    func clearError() {
        DispatchQueue.main.async {
            self.lastError = nil
            if self.appRunningState == .error {
                self.appRunningState = .running
            }
        }
    }
    
    // MARK: - Permission Monitoring
    
    /// 设置权限监控
    private func setupPermissionMonitoring() {
        // 定期检查权限状态（每30秒）
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshAllPermissions()
        }
        
        // 监听应用激活事件，激活时检查权限
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAllPermissions()
        }
    }
    
    // MARK: - State Validation
    
    /// 检查应用是否准备就绪
    var isAppReady: Bool {
        return isInitializationComplete && 
               isConfigurationLoaded && 
               permissionCheckStatus != .missingCritical &&
               appRunningState == .running
    }
    
    /// 获取应用状态描述
    var appStatusDescription: String {
        switch appRunningState {
        case .initializing:
            return initializationProgress
        case .requestingPermissions:
            return "正在请求权限"
        case .running:
            return isAppReady ? "应用就绪" : "等待完成初始化"
        case .error:
            return lastError?.localizedDescription ?? "未知错误"
        case .terminating:
            return "应用正在退出"
        }
    }
    
    /// 获取权限状态描述
    var permissionStatusDescription: String {
        switch permissionCheckStatus {
        case .checking:
            return "正在检查权限"
        case .allGranted:
            return "所有权限已授权"
        case .partialGranted:
            return "部分权限已授权"
        case .missingCritical:
            return "缺少关键权限"
        }
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
}

// MARK: - App Running State

/// 应用运行状态
enum AppRunningState: String, CaseIterable {
    case initializing = "初始化中"
    case requestingPermissions = "请求权限中"
    case running = "运行中"
    case error = "错误状态"
    case terminating = "退出中"
}

// MARK: - Permission Check Status

/// 权限检查状态
enum PermissionCheckStatus: String, CaseIterable {
    case checking = "检查中"
    case allGranted = "全部授权"
    case partialGranted = "部分授权"
    case missingCritical = "缺少关键权限"
}

// MARK: - App Error

/// 应用错误类型
enum AppError: LocalizedError, Equatable {
    case configurationLoadFailed(String)
    case serviceInitializationFailed(String)
    case permissionDenied(String)
    case modelLoadFailed(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationLoadFailed(let message):
            return "配置加载失败: \(message)"
        case .serviceInitializationFailed(let message):
            return "服务初始化失败: \(message)"
        case .permissionDenied(let message):
            return "权限被拒绝: \(message)"
        case .modelLoadFailed(let message):
            return "模型加载失败: \(message)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appInitializationDidComplete = Notification.Name("appInitializationDidComplete")
    static let appRunningStateDidChange = Notification.Name("appRunningStateDidChange")
    static let accessibilityPermissionDidChange = Notification.Name("accessibilityPermissionDidChange")
    static let textInputPermissionDidChange = Notification.Name("textInputPermissionDidChange")
    static let appErrorDidOccur = Notification.Name("appErrorDidOccur")
}

// MARK: - Extensions

extension AppState {
    
    /// 调试信息
    var debugDescription: String {
        return """
        AppState Debug Info:
        - Running State: \(appRunningState.rawValue)
        - Initialization Complete: \(isInitializationComplete)
        - Configuration Loaded: \(isConfigurationLoaded)
        - Accessibility Permission: \(hasAccessibilityPermission)
        - Text Input Permission: \(hasTextInputPermission)
        - Permission Status: \(permissionCheckStatus.rawValue)
        - Background Mode: \(isBackgroundMode)
        - Last Error: \(lastError?.localizedDescription ?? "None")
        """
    }
    
    /// 重置所有状态
    func resetAllStates() {
        DispatchQueue.main.async {
            self.initializationProgress = "正在启动..."
            self.isInitializationComplete = false
            self.hasAccessibilityPermission = false
            self.hasTextInputPermission = false
            self.appRunningState = .initializing
            self.permissionCheckStatus = .checking
            self.lastError = nil
            self.isConfigurationLoaded = false
            self.shouldShowMainWindow = false
            self.isBackgroundMode = false
        }
        
        print("🔄 AppState: 所有状态已重置")
    }
}