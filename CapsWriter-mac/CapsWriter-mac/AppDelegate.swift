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
        keyboardMonitor?.setCallbacks(
            startRecording: { [weak self] in
                self?.startRecording()
            },
            stopRecording: { [weak self] in
                self?.stopRecording()
            }
        )
        
        // 启动监听
        keyboardMonitor?.startMonitoring()
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
}