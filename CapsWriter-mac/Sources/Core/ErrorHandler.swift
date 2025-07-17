import Foundation
import SwiftUI
import Combine
import OSLog

/// 统一错误处理器 - CapsWriter-mac 第一阶段任务 1.3
/// 负责错误收集、分类、恢复和用户通知
/// 实现 ErrorHandlerProtocol 以支持依赖注入
class ErrorHandler: ObservableObject, ErrorHandlerProtocol {
    
    // MARK: - Types
    
    /// 错误严重程度
    enum ErrorSeverity: String, CaseIterable {
        case low = "低"        
        case medium = "中"     
        case high = "高"       
        case critical = "严重" 
    }
    
    /// 错误恢复策略
    enum RecoveryStrategy {
        case none              
        case retry             
        case fallback          
        case restart           
        case userAction        
    }
    
    /// 错误上下文信息
    struct ErrorContext {
        let component: String      
        let operation: String     
        let timestamp: Date       
        let userInfo: [String: Any] 
        
        init(component: String, operation: String, userInfo: [String: Any] = [:]) {
            self.component = component
            self.operation = operation
            self.timestamp = Date()
            self.userInfo = userInfo
        }
    }
    
    /// 错误记录
    struct ErrorRecord: Identifiable {
        let id = UUID()
        let error: AppError
        let context: ErrorContext
        let severity: ErrorSeverity
        let recoveryStrategy: RecoveryStrategy
        let isResolved: Bool
        let resolvedAt: Date?
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: context.timestamp)
        }
    }
    
    // MARK: - Published Properties
    
    @Published var activeErrors: [ErrorRecord] = []
    @Published var errorHistory: [ErrorRecord] = []
    @Published var currentHighestSeverityError: ErrorRecord?
    @Published var shouldShowErrorNotification: Bool = false
    @Published var errorStats: ErrorStatistics = ErrorStatistics()
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.capswriter.mac", category: "ErrorHandler")
    private let errorQueue = DispatchQueue(label: "com.capswriter.error-handler", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private var retryTimers: [UUID: Timer] = [:]
    
    // MARK: - Singleton
    
    static let shared = ErrorHandler()
    
    private init() {
        setupErrorMonitoring()
        logger.info("🔧 ErrorHandler: 错误处理器已初始化")
    }
    
    // MARK: - Public Interface
    
    /// 报告错误
    func reportError(
        _ error: AppError,
        context: ErrorContext,
        severity: ErrorSeverity? = nil,
        recoveryStrategy: RecoveryStrategy? = nil
    ) {
        let determinedSeverity = severity ?? determineSeverity(for: error)
        let determinedStrategy = recoveryStrategy ?? determineRecoveryStrategy(for: error)
        
        let record = ErrorRecord(
            error: error,
            context: context,
            severity: determinedSeverity,
            recoveryStrategy: determinedStrategy,
            isResolved: false,
            resolvedAt: nil
        )
        
        errorQueue.async { [weak self] in
            self?.processError(record)
        }
        
        logger.error("❌ ErrorHandler: \(error.localizedDescription) - \(context.component).\(context.operation)")
    }
    
    /// 标记错误已解决
    func markErrorResolved(_ errorId: UUID) {
        errorQueue.async { [weak self] in
            self?.resolveError(errorId)
        }
    }
    
    /// 清除所有错误记录
    func clearAllErrors() {
        DispatchQueue.main.async {
            self.activeErrors.removeAll()
            self.errorHistory.removeAll()
            self.currentHighestSeverityError = nil
            self.shouldShowErrorNotification = false
        }
        
        errorStats.reset()
        logger.info("🗑️ ErrorHandler: 已清除所有错误记录")
    }
    
    // MARK: - Error Processing
    
    private func processError(_ record: ErrorRecord) {
        DispatchQueue.main.async {
            self.activeErrors.append(record)
            self.errorHistory.append(record)
            
            // 保持历史记录数量限制
            if self.errorHistory.count > 500 {
                self.errorHistory.removeFirst(self.errorHistory.count - 500)
            }
            
            self.updateHighestSeverityError()
            self.errorStats.recordError(record.severity)
            
            if record.severity == .high || record.severity == .critical {
                self.shouldShowErrorNotification = true
            }
        }
        
        executeRecoveryStrategy(for: record)
        
        NotificationCenter.default.post(
            name: .errorDidOccur,
            object: self,
            userInfo: [
                "record": record,
                "severity": record.severity.rawValue
            ]
        )
    }
    
    private func resolveError(_ errorId: UUID) {
        DispatchQueue.main.async {
            if let index = self.activeErrors.firstIndex(where: { $0.id == errorId }) {
                var resolvedRecord = self.activeErrors[index]
                resolvedRecord = ErrorRecord(
                    error: resolvedRecord.error,
                    context: resolvedRecord.context,
                    severity: resolvedRecord.severity,
                    recoveryStrategy: resolvedRecord.recoveryStrategy,
                    isResolved: true,
                    resolvedAt: Date()
                )
                
                self.activeErrors[index] = resolvedRecord
                
                if let historyIndex = self.errorHistory.firstIndex(where: { $0.id == errorId }) {
                    self.errorHistory[historyIndex] = resolvedRecord
                }
                
                self.retryTimers[errorId]?.invalidate()
                self.retryTimers.removeValue(forKey: errorId)
                
                self.updateHighestSeverityError()
                self.errorStats.recordResolution(resolvedRecord.severity)
            }
        }
        
        logger.info("✅ ErrorHandler: 错误已解决 - \(errorId)")
    }
    
    // MARK: - Recovery Strategies
    
    private func executeRecoveryStrategy(for record: ErrorRecord) {
        switch record.recoveryStrategy {
        case .none:
            break
        case .retry:
            scheduleRetry(for: record)
        case .fallback:
            executeFallback(for: record)
        case .restart:
            executeRestart(for: record)
        case .userAction:
            requestUserAction(for: record)
        }
    }
    
    private func scheduleRetry(for record: ErrorRecord) {
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.executeRetry(record.id)
        }
        
        retryTimers[record.id] = timer
        logger.info("⏰ ErrorHandler: 已安排重试 - \(record.context.component).\(record.context.operation)")
    }
    
    private func executeRetry(_ errorId: UUID) {
        guard let record = activeErrors.first(where: { $0.id == errorId && !$0.isResolved }) else {
            return
        }
        
        NotificationCenter.default.post(
            name: .errorRetryRequested,
            object: self,
            userInfo: [
                "record": record,
                "component": record.context.component,
                "operation": record.context.operation
            ]
        )
        
        logger.info("🔄 ErrorHandler: 正在重试 - \(record.context.component).\(record.context.operation)")
    }
    
    private func executeFallback(for record: ErrorRecord) {
        NotificationCenter.default.post(
            name: .errorFallbackRequested,
            object: self,
            userInfo: [
                "record": record,
                "component": record.context.component
            ]
        )
        
        logger.info("⚠️ ErrorHandler: 执行降级处理 - \(record.context.component)")
    }
    
    private func executeRestart(for record: ErrorRecord) {
        NotificationCenter.default.post(
            name: .errorRestartRequested,
            object: self,
            userInfo: [
                "record": record,
                "component": record.context.component
            ]
        )
        
        logger.info("🔄 ErrorHandler: 请求重启服务 - \(record.context.component)")
    }
    
    private func requestUserAction(for record: ErrorRecord) {
        NotificationCenter.default.post(
            name: .errorUserActionRequired,
            object: self,
            userInfo: [
                "record": record,
                "error": record.error
            ]
        )
        
        logger.info("👤 ErrorHandler: 需要用户操作 - \(record.error.localizedDescription)")
    }
    
    // MARK: - Error Analysis
    
    private func determineSeverity(for error: AppError) -> ErrorSeverity {
        switch error {
        case .permissionDenied:
            return .critical
        case .serviceInitializationFailed:
            return .high
        case .modelLoadFailed:
            return .high
        case .configurationLoadFailed:
            return .medium
        case .unknownError:
            return .medium
        }
    }
    
    private func determineRecoveryStrategy(for error: AppError) -> RecoveryStrategy {
        switch error {
        case .permissionDenied:
            return .userAction
        case .serviceInitializationFailed:
            return .restart
        case .modelLoadFailed:
            return .retry
        case .configurationLoadFailed:
            return .fallback
        case .unknownError:
            return .retry
        }
    }
    
    private func updateHighestSeverityError() {
        let activeUnresolvedErrors = activeErrors.filter { !$0.isResolved }
        
        currentHighestSeverityError = activeUnresolvedErrors.max { lhs, rhs in
            severityPriority(lhs.severity) < severityPriority(rhs.severity)
        }
    }
    
    private func severityPriority(_ severity: ErrorSeverity) -> Int {
        switch severity {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    // MARK: - Error Monitoring
    
    private func setupErrorMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .appErrorDidOccur,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?["error"] as? AppError {
                self?.reportError(
                    error,
                    context: ErrorContext(component: "AppState", operation: "stateManagement")
                )
            }
        }
    }
    
    // MARK: - ErrorHandlerProtocol Implementation
    
    /// 处理通用错误 (ErrorHandlerProtocol required method)
    func handle(_ error: Error, context: String) {
        let appError: AppError
        if let appErr = error as? AppError {
            appError = appErr
        } else {
            appError = .unknownError(error.localizedDescription)
        }
        
        reportError(
            appError,
            context: ErrorContext(component: context, operation: "错误处理")
        )
    }
    
    /// 处理语音输入控制器错误 (ErrorHandlerProtocol required method)
    func handleVoiceInputError(_ error: VoiceInputController.VoiceInputError) {
        let appError: AppError
        switch error {
        case .initializationFailed(let message):
            appError = .serviceInitializationFailed(message)
        case .permissionDenied(let message):
            appError = .permissionDenied(message)
        case .recordingFailed(let message):
            appError = .audioCaptureFailed(message)
        case .recognitionFailed(let message):
            appError = .speechRecognitionFailed(message)
        case .textInputFailed(let message):
            appError = .textInputFailed(message)
        }
        
        reportError(
            appError,
            context: ErrorContext(component: "VoiceInputController", operation: "语音输入")
        )
    }
    
    /// 报告错误并提供用户信息 (ErrorHandlerProtocol required method)
    func reportError(_ error: Error, userInfo: [String: Any]?) {
        let appError: AppError
        if let appErr = error as? AppError {
            appError = appErr
        } else {
            appError = .unknownError(error.localizedDescription)
        }
        
        // 从userInfo中提取上下文信息
        let component = userInfo?["component"] as? String ?? "Unknown"
        let operation = userInfo?["operation"] as? String ?? "未知操作"
        
        reportError(
            appError,
            context: ErrorContext(component: component, operation: operation)
        )
    }
    
    deinit {
        retryTimers.values.forEach { $0.invalidate() }
    }
}

// MARK: - Error Statistics

class ErrorStatistics: ObservableObject {
    @Published var totalErrors: Int = 0
    @Published var criticalErrors: Int = 0
    @Published var highErrors: Int = 0
    @Published var mediumErrors: Int = 0
    @Published var lowErrors: Int = 0
    @Published var resolvedErrors: Int = 0
    
    var resolutionRate: Double {
        guard totalErrors > 0 else { return 0 }
        return Double(resolvedErrors) / Double(totalErrors)
    }
    
    func recordError(_ severity: ErrorHandler.ErrorSeverity) {
        totalErrors += 1
        
        switch severity {
        case .critical: criticalErrors += 1
        case .high: highErrors += 1
        case .medium: mediumErrors += 1
        case .low: lowErrors += 1
        }
    }
    
    func recordResolution(_ severity: ErrorHandler.ErrorSeverity) {
        resolvedErrors += 1
    }
    
    func reset() {
        totalErrors = 0
        criticalErrors = 0
        highErrors = 0
        mediumErrors = 0
        lowErrors = 0
        resolvedErrors = 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let errorDidOccur = Notification.Name("errorDidOccur")
    static let errorRetryRequested = Notification.Name("errorRetryRequested")
    static let errorFallbackRequested = Notification.Name("errorFallbackRequested")
    static let errorRestartRequested = Notification.Name("errorRestartRequested")
    static let errorUserActionRequired = Notification.Name("errorUserActionRequired")
}

// MARK: - Convenient Error Reporting Extensions

extension ErrorHandler {
    
    /// 报告配置错误
    func reportConfigurationError(_ message: String, operation: String = "配置加载") {
        reportError(
            .configurationLoadFailed(message),
            context: ErrorContext(component: "Configuration", operation: operation)
        )
    }
    
    /// 报告服务初始化错误
    func reportServiceError(_ serviceName: String, message: String) {
        reportError(
            .serviceInitializationFailed(message),
            context: ErrorContext(component: serviceName, operation: "初始化")
        )
    }
    
    /// 报告权限错误
    func reportPermissionError(_ permissionType: String, message: String) {
        reportError(
            .permissionDenied(message),
            context: ErrorContext(component: "Permission", operation: permissionType)
        )
    }
    
    /// 报告模型加载错误
    func reportModelError(_ modelName: String, message: String) {
        reportError(
            .modelLoadFailed(message),
            context: ErrorContext(component: "Model", operation: "加载\(modelName)")
        )
    }
    
    /// 报告未知错误
    func reportUnknownError(_ component: String, operation: String, message: String) {
        reportError(
            .unknownError(message),
            context: ErrorContext(component: component, operation: operation)
        )
    }
    
    /// 调试信息
    var debugDescription: String {
        return """
        ErrorHandler Debug Info:
        - Active Errors: \(activeErrors.count)
        - Total Errors: \(errorStats.totalErrors)
        - Critical Errors: \(errorStats.criticalErrors)
        - Resolution Rate: \(String(format: "%.1f%%", errorStats.resolutionRate * 100))
        - Highest Severity: \(currentHighestSeverityError?.severity.rawValue ?? "None")
        """
    }
    
    /// 获取错误统计摘要
    var errorSummary: String {
        if activeErrors.isEmpty {
            return "无活跃错误"
        } else {
            let unresolvedCount = activeErrors.filter { !$0.isResolved }.count
            return "活跃错误: \(unresolvedCount)/\(activeErrors.count)"
        }
    }
}

// MARK: - AppError Definition

/// 应用程序错误类型定义
enum AppError: Error, LocalizedError, Equatable {
    case permissionDenied(String)
    case serviceInitializationFailed(String)
    case modelLoadFailed(String)
    case configurationLoadFailed(String)
    case audioCaptureFailed(String)
    case speechRecognitionFailed(String)
    case textInputFailed(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "权限被拒绝: \(message)"
        case .serviceInitializationFailed(let message):
            return "服务初始化失败: \(message)"
        case .modelLoadFailed(let message):
            return "模型加载失败: \(message)"
        case .configurationLoadFailed(let message):
            return "配置加载失败: \(message)"
        case .audioCaptureFailed(let message):
            return "音频采集失败: \(message)"
        case .speechRecognitionFailed(let message):
            return "语音识别失败: \(message)"
        case .textInputFailed(let message):
            return "文本输入失败: \(message)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
    
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied(let lhsMsg), .permissionDenied(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.serviceInitializationFailed(let lhsMsg), .serviceInitializationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.modelLoadFailed(let lhsMsg), .modelLoadFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.configurationLoadFailed(let lhsMsg), .configurationLoadFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.audioCaptureFailed(let lhsMsg), .audioCaptureFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.speechRecognitionFailed(let lhsMsg), .speechRecognitionFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.textInputFailed(let lhsMsg), .textInputFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unknownError(let lhsMsg), .unknownError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}