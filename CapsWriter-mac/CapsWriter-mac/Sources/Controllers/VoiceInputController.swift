import Foundation
import Combine
import AVFoundation

/// 语音输入控制器 - 第二阶段任务2.1
/// 统一协调语音输入流程，从 AppDelegate 中分离业务逻辑
/// 利用事件总线实现组件解耦，为功能扩展做准备
class VoiceInputController: ObservableObject {
    
    // MARK: - Dependencies
    
    private let configManager = ConfigurationManager.shared
    
    // 使用现有的状态管理（向后兼容）
    private let recordingState = RecordingState.shared
    
    // MARK: - Services
    
    private var keyboardMonitor: KeyboardMonitor?
    private var asrService: SherpaASRService?
    private var audioCaptureService: AudioCaptureService?
    private var textInputService: TextInputService?
    
    // MARK: - State
    
    @Published var isInitialized: Bool = false
    @Published var currentPhase: VoiceInputPhase = .idle
    @Published var lastError: VoiceInputError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let controllerQueue = DispatchQueue(label: "com.capswriter.voice-input-controller", qos: .userInitiated)
    private var audioForwardCount: Int = 0
    
    // 日志控制开关
    private static let enableDetailedLogging: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// 条件日志输出 - 只在调试模式或需要时输出
    private func debugLog(_ message: String) {
        if Self.enableDetailedLogging {
            print("🔍 [VoiceInputController] \(message)")
        }
    }
    
    // MARK: - Types
    
    enum VoiceInputPhase: Equatable {
        case idle
        case initializing
        case ready
        case recording
        case processing
        case error(VoiceInputError)
        
        static func == (lhs: VoiceInputPhase, rhs: VoiceInputPhase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.initializing, .initializing), (.ready, .ready), (.recording, .recording), (.processing, .processing):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    enum VoiceInputError: Error, LocalizedError {
        case initializationFailed(String)
        case permissionDenied(String)
        case recordingFailed(String)
        case recognitionFailed(String)
        case textInputFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .initializationFailed(let message):
                return "初始化失败: \(message)"
            case .permissionDenied(let message):
                return "权限不足: \(message)"
            case .recordingFailed(let message):
                return "录音失败: \(message)"
            case .recognitionFailed(let message):
                return "识别失败: \(message)"
            case .textInputFailed(let message):
                return "文本输入失败: \(message)"
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = VoiceInputController()
    
    private init() {
        setupEventSubscriptions()
        print("🎙️ VoiceInputController 已初始化")
    }
    
    // MARK: - Event Subscriptions
    
    private func setupEventSubscriptions() {
        // 暂时注释事件订阅，先修复基本功能
        // TODO: 等AppEvents完善后恢复事件订阅功能
        print("🔔 VoiceInputController 事件订阅设置完成 (暂时简化)")
    }
    
    // MARK: - Public Interface
    
    /// 初始化语音输入控制器
    func initializeController() {
        print("🚀 开始初始化 VoiceInputController")
        
        controllerQueue.async { [weak self] in
            self?.performInitialization()
        }
    }
    
    /// 重新初始化控制器（在初始化失败后可调用）
    func reinitializeController() {
        print("🔄 重新初始化 VoiceInputController")
        
        // 先清理当前状态
        performInitializationRollback()
        
        // 等待一段时间后重新初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.initializeController()
        }
    }
    
    /// 启动键盘监听
    func startKeyboardMonitoring() {
        guard isInitialized else {
            print("❌ 控制器未初始化，无法启动键盘监听")
            return
        }
        
        keyboardMonitor?.startMonitoring()
        print("🔔 键盘监听已启动")
    }
    
    /// 停止键盘监听
    func stopKeyboardMonitoring() {
        keyboardMonitor?.stopMonitoring()
        print("🔕 键盘监听已停止")
    }
    
    /// 检查是否可以开始录音
    func canStartRecording() -> Bool {
        return isInitialized && 
               currentPhase == .ready && 
               recordingState.hasMicrophonePermission && 
               recordingState.hasAccessibilityPermission
    }
    
    /// 获取当前状态信息
    func getStatusInfo() -> VoiceInputStatusInfo {
        return VoiceInputStatusInfo(
            isInitialized: isInitialized,
            currentPhase: currentPhase,
            hasAudioPermission: recordingState.hasMicrophonePermission,
            hasAccessibilityPermission: recordingState.hasAccessibilityPermission,
            isRecording: currentPhase == .recording,
            lastError: lastError
        )
    }
    
    /// 开始监听（为向后兼容性）
    func startListening() {
        handleRecordingStartRequested()
    }
    
    /// 停止监听（为向后兼容性）
    func stopListening() {
        handleRecordingStopRequested()
    }
    
    // MARK: - Private Methods - Initialization
    
    private func performInitialization() {
        updatePhase(.initializing)
        
        do {
            // 初始化服务
            try initializeServices()
            
            // 设置服务回调
            setupServiceCallbacks()
            
            // 完成初始化
            DispatchQueue.main.async { [weak self] in
                self?.isInitialized = true
                self?.updatePhase(.ready)
                print("✅ VoiceInputController 控制器已初始化完成")
                print("✅ VoiceInputController 初始化完成")
            }
            
        } catch {
            let voiceInputError = VoiceInputError.initializationFailed(error.localizedDescription)
            print("❌ VoiceInputController 初始化失败: \(error.localizedDescription)")
            
            // 执行回滚操作
            performInitializationRollback()
            
            // 处理错误
            handleError(voiceInputError)
        }
    }
    
    private func initializeServices() throws {
        print("🔧 开始初始化各项服务...")
        
        // 1. 初始化键盘监听器
        do {
            print("🔧 初始化键盘监听器...")
            keyboardMonitor = KeyboardMonitor()
            keyboardMonitor?.setCallbacks(
                startRecording: { [weak self] in
                    self?.handleRecordingStartRequested()
                },
                stopRecording: { [weak self] in
                    self?.handleRecordingStopRequested()
                }
            )
            print("✅ 键盘监听器初始化完成")
        } catch {
            throw VoiceInputError.initializationFailed("键盘监听器初始化失败: \(error.localizedDescription)")
        }
        
        // 2. 初始化文本输入服务
        do {
            print("🔧 初始化文本输入服务...")
            textInputService = TextInputService.shared
            print("✅ 文本输入服务初始化完成")
        } catch {
            throw VoiceInputError.initializationFailed("文本输入服务初始化失败: \(error.localizedDescription)")
        }
        
        // 3. 初始化ASR服务
        do {
            print("🔧 初始化ASR服务...")
            asrService = SherpaASRService()
            
            // 验证ASR服务是否成功创建
            guard let asr = asrService else {
                throw VoiceInputError.initializationFailed("ASR服务创建失败")
            }
            
            // 启动ASR服务
            asr.startService()
            print("✅ ASR服务初始化完成")
        } catch {
            throw VoiceInputError.initializationFailed("ASR服务初始化失败: \(error.localizedDescription)")
        }
        
        // 4. 初始化音频采集服务
        do {
            print("🔧 初始化音频采集服务...")
            audioCaptureService = AudioCaptureService()
            
            // 验证音频采集服务是否成功创建
            guard audioCaptureService != nil else {
                throw VoiceInputError.initializationFailed("音频采集服务创建失败")
            }
            print("✅ 音频采集服务初始化完成")
        } catch {
            throw VoiceInputError.initializationFailed("音频采集服务初始化失败: \(error.localizedDescription)")
        }
        
        print("✅ 所有服务初始化完成")
    }
    
    private func setupServiceCallbacks() {
        // 设置ASR服务回调
        asrService?.delegate = self
        
        // 设置音频采集服务回调
        audioCaptureService?.delegate = self
        
        print("📞 服务回调设置完成")
    }
    
    /// 初始化失败时的回滚操作
    private func performInitializationRollback() {
        print("🔄 执行初始化回滚操作...")
        
        // 清理ASR服务
        if let asr = asrService {
            print("🧹 清理ASR服务...")
            asr.stopService()
            asr.delegate = nil
            asrService = nil
        }
        
        // 清理音频采集服务
        if let audio = audioCaptureService {
            print("🧹 清理音频采集服务...")
            audio.delegate = nil
            audioCaptureService = nil
        }
        
        // 清理键盘监听器
        if let keyboard = keyboardMonitor {
            print("🧹 清理键盘监听器...")
            keyboard.stopMonitoring()
            keyboardMonitor = nil
        }
        
        // 清理文本输入服务引用
        textInputService = nil
        
        // 重置状态
        DispatchQueue.main.async { [weak self] in
            self?.isInitialized = false
            self?.updatePhase(.idle)
            print("🔄 回滚操作完成，控制器已重置为初始状态")
        }
    }
    
    // MARK: - Private Methods - Event Handlers
    
    private func handleRecordingStartRequested() {
        guard canStartRecording() else {
            let error = VoiceInputError.permissionDenied("缺少必要权限或服务未就绪")
            handleError(error)
            return
        }
        
        startRecordingFlow()
    }
    
    private func handleRecordingStopRequested() {
        guard currentPhase == .recording else {
            print("⚠️ 当前不在录音状态，忽略停止请求")
            return
        }
        
        stopRecordingFlow()
    }
    
    private func handleAudioCaptureStarted() {
        print("🎤 音频采集已启动")
    }
    
    private func handleAudioCaptureStopped() {
        print("⏹️ 音频采集已停止")
    }
    
    private func handleAudioCaptureError(_ error: Error) {
        let voiceInputError = VoiceInputError.recordingFailed(error.localizedDescription)
        handleError(voiceInputError)
    }
    
    private func handlePartialResult(_ text: String) {
        print("📝 部分识别结果: \(text)")
        
        DispatchQueue.main.async { [weak self] in
            // 更新识别状态 - 使用现有的状态管理
            self?.asrService?.partialTranscript = text
        }
    }
    
    private func handleFinalResult(_ text: String) {
        print("✅ 最终识别结果: \(text)")
        
        DispatchQueue.main.async { [weak self] in
            self?.asrService?.addTranscriptEntry(text: text, isPartial: false)
            self?.asrService?.partialTranscript = ""
        }
        
        // 处理文本输入
        processTextInput(text)
    }
    
    private func handleEndpointDetected() {
        print("🔚 检测到语音端点")
    }
    
    private func handleRecognitionError(_ error: Error) {
        let voiceInputError = VoiceInputError.recognitionFailed(error.localizedDescription)
        handleError(voiceInputError)
    }
    
    private func handleMicrophonePermissionChanged(_ hasPermission: Bool) {
        recordingState.updateMicrophonePermission(hasPermission)
        print("🎤 麦克风权限状态变更: \(hasPermission ? "已授权" : "未授权")")
        
        if !hasPermission && currentPhase == .recording {
            stopRecordingFlow()
        }
    }
    
    private func handleAccessibilityPermissionChanged(_ hasPermission: Bool) {
        recordingState.updateAccessibilityPermission(hasPermission)
        print("🔐 辅助功能权限状态变更: \(hasPermission ? "已授权" : "未授权")")
    }
    
    // MARK: - Private Methods - Recording Flow
    
    private func startRecordingFlow() {
        print("🎤 开始录音流程")
        
        updatePhase(.recording)
        
        // 录音开始
        print("🚀 录音流程已开始")
        
        // 启动音频采集
        audioCaptureService?.requestPermissionAndStartCapture()
        
        // 延迟启动语音识别
        let delay = configManager.appBehavior.recognitionStartDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.asrService?.startRecognition()
            print("🧠 延迟启动语音识别")
        }
    }
    
    private func stopRecordingFlow() {
        print("⏹️ 停止录音流程")
        
        updatePhase(.processing)
        
        // 停止音频采集
        audioCaptureService?.stopCapture()
        
        // 停止语音识别
        asrService?.stopRecognition()
        
        // 录音停止
        print("🚀 录音流程已停止")
        
        // 延迟回到就绪状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updatePhase(.ready)
        }
    }
    
    // MARK: - Private Methods - Text Processing
    
    private func processTextInput(_ text: String) {
        guard let textInputService = textInputService else {
            let error = VoiceInputError.textInputFailed("文本输入服务未初始化")
            handleError(error)
            return
        }
        
        // 检查文本是否适合输入
        guard textInputService.shouldInputText(text) else {
            print("⚠️ 文本不适合输入，跳过: \(text)")
            return
        }
        
        // 应用文本处理
        let processedText = applyTextProcessing(text)
        
        // 格式化文本
        let formattedText = textInputService.formatTextForInput(processedText)
        
        print("🎤➡️⌨️ 语音输入: \(text) -> \(formattedText)")
        
        // 延迟执行文本输入
        let delay = configManager.appBehavior.startupDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            textInputService.inputText(formattedText)
        }
        
        // 发布文本输入事件 (暂时注释，待AppEvents完善)
        // eventBus.publish(AppEvents.TextInput.TextProcessed(
        //     originalText: text,
        //     processedText: formattedText
        // ))
    }
    
    private func applyTextProcessing(_ text: String) -> String {
        let processedText = text
        
        // 这里为后续的热词替换和文本处理功能预留接口
        if configManager.textProcessing.enableHotwordReplacement {
            // TODO: 实现热词替换
            print("🔄 热词替换功能将在后续版本中实现")
        }
        
        // TODO: 标点符号处理功能将在后续版本中实现
        print("📝 标点符号处理功能将在后续版本中实现")
        
        return processedText
    }
    
    // MARK: - Private Methods - State Management
    
    private func updatePhase(_ newPhase: VoiceInputPhase) {
        DispatchQueue.main.async { [weak self] in
            self?.currentPhase = newPhase
            
            // 同步更新状态管理器
            switch newPhase {
            case .recording:
                self?.recordingState.startRecording()
            case .ready, .idle:
                self?.recordingState.stopRecording()
            case .error(let error):
                self?.lastError = error
                print("❌ VoiceInputController 状态错误: \(error.localizedDescription)")
            default:
                break
            }
        }
    }
    
    private func handleError(_ error: VoiceInputError) {
        print("❌ VoiceInputController 错误: \(error.localizedDescription)")
        
        // 根据错误类型采取不同的处理策略
        switch error {
        case .initializationFailed(let message):
            print("🚨 初始化失败，需要特殊处理: \(message)")
            handleInitializationError(message)
        case .permissionDenied(let message):
            print("🚨 权限错误: \(message)")
            handlePermissionError(message)
        case .recordingFailed(let message):
            print("🚨 录音错误: \(message)")
            handleRecordingError(message)
        case .recognitionFailed(let message):
            print("🚨 识别错误: \(message)")
            handleRecognitionError(message)
        case .textInputFailed(let message):
            print("🚨 文本输入错误: \(message)")
            // 文本输入错误通常不需要特殊处理，只记录日志
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.lastError = error
            self?.updatePhase(.error(error))
            
            // TODO: 重新启用 StateManager 集成后恢复
            // if let stateManager = StateManager.shared as? StateManager {
            //     stateManager.handleRecognitionError(error.localizedDescription)
            // }
        }
        
        // 错误记录到日志
        print("❌ VoiceInputController 处理错误完成: \(error.localizedDescription)")
    }
    
    /// 处理初始化错误
    private func handleInitializationError(_ message: String) {
        print("🔧 处理初始化错误: \(message)")
        
        // 设置识别引擎状态为错误
        DispatchQueue.main.async { [weak self] in
            self?.recordingState.updateInitializationProgress("初始化失败: \(message)")
            self?.recordingState.updateASRServiceInitialized(false)
        }
        
        // TODO: 重新启用 StateManager 集成后恢复
        // Task { @MainActor in
        //     StateManager.shared.updateRecognitionEngineStatus(.error(message))
        // }
    }
    
    /// 处理权限错误
    private func handlePermissionError(_ message: String) {
        print("🔐 处理权限错误: \(message)")
        
        // 刷新权限状态
        recordingState.refreshPermissionStatus()
    }
    
    /// 处理录音错误
    private func handleRecordingError(_ message: String) {
        print("🎤 处理录音错误: \(message)")
        
        // 停止当前录音流程
        if currentPhase == .recording {
            stopRecordingFlow()
        }
    }
    
    /// 处理识别错误（重载方法）
    private func handleRecognitionError(_ message: String) {
        print("🗣️ 处理识别错误: \(message)")
        
        // 可以在这里添加识别错误的特殊处理逻辑
    }
    
    // MARK: - Cleanup
    
    deinit {
        keyboardMonitor?.stopMonitoring()
        audioCaptureService?.stopCapture()
        asrService?.stopService()
        
        // 清理delegate引用
        asrService?.delegate = nil
        audioCaptureService?.delegate = nil
        
        print("🧹 VoiceInputController 已清理")
    }
}

// MARK: - Supporting Types

struct VoiceInputStatusInfo {
    let isInitialized: Bool
    let currentPhase: VoiceInputController.VoiceInputPhase
    let hasAudioPermission: Bool
    let hasAccessibilityPermission: Bool
    let isRecording: Bool
    let lastError: VoiceInputController.VoiceInputError?
}

// MARK: - AudioCaptureDelegate

extension VoiceInputController: AudioCaptureDelegate {
    func audioCaptureDidReceiveBuffer(_ buffer: AVAudioPCMBuffer) {
        // 转发音频数据到ASR服务
        asrService?.processAudioBuffer(buffer)
        
        // 可选的详细日志输出（频率大幅降低）
        audioForwardCount += 1
        
        // 只在调试模式或每1000次时输出日志，大幅减少日志频率
        #if DEBUG
        let shouldLog = audioForwardCount % 1000 == 0
        #else
        let shouldLog = audioForwardCount % 5000 == 0  // 发布版本更少的日志
        #endif
        
        if shouldLog {
            print("🔄 [音频处理] 已转发 \(audioForwardCount) 个音频缓冲区，当前缓冲区大小: \(buffer.frameLength)")
        }
    }
    
    func audioCaptureDidStart() {
        handleAudioCaptureStarted()
    }
    
    func audioCaptureDidStop() {
        handleAudioCaptureStopped()
    }
    
    func audioCaptureDidFailWithError(_ error: Error) {
        handleAudioCaptureError(error)
    }
}

// MARK: - SpeechRecognitionDelegate

extension VoiceInputController: SpeechRecognitionDelegate {
    func speechRecognitionDidReceivePartialResult(_ text: String) {
        handlePartialResult(text)
    }
    
    func speechRecognitionDidReceiveFinalResult(_ text: String) {
        handleFinalResult(text)
    }
    
    func speechRecognitionDidDetectEndpoint() {
        handleEndpointDetected()
    }
    
    func speechRecognitionDidFailWithError(_ error: Error) {
        handleRecognitionError(error)
    }
}