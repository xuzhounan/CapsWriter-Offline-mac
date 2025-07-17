import SwiftUI
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusBarController: StatusBarController?
    var keyboardMonitor: KeyboardMonitor?
    var asrService: SherpaASRService?
    var audioCaptureService: AudioCaptureService?
    var textInputService: TextInputService?
    
    // Audio forwarding counter
    private static var forwardCount = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀🚀🚀 AppDelegate: applicationDidFinishLaunching 开始执行 🚀🚀🚀")
        
        // 禁用窗口恢复功能
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        
        // 设置应用为正常应用，可在需要时切换为代理模式
        NSApp.setActivationPolicy(.regular)
        
        // 立即初始化状态栏控制器（轻量级操作）
        statusBarController = StatusBarController()
        
        // 立即初始化键盘监听器（轻量级操作）
        print("🔧 快速初始化键盘监听器...")
        setupKeyboardMonitor()
        print("✅ 键盘监听器初始化完成")
        
        // 手动激活应用，确保 Dock 图标显示
        NSApp.activate(ignoringOtherApps: true)
        
        // 初始化文本输入服务（轻量级操作）
        print("⌨️ 初始化文本输入服务...")
        setupTextInputService()
        
        // 异步初始化语音识别服务（耗时操作）
        print("🔧 开始异步初始化语音识别服务...")
        setupASRServiceAsync()
        
        // 调试：检查权限状态（延迟更久，确保监听器完全初始化）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.debugPermissionStatus()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 AppDelegate: 应用即将终止，开始清理资源...")
        
        // 按正确顺序清理资源，避免依赖关系问题
        // 1. 首先停止键盘监听，避免新的录音触发
        keyboardMonitor?.stopMonitoring()
        keyboardMonitor = nil
        print("✅ 键盘监听器已清理")
        
        // 2. 停止音频采集
        audioCaptureService?.stopCapture()
        audioCaptureService?.delegate = nil // 清除delegate引用
        audioCaptureService = nil
        print("✅ 音频采集服务已清理")
        
        // 3. 停止语音识别服务
        asrService?.stopService()
        asrService?.delegate = nil // 清除delegate引用
        asrService = nil
        print("✅ 语音识别服务已清理")
        
        // 4. 清理文本输入服务
        textInputService = nil
        print("✅ 文本输入服务已清理")
        
        // 5. 清理状态栏控制器
        statusBarController = nil
        print("✅ 状态栏控制器已清理")
        
        // 6. 清理静态AppDelegate引用
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
    
    // MARK: - 语音识别服务设置
    private func setupASRServiceAsync() {
        print("🚀 异步初始化语音服务...")
        
        // 更新初始化进度
        RecordingState.shared.updateInitializationProgress("正在启动语音识别服务...")
        
        // 使用后台队列执行耗时的初始化操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🧠 后台线程：开始初始化ASR服务...")
            RecordingState.shared.updateInitializationProgress("正在加载语音识别模型...")
            
            // 初始化纯识别服务（不涉及麦克风）
            self.initializeASRService()
            
            // 回到主线程更新UI和初始化音频采集服务
            DispatchQueue.main.async {
                print("🎤 主线程：初始化音频采集服务...")
                RecordingState.shared.updateInitializationProgress("正在初始化音频采集服务...")
                
                self.initializeAudioCaptureService()
                
                RecordingState.shared.updateInitializationProgress("启动完成")
                RecordingState.shared.updateASRServiceInitialized(true)
                print("✅ 语音识别服务异步初始化完成")
            }
        }
    }
    
    // 保留原方法供需要时调用
    private func setupASRService() {
        print("🚀 同步初始化语音服务...")
        
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
    
    // MARK: - 文本输入服务设置
    private func setupTextInputService() {
        print("⌨️ 初始化文本输入服务...")
        textInputService = TextInputService.shared
        print("✅ 文本输入服务已初始化")
    }
    
    // MARK: - 键盘监听器设置
    func setupKeyboardMonitor() {
        print("🔧 AppDelegate: 开始设置键盘监听器...")
        print("🔧 创建键盘监听器...")
        keyboardMonitor = KeyboardMonitor()
        print("✅ 键盘监听器对象创建完成")
        
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
        
        // 默认不启动监听器，等待用户手动启动
        print("⏸️ AppDelegate: 键盘监听器已准备就绪，等待用户启动...")
        RecordingState.shared.updateKeyboardMonitorStatus("已停止")
    }
    
    // MARK: - 语音识别回调
    func startRecording() {
        print("🎤 AppDelegate: 开始录音...")
        
        // 更新UI状态
        RecordingState.shared.startRecording()
        
        // 开始音频采集（会自动请求权限）
        audioCaptureService?.requestPermissionAndStartCapture()
        
        // 延迟启动语音识别，确保音频采集已经开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.asrService?.startRecognition()
            print("🧠 AppDelegate: 延迟启动语音识别")
        }
        
        print("✅ AppDelegate: 录音流程已启动")
    }
    
    func stopRecording() {
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
        if keyboardMonitor != nil {
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
        
        // 检查文本输入服务状态
        if let textInput = textInputService {
            let hasInputPermission = textInput.checkAccessibilityPermission()
            print("⌨️ 文本输入服务: 已创建，输入权限: \(hasInputPermission ? "✅ 已授权" : "❌ 未授权")")
        } else {
            print("⌨️ 文本输入服务: ❌ 未创建")
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
        // 添加音频数据转发日志（每200帧输出一次避免刷屏）
        AppDelegate.forwardCount += 1
        if AppDelegate.forwardCount % 200 == 0 {
            print("🔄 已转发 \(AppDelegate.forwardCount) 个音频缓冲区到ASR服务，缓冲区大小: \(buffer.frameLength)")
        }
        
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
        
        // 更新ASR服务的部分转录结果
        DispatchQueue.main.async {
            self.asrService?.partialTranscript = text
        }
    }
    
    func speechRecognitionDidReceiveFinalResult(_ text: String) {
        print("✅ 最终识别结果: \(text)")
        
        // 将最终结果添加到转录历史
        DispatchQueue.main.async {
            self.asrService?.addTranscriptEntry(text: text, isPartial: false)
            self.asrService?.partialTranscript = "" // 清空部分结果
        }
        
        // 语音输入：将识别结果转换为键盘输入
        self.performVoiceInput(text)
    }
    
    func speechRecognitionDidDetectEndpoint() {
        print("🔚 检测到语音端点")
    }
    
    // MARK: - 语音输入方法
    
    /// 执行语音输入：将语音识别结果转换为键盘输入
    /// - Parameter text: 识别到的文本
    private func performVoiceInput(_ text: String) {
        guard let textInputService = textInputService else {
            print("❌ 文本输入服务未初始化")
            return
        }
        
        // 检查文本是否适合输入
        guard textInputService.shouldInputText(text) else {
            print("⚠️ 文本不适合输入，跳过: \(text)")
            return
        }
        
        // 格式化文本
        let formattedText = textInputService.formatTextForInput(text)
        
        print("🎤➡️⌨️ 语音输入: \(text) -> \(formattedText)")
        
        // 延迟一小段时间，确保当前应用有时间处理录音结束
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textInputService.inputText(formattedText)
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
        return textInputService?.checkAccessibilityPermission() ?? false
    }
}