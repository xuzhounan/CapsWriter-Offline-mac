import Foundation
import XCTest
import Combine
import AVFoundation
@testable import CapsWriter_mac

// MARK: - Mock 服务基础协议

/// Mock 服务基础协议，提供通用的测试功能
protocol MockService: AnyObject {
    /// 调用历史记录
    var callHistory: [String] { get set }
    /// 返回值设置
    var returnValues: [String: Any] { get set }
    /// 是否应该抛出错误
    var shouldThrowError: Bool { get set }
    /// 要抛出的错误
    var errorToThrow: Error? { get set }
    
    /// 重置 Mock 状态
    func reset()
    /// 记录方法调用
    func recordCall(_ methodName: String, with parameters: [String: Any])
    /// 验证方法调用次数
    func verifyCall(_ methodName: String, times: Int) -> Bool
}

extension MockService {
    func reset() {
        callHistory.removeAll()
        returnValues.removeAll()
        shouldThrowError = false
        errorToThrow = nil
    }

    func recordCall(_ methodName: String, with parameters: [String: Any] = [:]) {
        let call = parameters.isEmpty ? methodName : "\(methodName):\(parameters)"
        callHistory.append(call)
    }

    func verifyCall(_ methodName: String, times: Int = 1) -> Bool {
        let count = callHistory.filter { $0.contains(methodName) }.count
        return count == times
    }
}

// MARK: - Mock ConfigurationManager

class MockConfigurationManager: ConfigurationManagerProtocol, MockService, ObservableObject {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    // Configuration data
    @Published var general = GeneralConfiguration()
    @Published var audio = AudioConfiguration()
    @Published var recognition = RecognitionConfiguration()
    @Published var hotwords = HotwordConfiguration()
    @Published var shortcuts = ShortcutConfiguration()
    @Published var ui = UIConfiguration()

    func save() {
        recordCall("save")
        if shouldThrowError, let error = errorToThrow {
            // 在实际使用中会抛出错误
        }
    }

    func load() {
        recordCall("load")
        // 加载测试配置
        if let testGeneral = returnValues["general"] as? GeneralConfiguration {
            general = testGeneral
        }
        if let testAudio = returnValues["audio"] as? AudioConfiguration {
            audio = testAudio
        }
    }

    override func reset() {
        super.reset()
        // 重置配置为默认值
        general = GeneralConfiguration()
        audio = AudioConfiguration()
        recognition = RecognitionConfiguration()
        hotwords = HotwordConfiguration()
        shortcuts = ShortcutConfiguration()
        ui = UIConfiguration()
    }
}

// MARK: - Mock HotWordService

class MockHotWordService: HotWordServiceProtocol, MockService, ObservableObject {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    // Mock 数据
    private var mockHotWords: [String: String] = [
        "测试": "test",
        "你好": "hello",
        "世界": "world",
        "开发": "development",
        "应用": "application"
    ]
    
    private var mockStatistics = HotWordStatistics(
        totalEntries: 5,
        chineseEntries: 3,
        englishEntries: 1,
        ruleEntries: 1,
        runtimeEntries: 0,
        totalReplacements: 0,
        lastReloadTime: Date()
    )

    // ServiceLifecycleProtocol
    var isInitialized: Bool = false
    var isRunning: Bool = false
    var lastError: Error?
    var statusDescription: String = "Mock HotWordService"

    func initialize() throws {
        recordCall("initialize")
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isInitialized = true
    }

    func start() throws {
        recordCall("start")
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isRunning = true
    }

    func stop() {
        recordCall("stop")
        isRunning = false
    }

    func cleanup() {
        recordCall("cleanup")
        isInitialized = false
        isRunning = false
        mockHotWords.removeAll()
    }

    // HotWordServiceProtocol
    func processText(_ text: String) -> String {
        recordCall("processText", with: ["text": text])
        
        if shouldThrowError {
            return text
        }
        
        var result = text
        for (original, replacement) in mockHotWords {
            result = result.replacingOccurrences(of: original, with: replacement)
        }
        return result
    }

    func reloadHotWords() {
        recordCall("reloadHotWords")
        if let customHotWords = returnValues["hotWords"] as? [String: String] {
            mockHotWords = customHotWords
        }
    }

    func getStatistics() -> HotWordStatistics {
        recordCall("getStatistics")
        return returnValues["statistics"] as? HotWordStatistics ?? mockStatistics
    }

    func addRuntimeHotWord(original: String, replacement: String, type: HotWordType) {
        recordCall("addRuntimeHotWord", with: [
            "original": original,
            "replacement": replacement,
            "type": type.rawValue
        ])
        mockHotWords[original] = replacement
    }

    func removeRuntimeHotWord(original: String, type: HotWordType) {
        recordCall("removeRuntimeHotWord", with: [
            "original": original,
            "type": type.rawValue
        ])
        mockHotWords.removeValue(forKey: original)
    }

    // Test helper methods
    func setMockHotWords(_ hotWords: [String: String]) {
        mockHotWords = hotWords
    }
    
    func getMockHotWordsCount() -> Int {
        return mockHotWords.count
    }
}

// MARK: - Mock EventBus

class MockEventBus: EventBusProtocol, MockService {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    private var subscribers: [String: [(Any) -> Void]] = [:]
    private var subscriptionCount: [String: Int] = [:]

    func publish<T>(_ event: T) {
        let eventName = String(describing: T.self)
        recordCall("publish", with: ["eventType": eventName])

        // 通知订阅者
        subscribers[eventName]?.forEach { callback in
            callback(event)
        }
    }

    func subscribe<T>(_ eventType: T.Type, handler: @escaping (T) -> Void) {
        let eventName = String(describing: T.self)
        recordCall("subscribe", with: ["eventType": eventName])

        if subscribers[eventName] == nil {
            subscribers[eventName] = []
            subscriptionCount[eventName] = 0
        }

        subscribers[eventName]?.append { event in
            if let typedEvent = event as? T {
                handler(typedEvent)
            }
        }
        
        subscriptionCount[eventName] = (subscriptionCount[eventName] ?? 0) + 1
    }

    func unsubscribe<T>(_ eventType: T.Type) {
        let eventName = String(describing: T.self)
        recordCall("unsubscribe", with: ["eventType": eventName])
        
        subscribers.removeValue(forKey: eventName)
        subscriptionCount.removeValue(forKey: eventName)
    }
    
    // Test helper methods
    func getSubscriberCount<T>(for eventType: T.Type) -> Int {
        let eventName = String(describing: T.self)
        return subscriptionCount[eventName] ?? 0
    }
    
    override func reset() {
        super.reset()
        subscribers.removeAll()
        subscriptionCount.removeAll()
    }
}

// MARK: - Mock AudioCaptureService  

class MockAudioCaptureService: AudioCaptureServiceProtocol, MockService, ObservableObject {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    // Service state
    @Published var isRecording: Bool = false
    @Published var isInitialized: Bool = false
    @Published var currentVolume: Float = 0.0

    // Mock 音频数据
    private var mockAudioData: Data = Data(repeating: 0x00, count: 1024)

    // ServiceLifecycleProtocol
    var isRunning: Bool { isRecording }
    var lastError: Error?
    var statusDescription: String = "Mock AudioCaptureService"

    func initialize() throws {
        recordCall("initialize")
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isInitialized = true
    }

    func start() throws {
        recordCall("start")
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isRecording = true
    }

    func stop() {
        recordCall("stop")
        isRecording = false
    }

    func cleanup() {
        recordCall("cleanup")
        isInitialized = false
        isRecording = false
    }

    // AudioCaptureServiceProtocol methods (根据实际接口调整)
    func startRecording() async throws {
        recordCall("startRecording")
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isRecording = true
    }

    func stopRecording() async throws {
        recordCall("stopRecording") 
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        isRecording = false
    }

    func getAudioData() -> Data? {
        recordCall("getAudioData")
        return returnValues["audioData"] as? Data ?? mockAudioData
    }

    // Test helper methods
    func setMockAudioData(_ data: Data) {
        mockAudioData = data
    }
    
    func simulateVolumeChange(_ volume: Float) {
        currentVolume = volume
    }
}

// MARK: - Mock ErrorHandler

class MockErrorHandler: ErrorHandlerProtocol, MockService {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    private var handledErrors: [Error] = []
    private var errorContexts: [String] = []

    func handle(_ error: Error, context: String) {
        recordCall("handle", with: ["context": context])
        handledErrors.append(error)
        errorContexts.append(context)
    }

    func handleVoiceInputError(_ error: VoiceInputController.VoiceInputError) {
        recordCall("handleVoiceInputError", with: ["errorType": String(describing: error)])
        handledErrors.append(error)
    }

    func reportError(_ error: Error, userInfo: [String: Any]?) {
        recordCall("reportError", with: userInfo ?? [:])
        handledErrors.append(error)
    }

    // Test helper methods
    func getHandledErrors() -> [Error] {
        return handledErrors
    }
    
    func getErrorContexts() -> [String] {
        return errorContexts
    }
    
    override func reset() {
        super.reset()
        handledErrors.removeAll()
        errorContexts.removeAll()
    }
}

// MARK: - Mock TextProcessingService

class MockTextProcessingService: TextProcessingServiceProtocol, MockService {
    var callHistory: [String] = []
    var returnValues: [String: Any] = [:]
    var shouldThrowError = false
    var errorToThrow: Error?

    func processText(_ text: String) -> String {
        recordCall("processText", with: ["text": text])
        
        if shouldThrowError {
            return text
        }
        
        // 返回预设的处理结果或原文本
        return returnValues["processedText"] as? String ?? text.uppercased()
    }

    // Test helper methods
    func setProcessedTextResult(_ result: String) {
        returnValues["processedText"] = result
    }
}

// MARK: - Test Errors

enum MockServiceError: Error, LocalizedError {
    case initializationFailed
    case operationFailed
    case invalidConfiguration
    case networkError
    case timeoutError
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Mock service initialization failed"
        case .operationFailed:
            return "Mock operation failed"
        case .invalidConfiguration:
            return "Invalid mock configuration"
        case .networkError:
            return "Mock network error"
        case .timeoutError:
            return "Mock timeout error"
        }
    }
}