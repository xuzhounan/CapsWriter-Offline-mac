import SwiftUI
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusBarController: StatusBarController?
    
    // 使用 VoiceInputController 替代直接服务管理
    private let voiceInputController = VoiceInputController.shared
    private let configManager = ConfigurationManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀🚀🚀 AppDelegate: applicationDidFinishLaunching 开始执行 🚀🚀🚀")
        
        // 禁用窗口恢复功能
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        
        // 设置应用为正常应用，可在需要时切换为代理模式
        NSApp.setActivationPolicy(.regular)
        
        // 立即初始化状态栏控制器（轻量级操作）
        statusBarController = StatusBarController()
        
        // 手动激活应用，确保 Dock 图标显示
        NSApp.activate(ignoringOtherApps: true)
        
        // 使用 VoiceInputController 统一管理语音输入流程
        print("🎙️ 初始化语音输入控制器...")
        voiceInputController.initializeController()
        
        // 调试：检查权限状态（延迟更久，确保服务完全初始化）
        DispatchQueue.main.asyncAfter(deadline: .now() + configManager.appBehavior.permissionCheckDelay) {
            self.debugPermissionStatus()
            
            // 检查 VoiceInputController 是否初始化成功，如果失败则重新初始化
            let statusInfo = self.voiceInputController.getStatusInfo()
            if !statusInfo.isInitialized {
                print("🔄 VoiceInputController 未初始化，尝试重新初始化...")
                self.voiceInputController.reinitializeController()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 AppDelegate: 应用即将终止，开始清理资源...")
        
        // VoiceInputController 会自动清理其管理的服务
        // 这里只需要清理 AppDelegate 直接管理的资源
        
        // 清理状态栏控制器
        statusBarController = nil
        print("✅ 状态栏控制器已清理")
        
        // 清理静态AppDelegate引用
        CapsWriterApp.sharedAppDelegate = nil
        print("✅ 静态引用已清理")
        
        print("🛑 AppDelegate: 资源清理完成")
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
    
    // MARK: - VoiceInputController Integration
    
    /// 启动键盘监听 - 供 StatusBarController 调用
    func startKeyboardMonitoring() {
        voiceInputController.startKeyboardMonitoring()
    }
    
    /// 停止键盘监听 - 供 StatusBarController 调用
    func stopKeyboardMonitoring() {
        voiceInputController.stopKeyboardMonitoring()
    }
    
    /// 获取语音输入状态信息 - 供 UI 组件调用
    func getVoiceInputStatus() -> VoiceInputStatusInfo {
        return voiceInputController.getStatusInfo()
    }
    
    /// 开始录音 - 供 UI 组件调用
    func startRecording() {
        voiceInputController.startListening()
    }
    
    /// 停止录音 - 供 UI 组件调用
    func stopRecording() {
        voiceInputController.stopListening()
    }
    
    /// 键盘监听器 - 委托给 VoiceInputController
    var keyboardMonitor: KeyboardMonitor? {
        // 注意：直接访问已不推荐，应使用 VoiceInputController 的方法
        return nil
    }
    
    /// 设置键盘监听器 - 委托给 VoiceInputController
    func setupKeyboardMonitor() {
        // 键盘监听器由 VoiceInputController 管理，无需单独设置
        print("⚠️ setupKeyboardMonitor 已废弃，使用 VoiceInputController 管理")
    }
    
    /// ASR 服务 - 委托给 VoiceInputController
    var asrService: SherpaASRService? {
        // 注意：直接访问已不推荐，应使用 VoiceInputController 的方法
        return nil
    }
    
    // MARK: - 调试方法
    private func debugPermissionStatus() {
        print("🔍 === 权限状态调试 ===")
        
        // 从 VoiceInputController 获取状态信息
        let statusInfo = voiceInputController.getStatusInfo()
        
        // 检查辅助功能权限
        let hasAccessibilityPermission = KeyboardMonitor.checkAccessibilityPermission()
        print("🔐 辅助功能权限: \(hasAccessibilityPermission ? "✅ 已授权" : "❌ 未授权")")
        
        // 检查麦克风权限
        let micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 麦克风权限: \(micPermission == .authorized ? "✅ 已授权" : "❌ 未授权 (\(micPermission.rawValue))")")
        
        // 检查 VoiceInputController 状态
        print("🎙️ VoiceInputController: 初始化状态: \(statusInfo.isInitialized ? "✅ 已初始化" : "❌ 未初始化")")
        print("🎙️ VoiceInputController: 当前阶段: \(statusInfo.currentPhase)")
        print("🎙️ VoiceInputController: 录音状态: \(statusInfo.isRecording ? "✅ 录音中" : "❌ 未录音")")
        
        if let error = statusInfo.lastError {
            print("❌ VoiceInputController: 最后错误: \(error.localizedDescription)")
        }
        
        print("🔍 === 调试完成 ===")
        
        // 如果没有辅助功能权限，提示用户
        if !hasAccessibilityPermission {
            print("⚠️ 请前往 系统设置 → 隐私与安全性 → 辅助功能，添加 CapsWriter-mac")
        }
    }
    
    // MARK: - 后台模式管理
    
    /// 切换应用的激活策略
    /// - Parameter toBackground: true表示切换到后台代理模式，false表示正常模式
    func switchActivationPolicy(toBackground: Bool) {
        if toBackground {
            print("🔄 切换到后台代理模式...")
            NSApp.setActivationPolicy(.accessory)
        } else {
            print("🔄 切换到正常模式...")
            NSApp.setActivationPolicy(.regular)
            // 激活应用到前台
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    /// 检查应用是否可以在后台运行语音输入
    func canRunInBackground() -> Bool {
        // 从 VoiceInputController 获取状态信息来判断
        let statusInfo = voiceInputController.getStatusInfo()
        return statusInfo.hasAccessibilityPermission && statusInfo.hasAudioPermission
    }
}