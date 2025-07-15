import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var keyboardMonitor: KeyboardMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制设置应用为正常应用，确保在 Dock 中显示
        NSApp.setActivationPolicy(.regular)
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        
        // 初始化键盘监听器
        setupKeyboardMonitor()
        
        // 手动激活应用，确保 Dock 图标显示
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
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
        // 当最后一个窗口关闭时，不退出应用（继续在菜单栏中运行）
        return false
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
        print("📊 AppDelegate: 调用 RecordingState.shared.startRecording()")
        RecordingState.shared.startRecording()
        print("✅ AppDelegate: RecordingState.shared.startRecording() 已调用")
        // TODO: 在这里添加语音识别开始逻辑
        // 例如：speechRecognizer.startRecording()
    }
    
    private func stopRecording() {
        print("⏹️ AppDelegate: 结束语音识别...")
        print("📊 AppDelegate: 调用 RecordingState.shared.stopRecording()")
        RecordingState.shared.stopRecording()
        print("✅ AppDelegate: RecordingState.shared.stopRecording() 已调用")
        // TODO: 在这里添加语音识别结束逻辑
        // 例如：speechRecognizer.stopRecording()
    }
}