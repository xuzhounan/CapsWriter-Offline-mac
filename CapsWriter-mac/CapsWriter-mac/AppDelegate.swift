import SwiftUI
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var keyboardMonitor: KeyboardMonitor?
    var asrService: SherpaASRService?
    
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
        print("🚀 初始化语音识别服务...")
        
        // 先请求麦克风权限
        requestMicrophonePermission { [weak self] granted in
            if granted {
                print("✅ 麦克风权限已获得")
                DispatchQueue.main.async {
                    self?.initializeASRService()
                }
            } else {
                print("❌ 麦克风权限被拒绝")
            }
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("✅ 麦克风权限已授权")
            completion(true)
        case .notDetermined:
            print("🔍 请求麦克风权限...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "✅ 用户授予了麦克风权限" : "❌ 用户拒绝了麦克风权限")
                completion(granted)
            }
        case .denied, .restricted:
            print("❌ 麦克风权限被拒绝或受限")
            completion(false)
        @unknown default:
            print("❓ 未知麦克风权限状态")
            completion(false)
        }
    }
    
    private func initializeASRService() {
        print("🔧 初始化ASR服务实例...")
        asrService = SherpaASRService()
        
        // 启动服务，让它随时准备识别
        asrService?.startService()
        print("✅ 语音识别服务已启动，随时准备检测语音")
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
        print("🎤 AppDelegate: 开始语音识别...")
        
        // 更新状态
        RecordingState.shared.startRecording()
        
        // 开始实际的语音识别
        asrService?.startRecognition()
        
        print("✅ AppDelegate: 语音识别已启动")
    }
    
    private func stopRecording() {
        print("⏹️ AppDelegate: 结束语音识别...")
        
        // 停止实际的语音识别
        asrService?.stopRecognition()
        
        // 更新状态
        RecordingState.shared.stopRecording()
        
        print("✅ AppDelegate: 语音识别已停止")
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