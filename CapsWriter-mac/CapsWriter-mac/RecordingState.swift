import SwiftUI
import Combine
import AVFoundation

class RecordingState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingStartTime: Date?
    @Published var keyboardMonitorStatus: String = "未知"
    @Published var hasAccessibilityPermission: Bool = false
    @Published var hasMicrophonePermission: Bool = false
    @Published var isASRServiceRunning: Bool = false
    @Published var isAudioCaptureServiceReady: Bool = false
    
    // 添加一个标志位来跟踪用户是否手动停止了监听
    // 使用队列保护以确保线程安全
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
    
    static let shared = RecordingState()
    
    private init() {}
    
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
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    func updateKeyboardMonitorStatus(_ status: String) {
        DispatchQueue.main.async {
            self.keyboardMonitorStatus = status
        }
    }
    
    // 用户手动启动监听器
    func userStartedKeyboardMonitor() {
        isManuallyStoppedByUser = false
        updateKeyboardMonitorStatus("已启动")
    }
    
    // 用户手动停止监听器
    func userStoppedKeyboardMonitor() {
        isManuallyStoppedByUser = true
        updateKeyboardMonitorStatus("已停止")
    }
    
    func updateAccessibilityPermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = hasPermission
        }
    }
    
    func updateMicrophonePermission(_ hasPermission: Bool) {
        DispatchQueue.main.async {
            self.hasMicrophonePermission = hasPermission
        }
    }
    
    func updateASRServiceStatus(_ isRunning: Bool) {
        DispatchQueue.main.async {
            self.isASRServiceRunning = isRunning
        }
    }
    
    func updateAudioCaptureServiceStatus(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.isAudioCaptureServiceReady = isReady
        }
    }
    
    func refreshPermissionStatus() {
        // 检查辅助功能权限
        let hasAccessibilityPermission = KeyboardMonitor.checkAccessibilityPermission()
        updateAccessibilityPermission(hasAccessibilityPermission)
        
        // 检查麦克风权限
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let hasMicrophonePermission = (microphoneStatus == .authorized)
        updateMicrophonePermission(hasMicrophonePermission)
        
        // 更新键盘监听器状态 - 只有在没有权限时才强制更新状态
        // 如果有权限且用户没有手动停止，则不要覆盖当前状态
        if !hasAccessibilityPermission {
            updateKeyboardMonitorStatus("等待权限")
            // 权限丢失时重置手动停止标志
            isManuallyStoppedByUser = false
        } else {
            // 有权限时，只有在状态是"等待权限"或"未知"时才自动设置为启动
            // 如果用户手动停止了，就保持停止状态
            if keyboardMonitorStatus == "等待权限" || keyboardMonitorStatus == "未知" {
                if !isManuallyStoppedByUser {
                    updateKeyboardMonitorStatus("已启动")
                }
            }
            // 如果当前是运行状态但用户手动停止了，应该保持停止状态
            else if (keyboardMonitorStatus == "已启动" || keyboardMonitorStatus == "正在监听") && isManuallyStoppedByUser {
                updateKeyboardMonitorStatus("已停止")
            }
        }
    }
}