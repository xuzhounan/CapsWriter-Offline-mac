import Foundation
import AVFoundation
import Combine

// MARK: - Service Protocols

/// 音频采集服务协议
protocol AudioCaptureServiceProtocol: AnyObject {
    // MARK: - Properties
    var isCapturing: Bool { get }
    var hasPermission: Bool { get }
    var delegate: AudioCaptureDelegate? { get set }
    
    // MARK: - Methods
    func checkMicrophonePermission() -> Bool
    func requestPermissionAndStartCapture()
    func startCapture()
    func stopCapture()
}

/// 语音识别服务协议
protocol SpeechRecognitionServiceProtocol: AnyObject {
    // MARK: - Properties
    var isServiceRunning: Bool { get }
    var partialTranscript: String { get set }
    var delegate: SpeechRecognitionDelegate? { get set }
    
    // MARK: - Methods
    func startService()
    func stopService()
    func startRecognition()
    func stopRecognition()
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func addTranscriptEntry(text: String, isPartial: Bool)
}

/// 文本输入服务协议
protocol TextInputServiceProtocol: AnyObject {
    // MARK: - Methods
    func checkAccessibilityPermission() -> Bool
    func shouldInputText(_ text: String) -> Bool
    func formatTextForInput(_ text: String) -> String
    func inputText(_ text: String)
    func inputTextWithAutoCorrection(_ text: String)
    func simulateKeyPress(_ keyCode: CGKeyCode, modifiers: CGEventFlags)
}

/// 键盘监听服务协议
protocol KeyboardMonitorProtocol: AnyObject {
    // MARK: - Properties
    var isRunning: Bool { get }
    var startRecordingCallback: (() -> Void)? { get set }
    var stopRecordingCallback: (() -> Void)? { get set }
    
    // MARK: - Methods
    func startMonitoring()
    func stopMonitoring()
    func setCallbacks(startRecording: @escaping () -> Void, stopRecording: @escaping () -> Void)
    func checkAccessibilityPermission() -> Bool
}

/// 配置管理服务协议
protocol ConfigurationManagerProtocol: AnyObject {
    // MARK: - Properties
    var audio: AudioConfiguration { get }
    var keyboard: KeyboardConfiguration { get }
    var appBehavior: AppBehaviorConfiguration { get }
    var textProcessing: TextProcessingConfiguration { get }
    var ui: UIConfiguration { get }
    var debug: DebugConfiguration { get }
    
    // MARK: - Methods
    func save()
    func reset()
    func resetToDefaults()
    func exportConfiguration() -> Data?
    func importConfiguration(from data: Data) -> Bool
}

// MARK: - Error Handling Protocol

/// 错误处理服务协议
protocol ErrorHandlerProtocol: AnyObject {
    func handle(_ error: Error, context: String)
    func handleVoiceInputError(_ error: VoiceInputController.VoiceInputError)
    func reportError(_ error: Error, userInfo: [String: Any]?)
}

// MARK: - Logging Protocol

/// 日志服务协议
protocol LoggingServiceProtocol: AnyObject {
    func log(_ message: String, level: LogLevel, category: String)
    func debug(_ message: String, category: String)
    func info(_ message: String, category: String)
    func warning(_ message: String, category: String)
    func error(_ message: String, category: String)
}

/// 日志级别
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

// MARK: - Service Status Protocol

/// 服务状态协议
protocol ServiceStatusProtocol {
    var isInitialized: Bool { get }
    var isRunning: Bool { get }
    var lastError: Error? { get }
    var statusDescription: String { get }
}

// MARK: - Service Lifecycle Protocol

/// 服务生命周期管理协议
protocol ServiceLifecycleProtocol: AnyObject {
    func initialize() throws
    func start() throws
    func stop()
    func cleanup()
}

// MARK: - Dependency Injection Protocol

/// 依赖注入协议
protocol DependencyInjectionProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T
    func resolve<T>(_ type: T.Type) -> T?
}

// MARK: - Mock Support Protocols

/// Mock 音频采集服务协议 (用于测试)
protocol MockAudioCaptureServiceProtocol: AudioCaptureServiceProtocol {
    func simulateAudioData(_ buffer: AVAudioPCMBuffer)
    func simulatePermissionState(_ hasPermission: Bool)
    func simulateError(_ error: Error)
}

/// Mock 语音识别服务协议 (用于测试)
protocol MockSpeechRecognitionServiceProtocol: SpeechRecognitionServiceProtocol {
    func simulatePartialResult(_ text: String)
    func simulateFinalResult(_ text: String)
    func simulateEndpointDetection()
    func simulateError(_ error: Error)
}

/// Mock 文本输入服务协议 (用于测试)
protocol MockTextInputServiceProtocol: TextInputServiceProtocol {
    var lastInputText: String? { get }
    var inputHistory: [String] { get }
    func clearHistory()
}

/// Mock 键盘监听服务协议 (用于测试)
protocol MockKeyboardMonitorProtocol: KeyboardMonitorProtocol {
    func simulateKeyPress()
    func simulateKeySequence()
    func simulatePermissionChange(_ hasPermission: Bool)
}

// MARK: - Service Factory Protocol

/// 服务工厂协议
protocol ServiceFactoryProtocol {
    func createAudioCaptureService() -> AudioCaptureServiceProtocol
    func createSpeechRecognitionService() -> SpeechRecognitionServiceProtocol
    func createTextInputService() -> TextInputServiceProtocol
    func createKeyboardMonitor() -> KeyboardMonitorProtocol
    func createConfigurationManager() -> ConfigurationManagerProtocol
}

// MARK: - Event Bus Protocol

/// 事件总线协议 (为后续扩展预留)
protocol EventBusProtocol: AnyObject {
    func publish<T>(_ event: T)
    func subscribe<T>(_ eventType: T.Type, handler: @escaping (T) -> Void)
    func unsubscribe<T>(_ eventType: T.Type)
}