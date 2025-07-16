import SwiftUI
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var keyboardMonitor: KeyboardMonitor?
    var asrService: SherpaASRService?
    var audioCaptureService: AudioCaptureService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 禁用窗口恢复功能
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        
        // 强制设置应用为正常应用，确保在 Dock 中显示
        NSApp.setActivationPolicy(.regular)
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        
        // 初始化语音识别服务
        setupASRService()
        
        // 初始化键盘监听器
        setupKeyboardMonitor()
        
        // 手动激活应用，确保 Dock 图标显示
        NSApp.activate(ignoringOtherApps: true)
        
        // 调试：检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.debugPermissionStatus()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        audioCaptureService?.stopCapture()
        audioCaptureService = nil
        asrService?.stopService()
        asrService = nil
        keyboardMonitor?.stopMonitoring()
        keyboardMonitor = nil
        statusBarController = nil
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户在 Dock 中点击应用图标时，如果没有可见窗口，则显示主窗口
        if !flag {
            statusBarController?.openMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭最后一个窗口时不退出应用，保持状态栏图标
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - 语音识别服务设置
    private func setupASRService() {
        print("🚀 初始化语音服务...")
        
        // 初始化纯识别服务（不涉及麦克风）
        initializeASRService()
        
        // 初始化音频采集服务（负责麦克风权限）
        initializeAudioCaptureService()
    }
    
    private func initializeASRService() {
        print("🧠 初始化ASR识别服务...")
        asrService = SherpaASRService()
        
        // 设置识别结果回调
        asrService?.delegate = self
        
        // 启动纯识别服务
        asrService?.startService()
        
        // 更新UI状态
        RecordingState.shared.updateASRServiceStatus(asrService?.isServiceRunning ?? false)
        
        print("✅ 语音识别服务已启动（纯识别模式）")
    }
    
    private func initializeAudioCaptureService() {
        print("🎤 初始化音频采集服务...")
        audioCaptureService = AudioCaptureService()
        
        // 设置音频采集回调
        audioCaptureService?.delegate = self
        
        // 更新UI状态
        RecordingState.shared.updateAudioCaptureServiceStatus(true)
        
        print("✅ 音频采集服务已初始化")
    }
    
    // MARK: - 键盘监听器设置
    private func setupKeyboardMonitor() {
        keyboardMonitor = KeyboardMonitor()
        
        // 初始权限检查和状态更新
        let hasPermission = KeyboardMonitor.checkAccessibilityPermission()
        RecordingState.shared.updateAccessibilityPermission(hasPermission)
        
        if hasPermission {
            RecordingState.shared.updateKeyboardMonitorStatus("初始化中...")
        } else {
            RecordingState.shared.updateKeyboardMonitorStatus("等待权限")
        }
        
        // 设置回调函数
        print("📞 设置键盘监听器回调函数...")
        keyboardMonitor?.setCallbacks(
            startRecording: { [weak self] in
                print("🎤 键盘监听器触发: 开始录音回调")
                self?.startRecording()
            },
            stopRecording: { [weak self] in
                print("⏹️ 键盘监听器触发: 停止录音回调")
                self?.stopRecording()
            }
        )
        print("✅ 键盘监听器回调函数已设置")
        
        // 启动监听
        print("🚀 启动键盘监听器...")
        keyboardMonitor?.startMonitoring()
        print("📡 键盘监听器启动调用完成")
    }
    
    // MARK: - 语音识别回调
    private func startRecording() {
        print("🎤 AppDelegate: 开始录音...")
        
        // 更新UI状态
        RecordingState.shared.startRecording()
        
        // 开始音频采集（会自动请求权限）
        audioCaptureService?.requestPermissionAndStartCapture()
        
        // 开始语音识别处理
        asrService?.startRecognition()
        
        print("✅ AppDelegate: 录音流程已启动")
    }
    
    private func stopRecording() {
        print("⏹️ AppDelegate: 结束录音...")
        
        // 停止音频采集
        audioCaptureService?.stopCapture()
        
        // 停止语音识别处理
        asrService?.stopRecognition()
        
        // 更新UI状态
        RecordingState.shared.stopRecording()
        
        print("✅ AppDelegate: 录音流程已停止")
    }
    
    // MARK: - 调试方法
    private func debugPermissionStatus() {
        print("🔍 === 权限状态调试 ===")
        
        // 检查辅助功能权限
        let hasAccessibilityPermission = KeyboardMonitor.checkAccessibilityPermission()
        print("🔐 辅助功能权限: \(hasAccessibilityPermission ? "✅ 已授权" : "❌ 未授权")")
        
        // 检查麦克风权限
        let micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 麦克风权限: \(micPermission == .authorized ? "✅ 已授权" : "❌ 未授权 (\(micPermission.rawValue))")")
        
        // 检查音频采集服务状态
        if let audioCapture = audioCaptureService {
            print("🎤 音频采集服务: 已创建，权限状态: \(audioCapture.hasPermission ? "✅ 已授权" : "❌ 未授权")")
            // 更新UI状态
            RecordingState.shared.updateMicrophonePermission(audioCapture.hasPermission)
        } else {
            print("🎤 音频采集服务: ❌ 未创建")
        }
        
        // 检查键盘监听器状态
        if let monitor = keyboardMonitor {
            print("⌨️ 键盘监听器: 已创建")
        } else {
            print("⌨️ 键盘监听器: ❌ 未创建")
        }
        
        // 检查ASR服务状态
        if let asr = asrService {
            print("🧠 ASR服务: 已创建，运行状态: \(asr.isServiceRunning ? "✅ 运行中" : "❌ 未运行")")
        } else {
            print("🧠 ASR服务: ❌ 未创建")
        }
        
        print("🔍 === 调试完成 ===")
        
        // 如果没有辅助功能权限，提示用户
        if !hasAccessibilityPermission {
            print("⚠️ 请前往 系统设置 → 隐私与安全性 → 辅助功能，添加 CapsWriter-mac")
        }
    }
}

// MARK: - AudioCaptureDelegate

extension AppDelegate: AudioCaptureDelegate {
    func audioCaptureDidReceiveBuffer(_ buffer: AVAudioPCMBuffer) {
        // 将音频数据转发给语音识别服务
        asrService?.processAudioBuffer(buffer)
    }
    
    func audioCaptureDidStart() {
        print("✅ 音频采集已开始")
        // 确保在主线程更新UI状态
        DispatchQueue.main.async {
            RecordingState.shared.updateMicrophonePermission(true)
        }
    }
    
    func audioCaptureDidStop() {
        print("⏹️ 音频采集已停止")
    }
    
    func audioCaptureDidFailWithError(_ error: Error) {
        print("❌ 音频采集失败: \(error.localizedDescription)")
        // 确保在主线程停止录音状态
        DispatchQueue.main.async {
            RecordingState.shared.stopRecording()
            RecordingState.shared.updateMicrophonePermission(false)
        }
    }
}

// MARK: - SpeechRecognitionDelegate

extension AppDelegate: SpeechRecognitionDelegate {
    func speechRecognitionDidReceivePartialResult(_ text: String) {
        print("📝 部分识别结果: \(text)")
    }
    
    func speechRecognitionDidReceiveFinalResult(_ text: String) {
        print("✅ 最终识别结果: \(text)")
    }
    
    func speechRecognitionDidDetectEndpoint() {
        print("🔚 检测到语音端点")
    }
}