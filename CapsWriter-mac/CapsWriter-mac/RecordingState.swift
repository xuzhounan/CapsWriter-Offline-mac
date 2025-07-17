import SwiftUI
import Combine
import AVFoundation

/// 录音状态管理器 - 兼容性包装器，委托给 StateManager
/// @deprecated 推荐直接使用 StateManager
class RecordingState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否正在录音
    @Published var isRecording: Bool = false
    
    /// 录音开始时间
    @Published var recordingStartTime: Date?
    
    /// 键盘监听器状态
    @Published var keyboardMonitorStatus: String = "未知"
    
    /// 辅助功能权限状态
    @Published var hasAccessibilityPermission: Bool = false
    
    /// 麦克风权限状态
    @Published var hasMicrophonePermission: Bool = false
    
    /// ASR 服务运行状态
    @Published var isASRServiceRunning: Bool = false
    
    /// 音频采集服务就绪状态
    @Published var isAudioCaptureServiceReady: Bool = false
    
    /// ASR 服务初始化状态
    @Published var isASRServiceInitialized: Bool = false
    
    /// 初始化进度
    @Published var initializationProgress: String = "正在启动..."
    
    /// 文本输入权限状态
    @Published var hasTextInputPermission: Bool = false
    
    // MARK: - Private Properties
    
    private let stateManager = StateManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 用户手动停止标志（保持向后兼容）
    private let stateQueue = DispatchQueue(label: "com.capswriter.recording-state", attributes: .concurrent)
    private var _isManuallyStoppedByUser: Bool = false
    
    private var isManuallyStoppedByUser: Bool {
        get {
            stateQueue.sync { _isManuallyStoppedByUser }
        }
        set {
            stateQueue.async(flags: .barrier) { [weak self] in
                self?._isManuallyStoppedByUser = newValue
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = RecordingState()
    
    // MARK: - Initialization
    
    private init() {
        setupStateBindings()
    }
    
    // MARK: - State Binding
    
    private func setupStateBindings() {
        // 绑定音频录制状态
        stateManager.audioState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
                if isRecording {
                    self?.recordingStartTime = Date()
                } else {
                    self?.recordingStartTime = nil
                }
            }
            .store(in: &cancellables)
        
        // 绑定权限状态
        stateManager.appState.$permissions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] permissions in
                self?.hasAccessibilityPermission = permissions.accessibility.isGranted
                self?.hasMicrophonePermission = permissions.microphone.isGranted
                self?.hasTextInputPermission = permissions.accessibility.isGranted // 文本输入需要辅助功能权限
            }
            .store(in: &cancellables)
        
        // 绑定识别引擎状态
        stateManager.recognitionState.$engineStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] engineStatus in
                self?.isASRServiceInitialized = engineStatus.isReady
                self?.isASRServiceRunning = { 
                    if case .initializing = engineStatus { return true }
                    return false
                }()
                self?.initializationProgress = {
                    switch engineStatus {
                    case .uninitialized: return "未初始化"
                    case .initializing: return "正在初始化..."
                    case .ready: return "已就绪"
                    case .error(let message): return "错误: \(message)"
                    }
                }()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 开始录音 - 委托给 StateManager
    func startRecording() {
        print("📊 RecordingState: startRecording() 被调用（委托给 StateManager）")
        Task { @MainActor in
            stateManager.startRecording()
        }
    }
    
    /// 停止录音 - 委托给 StateManager
    func stopRecording() {
        print("📊 RecordingState: stopRecording() 被调用（委托给 StateManager）")
        Task { @MainActor in
            stateManager.stopRecording()
        }
    }
    
    /// 录音时长 - 使用 StateManager 中的音频状态
    var recordingDuration: TimeInterval {
        return stateManager.audioState.recordingDuration
    }
    
    /// 更新键盘监听器状态
    func updateKeyboardMonitorStatus(_ status: String) {
        DispatchQueue.main.async {
            self.keyboardMonitorStatus = status
        }
        // 同时通知 StateManager
        stateManager.updateKeyboardMonitorStatus(status)
    }
    
    /// 用户手动启动监听器
    func userStartedKeyboardMonitor() {
        isManuallyStoppedByUser = false
        updateKeyboardMonitorStatus("已启动")
    }
    
    /// 用户手动停止监听器
    func userStoppedKeyboardMonitor() {
        isManuallyStoppedByUser = true
        updateKeyboardMonitorStatus("已停止")
    }
    
    /// 更新辅助功能权限 - 同步到 StateManager
    func updateAccessibilityPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = hasPermission
        }
        // 注意：状态绑定会自动同步，这里保持兼容性
    }
    
    /// 更新麦克风权限 - 同步到 StateManager
    func updateMicrophonePermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasMicrophonePermission = hasPermission
        }
        // 注意：状态绑定会自动同步，这里保持兼容性
    }
    
    /// 更新ASR服务状态 - 委托给 StateManager
    func updateASRServiceStatus(_ isRunning: Bool) {
        let status: RecognitionState.EngineStatus = isRunning ? .initializing : .uninitialized
        Task { @MainActor in
            stateManager.updateRecognitionEngineStatus(status)
        }
    }
    
    /// 更新音频采集服务状态
    func updateAudioCaptureServiceStatus(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.isAudioCaptureServiceReady = isReady
        }
        // 更新音频设备状态
        let deviceStatus: AudioState.AudioDeviceStatus = isReady ? .available : .unavailable
        Task { @MainActor in
            stateManager.audioState.updateDeviceStatus(deviceStatus)
        }
    }
    
    /// 更新ASR服务初始化状态 - 委托给 StateManager
    func updateASRServiceInitialized(_ isInitialized: Bool) {
        let status: RecognitionState.EngineStatus = isInitialized ? .ready : .uninitialized
        Task { @MainActor in
            stateManager.updateRecognitionEngineStatus(status)
        }
    }
    
    /// 更新初始化进度 - 委托给 StateManager
    func updateInitializationProgress(_ progress: String) {
        DispatchQueue.main.async {
            self.initializationProgress = progress
        }
        // 如果进度包含错误信息，更新引擎状态
        if progress.contains("错误") || progress.contains("失败") {
            Task { @MainActor in
                stateManager.updateRecognitionEngineStatus(.error(progress))
            }
        }
    }
    
    /// 更新文本输入权限
    func updateTextInputPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasTextInputPermission = hasPermission
        }
    }
    
    /// 刷新权限状态 - 委托给 StateManager
    func refreshPermissionStatus() {
        Task { @MainActor in
            stateManager.updatePermissions()
        }
        
        // 保持键盘监听器状态逻辑的兼容性
        let hasAccessibilityPermission = hasAccessibilityPermission
        if !hasAccessibilityPermission {
            updateKeyboardMonitorStatus("等待权限")
            isManuallyStoppedByUser = false
        } else {
            if keyboardMonitorStatus == "等待权限" || keyboardMonitorStatus == "未知" {
                updateKeyboardMonitorStatus("已停止")
                isManuallyStoppedByUser = true
            } else if (keyboardMonitorStatus == "已启动" || keyboardMonitorStatus == "正在监听") && isManuallyStoppedByUser {
                updateKeyboardMonitorStatus("已停止")
            }
        }
    }
}