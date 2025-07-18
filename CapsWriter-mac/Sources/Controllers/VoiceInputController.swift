import Foundation
import Combine
import AVFoundation

// MARK: - Imports and Dependencies

// 确保引用正确的依赖注入容器和协议
// 需要确保能够访问各种协议定义

/// 语音输入控制器 - 第二阶段任务2.1
/// 统一协调语音输入流程，从 AppDelegate 中分离业务逻辑
/// 利用事件总线实现组件解耦，为功能扩展做准备
class VoiceInputController: ObservableObject {
    
    // MARK: - Dependencies
    
    private let configManager: any ConfigurationManagerProtocol
    private let textProcessingService: TextProcessingServiceProtocol
    private let permissionMonitorService: PermissionMonitorServiceProtocol
    
    // 使用现有的状态管理（向后兼容）
    private let recordingState = RecordingState.shared
    
    // MARK: - Services (通过协议接口访问)
    
    private var keyboardMonitor: KeyboardMonitorProtocol?
    private var asrService: SpeechRecognitionServiceProtocol?
    private var audioCaptureService: AudioCaptureServiceProtocol?
    private var textInputService: TextInputServiceProtocol?
    
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
        // 通过 DI 容器获取依赖服务
        self.configManager = DIContainer.shared.resolve(ConfigurationManagerProtocol.self)
        self.textProcessingService = DIContainer.shared.resolve(TextProcessingServiceProtocol.self)
        self.permissionMonitorService = DIContainer.shared.resolve(PermissionMonitorServiceProtocol.self)
        
        setupEventSubscriptions()
        setupPermissionMonitoring()
        print("🎙️ VoiceInputController 已初始化（使用依赖注入和响应式权限管理）")
    }
    
    // MARK: - Event Subscriptions
    
    private func setupEventSubscriptions() {
        // 暂时注释事件订阅，先修复基本功能
        // TODO: 等AppEvents完善后恢复事件订阅功能
        print("🔔 VoiceInputController 事件订阅设置完成 (暂时简化)")
    }
    
    // MARK: - Permission Monitoring Setup
    
    private func setupPermissionMonitoring() {
        print("🔐 设置响应式权限监控")
        
        do {
            // 初始化权限监控服务
            try permissionMonitorService.initialize()
            
            // 设置权限变化回调
            permissionMonitorService.permissionChangeHandler = { [weak self] type, status in
                Task { @MainActor in
                    self?.handlePermissionChange(type, status: status)
                }
            }
            
            // 启动权限监控
            permissionMonitorService.start()
            
            print("✅ 响应式权限监控设置完成")
            
        } catch {
            print("❌ 权限监控设置失败: \(error)")
            handleError(.initializationFailed("权限监控初始化失败: \(error.localizedDescription)"))
        }
    }
    
    private func handlePermissionChange(_ type: PermissionType, status: PermissionStatus) {
        print("🔄 处理权限变化: \(type.displayName) → \(status.description)")
        
        // 同步更新到 RecordingState（保持向后兼容）
        switch type {
        case .microphone:
            recordingState.updateMicrophonePermission(status.isGranted)
            
            // 如果权限被撤销且正在录音，立即停止
            if !status.isGranted && currentPhase == .recording {
                print("⚠️ 麦克风权限被撤销，停止录音")
                stopRecordingFlow()
            }
            
        case .accessibility:
            recordingState.updateAccessibilityPermission(status.isGranted)
            
            // 如果权限被撤销，停止键盘监听
            if !status.isGranted {
                print("⚠️ 辅助功能权限被撤销，停止键盘监听")
                keyboardMonitor?.stopMonitoring()
            }
            
        case .textInput:
            // 文本输入权限变化处理
            print("📝 文本输入权限状态: \(status.description)")
        }
        
        // 立即更新服务状态（无需定时器）
        updateServiceStatusesImmediately()
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
               permissionMonitorService.canStartRecording()
    }
    
    /// 获取当前状态信息
    func getStatusInfo() -> VoiceInputStatusInfo {
        return VoiceInputStatusInfo(
            isInitialized: isInitialized,
            currentPhase: currentPhase,
            hasAudioPermission: permissionMonitorService.hasMicrophonePermission,
            hasAccessibilityPermission: permissionMonitorService.hasAccessibilityPermission,
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
            // 初始化文本处理服务
            try textProcessingService.initialize()
            try textProcessingService.start()
            
            // 初始化其他服务
            try initializeServices()
            
            // 设置服务回调
            setupServiceCallbacks()
            
            // 完成初始化
            DispatchQueue.main.async { [weak self] in
                self?.isInitialized = true
                self?.updatePhase(.ready)
                print("✅ VoiceInputController 控制器已初始化完成")
                print("✅ VoiceInputController 初始化完成")
                
                // 更新服务状态到RecordingState（一次性）
                self?.updateServiceStatuses()
                
                // 响应式权限管理已启动，无需定时器轮询
                print("🔐 使用响应式权限管理，已取消定时器轮询")
            }
            
        } catch {
            let voiceInputError = VoiceInputError.initializationFailed(error.localizedDescription)
            print("❌ VoiceInputController 初始化失败: \(error.localizedDescription)")
            print("❌ 错误类型: \(type(of: error))")
            print("❌ 详细错误: \(error)")
            
            // 执行回滚操作
            performInitializationRollback()
            
            // 处理错误
            handleError(voiceInputError)
        }
    }
    
    private func initializeServices() throws {
        print("🔧 开始初始化各项服务（使用依赖注入）...")
        
        // 1. 通过DI容器初始化键盘监听器
        do {
            print("🔧 初始化键盘监听器...")
            keyboardMonitor = DIContainer.shared.resolve(KeyboardMonitorProtocol.self)
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
        
        // 2. 通过DI容器初始化文本输入服务
        do {
            print("🔧 初始化文本输入服务...")
            textInputService = DIContainer.shared.resolve(TextInputServiceProtocol.self)
            print("✅ 文本输入服务初始化完成")
        } catch {
            throw VoiceInputError.initializationFailed("文本输入服务初始化失败: \(error.localizedDescription)")
        }
        
        // 3. 通过DI容器初始化ASR服务
        do {
            print("🔧 初始化ASR服务...")
            asrService = DIContainer.shared.resolve(SpeechRecognitionServiceProtocol.self)
            
            // 验证ASR服务是否成功创建
            guard let asr = asrService else {
                print("❌ ASR服务解析失败 - 检查DIContainer注册")
                throw VoiceInputError.initializationFailed("ASR服务创建失败")
            }
            
            print("✅ ASR服务已解析: \(type(of: asr))")
            
            // 启动ASR服务
            asr.startService()
            print("✅ ASR服务初始化完成")
            
            // 立即更新状态
            DispatchQueue.main.async { [weak self] in
                self?.updateServiceStatusesImmediately()
            }
        } catch {
            print("❌ ASR服务初始化异常: \(error)")
            throw VoiceInputError.initializationFailed("ASR服务初始化失败: \(error.localizedDescription)")
        }
        
        // 4. 通过DI容器初始化音频采集服务
        do {
            print("🔧 初始化音频采集服务...")
            audioCaptureService = DIContainer.shared.resolve(AudioCaptureServiceProtocol.self)
            
            // 验证音频采集服务是否成功创建
            guard let audioService = audioCaptureService else {
                print("❌ 音频采集服务解析失败 - 检查DIContainer注册")
                throw VoiceInputError.initializationFailed("音频采集服务创建失败")
            }
            
            print("✅ 音频采集服务已解析: \(type(of: audioService))")
            print("✅ 音频采集服务初始化完成")
        } catch {
            print("❌ 音频采集服务初始化异常: \(error)")
            throw VoiceInputError.initializationFailed("音频采集服务初始化失败: \(error.localizedDescription)")
        }
        
        print("✅ 所有服务初始化完成（通过依赖注入）")
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
            
            // 立即更新状态
            DispatchQueue.main.async { [weak self] in
                self?.updateServiceStatusesImmediately()
            }
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
        
        // 清理文本处理服务
        textProcessingService.cleanup()
        
        // 重置状态
        DispatchQueue.main.async { [weak self] in
            self?.isInitialized = false
            self?.updatePhase(.idle)
            print("🔄 回滚操作完成，控制器已重置为初始状态")
        }
    }
    
    // MARK: - Private Methods - Event Handlers
    
    private func handleRecordingStartRequested() {
        // 详细诊断检查
        if !isInitialized {
            let error = VoiceInputError.permissionDenied("服务未初始化")
            handleError(error)
            return
        }
        
        if currentPhase != .ready {
            let error = VoiceInputError.permissionDenied("服务状态不正确 (当前: \(currentPhase), 需要: ready)")
            handleError(error)
            return
        }
        
        if !permissionMonitorService.hasMicrophonePermission {
            let error = VoiceInputError.permissionDenied("缺少麦克风权限")
            handleError(error)
            return
        }
        
        if !permissionMonitorService.hasAccessibilityPermission {
            let error = VoiceInputError.permissionDenied("缺少辅助功能权限")
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
            
            // 同步到 RecordingState 供 UI 使用
            self?.recordingState.updatePartialTranscript(text)
        }
    }
    
    private func handleFinalResult(_ text: String) {
        print("✅ 最终识别结果: \(text)")
        
        DispatchQueue.main.async { [weak self] in
            self?.asrService?.addTranscriptEntry(text: text, isPartial: false)
            self?.asrService?.partialTranscript = ""
            
            // 同步到 RecordingState 供 UI 使用
            let entry = TranscriptEntry(timestamp: Date(), text: text, isPartial: false)
            self?.recordingState.addTranscriptEntry(entry)
            self?.recordingState.updatePartialTranscript("")
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
        // 使用TextProcessingService进行完整的文本处理
        return textProcessingService.processText(text)
    }
    
    // MARK: - Private Methods - State Management
    
    private func updatePhase(_ newPhase: VoiceInputPhase) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let oldPhase = self.currentPhase
            self.currentPhase = newPhase
            print("🔄 VoiceInputController 阶段变更: \(oldPhase) -> \(newPhase)")
            
            // 同步更新状态管理器
            switch newPhase {
            case .recording:
                self.recordingState.startRecording()
            case .ready, .idle:
                self.recordingState.stopRecording()
            case .error(let error):
                self.lastError = error
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
        
        // 响应式权限管理会自动处理权限状态更新
        print("🔐 权限状态由响应式系统自动管理")
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
    
    // MARK: - Status Update Methods
    
    /// 立即更新服务状态（由响应式权限系统触发）
    func updateServiceStatusesImmediately() {
        updateServiceStatuses()
    }
    
    /// 更新服务状态到RecordingState
    private func updateServiceStatuses() {
        print("📊 VoiceInputController: 更新服务状态... (响应式触发)")
        
        // 更新ASR服务状态 - 修复状态同步逻辑
        let asrRunning = asrService?.isServiceRunning ?? false
        let asrInitialized = asrService?.isInitialized ?? false
        
        // 修复状态同步逻辑：分别更新运行状态和初始化状态
        recordingState.updateASRServiceStatus(asrRunning)
        recordingState.updateASRServiceInitialized(asrInitialized)
        
        // 调试信息
        print("📊 ASR状态更新: 运行=\(asrRunning), 初始化=\(asrInitialized)")
        
        // 更新初始化进度文本
        if asrInitialized {
            recordingState.updateInitializationProgress("语音识别服务已就绪")
        } else if asrRunning {
            recordingState.updateInitializationProgress("语音识别服务正在初始化...")
        } else {
            recordingState.updateInitializationProgress("语音识别服务未启动")
        }
        
        // 更新音频采集服务状态
        let audioReady = audioCaptureService != nil
        recordingState.updateAudioCaptureServiceStatus(audioReady)
        
        // 权限状态由响应式系统自动管理，无需手动刷新
        print("🔐 权限状态由 PermissionStateManager 响应式管理")
        
        print("📊 VoiceInputController: 服务状态更新完成")
        print("   - ASR服务运行: \(asrRunning)")
        print("   - ASR服务初始化: \(asrInitialized)")
        print("   - 音频采集就绪: \(audioReady)")
    }
    
    // MARK: - Cleanup
    
    deinit {
        keyboardMonitor?.stopMonitoring()
        audioCaptureService?.stopCapture()
        asrService?.stopService()
        textProcessingService.cleanup()
        permissionMonitorService.cleanup()
        
        // 清理delegate引用
        asrService?.delegate = nil
        audioCaptureService?.delegate = nil
        
        print("🧹 VoiceInputController 已清理（包含响应式权限管理）")
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