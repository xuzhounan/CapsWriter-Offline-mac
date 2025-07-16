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
        
        // 更新键盘监听器状态
        if hasAccessibilityPermission {
            updateKeyboardMonitorStatus("已启动")
        } else {
            updateKeyboardMonitorStatus("等待权限")
        }
    }
}