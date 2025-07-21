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
    
    /// 转录历史记录
    @Published var transcriptHistory: [TranscriptEntry] = []
    
    /// 当前部分转录文本
    @Published var partialTranscript: String = ""
    
    // MARK: - Private Properties
    
    // StateManager 通过 DIContainer 动态解析，避免循环依赖
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
        // StateManager 集成 - 已重新启用
        print("🔧 RecordingState: 设置StateManager状态绑定...")
        
        // TODO: 监听StateManager的音频状态变化（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     stateManager.$audioState
        //         .map(\.isRecording)
        //         .receive(on: DispatchQueue.main)
        //         .assign(to: \.isRecording, on: self)
        //         .store(in: &cancellables)
        //     
        //     print("✅ RecordingState: StateManager绑定已建立")
        // } else {
            print("⚠️ RecordingState: StateManager未注册，使用独立状态管理")
        // }
    }
    
    // MARK: - Public Methods
    
    /// 开始录音
    func startRecording() {
        print("📊 RecordingState: startRecording() 被调用")
        print("📊 RecordingState: 当前录音状态 = \(isRecording)")
        DispatchQueue.main.async {
            print("📊 RecordingState: 在主线程中设置 isRecording = true")
            self.isRecording = true
            self.recordingStartTime = Date()
            print("✅ RecordingState: 录音状态已更新为 \(self.isRecording)")
        }
    }
    
    /// 停止录音
    func stopRecording() {
        print("📊 RecordingState: stopRecording() 被调用")
        print("📊 RecordingState: 当前录音状态 = \(isRecording)")
        DispatchQueue.main.async {
            print("📊 RecordingState: 在主线程中设置 isRecording = false")
            self.isRecording = false
            self.recordingStartTime = nil
            print("✅ RecordingState: 录音状态已更新为 \(self.isRecording)")
        }
    }
    
    /// 录音时长
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 更新键盘监听器状态
    func updateKeyboardMonitorStatus(_ status: String) {
        DispatchQueue.main.async {
            self.keyboardMonitorStatus = status
        }
        // TODO: 同时通知 StateManager（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     Task { @MainActor in
        //         stateManager.updateKeyboardMonitorStatus(status)
        //     }
        // }
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
    
    /// 更新ASR服务状态
    func updateASRServiceStatus(_ isRunning: Bool) {
        DispatchQueue.main.async {
            self.isASRServiceRunning = isRunning
        }
        // TODO: 同时通知 StateManager（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     let status: RecognitionState.EngineStatus = isRunning ? .initializing : .uninitialized
        //     Task { @MainActor in
        //         stateManager.updateRecognitionEngineStatus(status)
        //     }
        // }
    }
    
    /// 更新音频采集服务状态
    func updateAudioCaptureServiceStatus(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.isAudioCaptureServiceReady = isReady
        }
        // TODO: 同时通知 StateManager（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     Task { @MainActor in
        //         // 更新音频采集服务状态
        //         stateManager.audioState.updateAudioCaptureServiceStatus(isReady)
        //     }
        // }
    }
    
    /// 更新ASR服务初始化状态
    func updateASRServiceInitialized(_ isInitialized: Bool) {
        DispatchQueue.main.async {
            self.isASRServiceInitialized = isInitialized
        }
        // TODO: 同时通知 StateManager（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     let status: RecognitionState.EngineStatus = isInitialized ? .ready : .uninitialized
        //     Task { @MainActor in
        //         stateManager.updateRecognitionEngineStatus(status)
        //     }
        // }
    }
    
    /// 更新初始化进度
    func updateInitializationProgress(_ progress: String) {
        DispatchQueue.main.async {
            self.initializationProgress = progress
        }
        // TODO: 同时通知 StateManager（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     if progress.contains("错误") || progress.contains("失败") {
        //         Task { @MainActor in
        //             stateManager.updateRecognitionEngineStatus(.error(progress))
        //         }
        //     }
        // }
    }
    
    /// 更新文本输入权限
    func updateTextInputPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasTextInputPermission = hasPermission
        }
    }
    
    /// 更新转录历史记录
    func updateTranscriptHistory(_ entries: [TranscriptEntry]) {
        DispatchQueue.main.async {
            self.transcriptHistory = entries
        }
    }
    
    /// 添加转录条目
    func addTranscriptEntry(_ entry: TranscriptEntry) {
        DispatchQueue.main.async {
            self.transcriptHistory.append(entry)
            
            // 保持历史记录不超过100条
            if self.transcriptHistory.count > 100 {
                self.transcriptHistory.removeFirst(self.transcriptHistory.count - 100)
            }
        }
    }
    
    /// 更新部分转录文本
    func updatePartialTranscript(_ text: String) {
        DispatchQueue.main.async {
            self.partialTranscript = text
        }
    }
    
    /// 清空转录历史记录
    func clearTranscriptHistory() {
        DispatchQueue.main.async {
            self.transcriptHistory.removeAll()
            self.partialTranscript = ""
        }
    }
    
    /// 刷新权限状态
    func refreshPermissionStatus() {
        // 直接检查权限状态并更新（绕过StateManager）
        print("🔄 RecordingState: 开始刷新权限状态...")
        
        // 检查辅助功能权限
        let accessibilityPermission = KeyboardMonitor.checkAccessibilityPermission()
        updateAccessibilityPermission(accessibilityPermission)
        print("🔐 RecordingState: 辅助功能权限 = \(accessibilityPermission)")
        
        // 检查麦克风权限 - 修复逻辑：包含 notDetermined 和 authorized 状态
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let microphonePermission = (microphoneAuthStatus == .authorized || microphoneAuthStatus == .notDetermined)
        updateMicrophonePermission(microphonePermission)
        
        // 打印详细状态信息
        print("🎤 RecordingState: 麦克风权限状态原始值 = \(microphoneAuthStatus.rawValue)")
        print("🎤 RecordingState: 麦克风权限状态描述 = \(getMicrophoneStatusDescription(microphoneAuthStatus))")
        print("🎤 RecordingState: 麦克风权限 = \(microphonePermission)")
        
        // 检查文本输入权限（与辅助功能权限相同）
        updateTextInputPermission(accessibilityPermission)
        print("📝 RecordingState: 文本输入权限 = \(accessibilityPermission)")
        
        // TODO: 同时通知 StateManager 更新权限（暂时禁用直到StateManager在项目中）
        // if let stateManager = try? DIContainer.shared.resolve(StateManager.self) {
        //     Task { @MainActor in
        //         stateManager.updatePermissions()
        //     }
        // }
        
        // 保持键盘监听器状态逻辑的兼容性
        let hasAccessibilityPermission = accessibilityPermission
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
    
    /// 获取麦克风权限状态描述
    private func getMicrophoneStatusDescription(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未确定（可以使用）"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已授权"
        @unknown default:
            return "未知状态"
        }
    }
}