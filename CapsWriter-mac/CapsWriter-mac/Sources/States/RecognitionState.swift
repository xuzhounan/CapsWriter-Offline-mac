import SwiftUI
import Combine
import Foundation

/// 语音识别相关状态管理
/// 负责管理语音识别服务状态、识别结果状态和键盘监听器状态
class RecognitionState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// ASR 服务是否正在运行
    @Published var isASRServiceRunning: Bool = false
    
    /// ASR 服务是否已初始化
    @Published var isASRServiceInitialized: Bool = false
    
    /// 键盘监听器状态
    @Published var keyboardMonitorStatus: String = "未知"
    
    /// 当前识别结果
    @Published var currentRecognitionResult: String = ""
    
    /// 部分识别结果
    @Published var partialRecognitionResult: String = ""
    
    /// 识别历史记录
    @Published var recognitionHistory: [RecognitionEntry] = []
    
    /// 识别统计信息
    @Published var recognitionStats: RecognitionStatistics = RecognitionStatistics()
    
    /// 键盘监听器是否启用
    @Published var isKeyboardMonitorEnabled: Bool = false
    
    /// 是否检测到语音端点
    @Published var isEndpointDetected: Bool = false
    
    // MARK: - Private Properties
    
    private let stateQueue = DispatchQueue(label: "com.capswriter.recognition-state", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // 键盘监听器用户控制标志
    private var _isManuallyStoppedByUser: Bool = false
    private var isManuallyStoppedByUser: Bool {
        get {
            stateQueue.sync { _isManuallyStoppedByUser }
        }
        set {
            stateQueue.async(flags: .barrier) { [weak self] in
                self?._isManuallyStoppedByUser = newValue
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = RecognitionState()
    
    private init() {
        setupRecognitionMonitoring()
    }
    
    // MARK: - ASR Service Status
    
    /// 更新 ASR 服务运行状态
    func updateASRServiceStatus(_ isRunning: Bool) {
        DispatchQueue.main.async {
            self.isASRServiceRunning = isRunning
        }
        
        // 发送服务状态变更通知
        NotificationCenter.default.post(
            name: .asrServiceStatusDidChange,
            object: self,
            userInfo: ["isRunning": isRunning]
        )
    }
    
    /// 更新 ASR 服务初始化状态
    func updateASRServiceInitialized(_ isInitialized: Bool) {
        DispatchQueue.main.async {
            self.isASRServiceInitialized = isInitialized
        }
        
        if isInitialized {
            NotificationCenter.default.post(
                name: .asrServiceDidInitialize,
                object: self
            )
        }
    }
    
    // MARK: - Recognition Results
    
    /// 更新部分识别结果
    func updatePartialResult(_ text: String) {
        DispatchQueue.main.async {
            self.partialRecognitionResult = text
        }
        
        // 更新统计信息
        recognitionStats.incrementPartialResults()
    }
    
    /// 添加最终识别结果
    func addFinalResult(_ text: String) {
        guard !text.isEmpty else { return }
        
        let entry = RecognitionEntry(
            text: text,
            timestamp: Date(),
            confidence: 1.0 // 暂时设为1.0，后续可以从识别引擎获取真实置信度
        )
        
        DispatchQueue.main.async {
            self.currentRecognitionResult = text
            self.partialRecognitionResult = "" // 清空部分结果
            self.recognitionHistory.append(entry)
            
            // 保持历史记录不超过 100 条
            if self.recognitionHistory.count > 100 {
                self.recognitionHistory.removeFirst(self.recognitionHistory.count - 100)
            }
        }
        
        // 更新统计信息
        recognitionStats.incrementFinalResults()
        recognitionStats.addTextLength(text.count)
        
        // 发送识别结果通知
        NotificationCenter.default.post(
            name: .recognitionResultDidUpdate,
            object: self,
            userInfo: ["text": text, "entry": entry]
        )
    }
    
    /// 清空识别结果
    func clearRecognitionResults() {
        DispatchQueue.main.async {
            self.currentRecognitionResult = ""
            self.partialRecognitionResult = ""
        }
    }
    
    /// 清空识别历史
    func clearRecognitionHistory() {
        DispatchQueue.main.async {
            self.recognitionHistory.removeAll()
        }
        
        // 重置统计信息
        recognitionStats.reset()
    }
    
    // MARK: - Endpoint Detection
    
    /// 设置语音端点检测状态
    func setEndpointDetected(_ detected: Bool) {
        DispatchQueue.main.async {
            self.isEndpointDetected = detected
        }
        
        if detected {
            NotificationCenter.default.post(
                name: .speechEndpointDetected,
                object: self
            )
        }
    }
    
    // MARK: - Keyboard Monitor Status
    
    /// 更新键盘监听器状态
    func updateKeyboardMonitorStatus(_ status: String) {
        DispatchQueue.main.async {
            self.keyboardMonitorStatus = status
            self.isKeyboardMonitorEnabled = (status == "正在监听" || status == "已启动")
        }
    }
    
    /// 用户手动启动键盘监听器
    func userStartedKeyboardMonitor() {
        isManuallyStoppedByUser = false
        updateKeyboardMonitorStatus("已启动")
        
        NotificationCenter.default.post(
            name: .keyboardMonitorDidStart,
            object: self
        )
    }
    
    /// 用户手动停止键盘监听器
    func userStoppedKeyboardMonitor() {
        isManuallyStoppedByUser = true
        updateKeyboardMonitorStatus("已停止")
        
        NotificationCenter.default.post(
            name: .keyboardMonitorDidStop,
            object: self
        )
    }
    
    /// 检查键盘监听器是否被用户手动停止
    var isKeyboardMonitorManuallyStoppedByUser: Bool {
        return isManuallyStoppedByUser
    }
    
    // MARK: - Recognition Monitoring
    
    /// 设置识别监控
    private func setupRecognitionMonitoring() {
        // 监听音频录音状态变化
        NotificationCenter.default.addObserver(
            forName: .audioRecordingDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recognitionStats.startSession()
        }
        
        NotificationCenter.default.addObserver(
            forName: .audioRecordingDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recognitionStats.endSession()
            self?.setEndpointDetected(false)
        }
    }
    
    // MARK: - State Validation
    
    /// 验证识别系统是否准备就绪
    var isRecognitionSystemReady: Bool {
        return isASRServiceRunning && isASRServiceInitialized
    }
    
    /// 获取识别系统状态描述
    var recognitionSystemStatusDescription: String {
        if !isASRServiceRunning {
            return "ASR服务未运行"
        } else if !isASRServiceInitialized {
            return "ASR服务未初始化"
        } else {
            return "识别系统就绪"
        }
    }
    
    /// 获取键盘监听器状态描述
    var keyboardMonitorStatusDescription: String {
        if isManuallyStoppedByUser {
            return "键盘监听器已被用户停止"
        } else {
            return keyboardMonitorStatus
        }
    }
}

// MARK: - Recognition Entry

/// 识别记录条目
struct RecognitionEntry: Identifiable, Codable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let confidence: Double
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Recognition Statistics

/// 识别统计信息
class RecognitionStatistics: ObservableObject {
    @Published var totalSessions: Int = 0
    @Published var totalFinalResults: Int = 0
    @Published var totalPartialResults: Int = 0
    @Published var totalCharacters: Int = 0
    @Published var averageSessionDuration: TimeInterval = 0
    
    private var currentSessionStartTime: Date?
    private var sessionDurations: [TimeInterval] = []
    
    func startSession() {
        currentSessionStartTime = Date()
        totalSessions += 1
    }
    
    func endSession() {
        guard let startTime = currentSessionStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        sessionDurations.append(duration)
        
        // 计算平均时长
        averageSessionDuration = sessionDurations.reduce(0, +) / Double(sessionDurations.count)
        
        currentSessionStartTime = nil
    }
    
    func incrementFinalResults() {
        totalFinalResults += 1
    }
    
    func incrementPartialResults() {
        totalPartialResults += 1
    }
    
    func addTextLength(_ length: Int) {
        totalCharacters += length
    }
    
    func reset() {
        totalSessions = 0
        totalFinalResults = 0
        totalPartialResults = 0
        totalCharacters = 0
        averageSessionDuration = 0
        sessionDurations.removeAll()
        currentSessionStartTime = nil
    }
    
    var averageCharactersPerResult: Double {
        guard totalFinalResults > 0 else { return 0 }
        return Double(totalCharacters) / Double(totalFinalResults)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let asrServiceStatusDidChange = Notification.Name("asrServiceStatusDidChange")
    static let asrServiceDidInitialize = Notification.Name("asrServiceDidInitialize")
    static let recognitionResultDidUpdate = Notification.Name("recognitionResultDidUpdate")
    static let speechEndpointDetected = Notification.Name("speechEndpointDetected")
    static let keyboardMonitorDidStart = Notification.Name("keyboardMonitorDidStart")
    static let keyboardMonitorDidStop = Notification.Name("keyboardMonitorDidStop")
}

// MARK: - Extensions

extension RecognitionState {
    
    /// 调试信息
    var debugDescription: String {
        return """
        RecognitionState Debug Info:
        - ASR Service Running: \(isASRServiceRunning)
        - ASR Service Initialized: \(isASRServiceInitialized)
        - Keyboard Monitor: \(keyboardMonitorStatus)
        - Current Result: \(currentRecognitionResult)
        - Partial Result: \(partialRecognitionResult)
        - History Count: \(recognitionHistory.count)
        - Total Sessions: \(recognitionStats.totalSessions)
        - Total Results: \(recognitionStats.totalFinalResults)
        """
    }
    
    /// 重置所有状态
    func resetAllStates() {
        DispatchQueue.main.async {
            self.isASRServiceRunning = false
            self.isASRServiceInitialized = false
            self.keyboardMonitorStatus = "未知"
            self.currentRecognitionResult = ""
            self.partialRecognitionResult = ""
            self.recognitionHistory.removeAll()
            self.isKeyboardMonitorEnabled = false
            self.isEndpointDetected = false
        }
        
        recognitionStats.reset()
        isManuallyStoppedByUser = false
        
        print("🔄 RecognitionState: 所有状态已重置")
    }
}