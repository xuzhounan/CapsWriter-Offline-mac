import Foundation
import Combine
import os.log

// MARK: - Text Processing Service Protocol

/// 文本处理服务协议
protocol TextProcessingServiceProtocol: ServiceLifecycleProtocol {
    /// 处理文本（应用所有处理步骤）
    func processText(_ text: String) -> String
    
    /// 仅应用热词替换
    func applyHotWordReplacement(_ text: String) -> String
    
    /// 仅应用标点符号处理
    func applyPunctuationProcessing(_ text: String) -> String
    
    /// 仅应用格式化处理
    func applyFormatting(_ text: String) -> String
    
    /// 获取处理统计信息
    func getProcessingStatistics() -> TextProcessingStatistics
    
    /// 重置统计信息
    func resetStatistics()
}

// MARK: - Supporting Types

/// 文本处理统计信息
struct TextProcessingStatistics {
    var totalProcessed: Int = 0
    var hotWordReplacements: Int = 0
    var punctuationAdditions: Int = 0
    var formattingApplications: Int = 0
    var averageProcessingTime: Double = 0.0
    var lastProcessedAt: Date?
    
    var summary: String {
        return """
        文本处理统计:
        - 总处理数: \(totalProcessed)
        - 热词替换: \(hotWordReplacements) 次
        - 标点添加: \(punctuationAdditions) 次  
        - 格式应用: \(formattingApplications) 次
        - 平均耗时: \(String(format: "%.2f", averageProcessingTime))ms
        """
    }
}

/// 文本处理步骤
enum TextProcessingStep: String, CaseIterable {
    case hotWordReplacement = "hotword"
    case punctuationProcessing = "punctuation"
    case formatting = "formatting"
    case validation = "validation"
    
    var displayName: String {
        switch self {
        case .hotWordReplacement: return "热词替换"
        case .punctuationProcessing: return "标点符号处理"
        case .formatting: return "格式化"
        case .validation: return "验证"
        }
    }
}

/// 文本处理结果
struct TextProcessingResult {
    let originalText: String
    let processedText: String
    let appliedSteps: [TextProcessingStep]
    let processingTime: TimeInterval
    let hotWordReplacements: Int
    let punctuationAdditions: Int
    
    var wasProcessed: Bool {
        return originalText != processedText
    }
}

// MARK: - Text Processing Service Implementation

/// 文本处理服务实现
/// 统一管理文本处理管道，集成热词替换、标点符号处理和格式化功能
class TextProcessingService: ObservableObject, TextProcessingServiceProtocol {
    
    // MARK: - Dependencies
    
    private let configManager: any ConfigurationManagerProtocol
    private let hotWordService: any HotWordServiceProtocol
    private let punctuationService: any PunctuationServiceProtocol
    private let logger = Logger(subsystem: "com.capswriter.textprocessing", category: "TextProcessingService")
    
    // MARK: - Published Properties
    
    @Published var isInitialized: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastError: Error?
    @Published var statistics = TextProcessingStatistics()
    
    // MARK: - Private Properties
    
    private let processingQueue = DispatchQueue(label: "com.capswriter.textprocessing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    /// 处理时间记录（用于计算平均值）
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeRecords = 100
    
    // MARK: - Initialization
    
    init(
        configManager: any ConfigurationManagerProtocol = DIContainer.shared.resolve(ConfigurationManager.self),
        hotWordService: (any HotWordServiceProtocol)? = nil,
        punctuationService: (any PunctuationServiceProtocol)? = nil
    ) {
        self.configManager = configManager
        
        // 如果没有提供热词服务，通过DI容器获取
        if let providedService = hotWordService {
            self.hotWordService = providedService
        } else {
            // 创建热词服务实例
            self.hotWordService = HotWordService(configManager: configManager, errorHandler: ErrorHandler.shared)
        }
        
        // 如果没有提供标点服务，通过DI容器获取
        if let providedService = punctuationService {
            self.punctuationService = providedService
        } else {
            // 创建标点服务实例
            self.punctuationService = PunctuationService(configManager: configManager)
        }
        
        logger.info("📝 TextProcessingService 已创建")
    }
    
    // MARK: - ServiceLifecycleProtocol Implementation
    
    func initialize() throws {
        logger.info("🚀 初始化文本处理服务...")
        
        do {
            // 初始化热词服务
            try hotWordService.initialize()
            
            // 初始化标点服务
            try punctuationService.initialize()
            
            // 设置配置监听
            setupConfigurationObserver()
            
            isInitialized = true
            logger.info("✅ 文本处理服务初始化成功")
            
        } catch {
            logger.error("❌ 文本处理服务初始化失败: \(error.localizedDescription)")
            lastError = error
            throw error
        }
    }
    
    func start() throws {
        guard isInitialized else {
            throw TextProcessingServiceError.serviceNotInitialized
        }
        
        try hotWordService.start()
        try punctuationService.start()
        isRunning = true
        logger.info("▶️ 文本处理服务已启动")
    }
    
    func stop() {
        hotWordService.stop()
        punctuationService.stop()
        isRunning = false
        logger.info("⏹️ 文本处理服务已停止")
    }
    
    func cleanup() {
        stop()
        hotWordService.cleanup()
        punctuationService.cleanup()
        cancellables.removeAll()
        
        isInitialized = false
        logger.info("🧹 文本处理服务已清理")
    }
    
    // MARK: - TextProcessingServiceProtocol Implementation
    
    func processText(_ text: String) -> String {
        guard isRunning && !text.isEmpty else {
            return text
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return processingQueue.sync { [weak self] in
            guard let self = self else { return text }
            
            let result = self.performFullTextProcessing(text)
            
            let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // 转换为毫秒
            self.updateStatistics(with: result, processingTime: processingTime)
            
            return result.processedText
        }
    }
    
    func applyHotWordReplacement(_ text: String) -> String {
        guard isRunning && configManager.textProcessing.enableHotwordReplacement else {
            return text
        }
        
        return hotWordService.processText(text)
    }
    
    func applyPunctuationProcessing(_ text: String) -> String {
        guard isRunning && configManager.textProcessing.enablePunctuation else {
            return text
        }
        
        return punctuationService.processText(text)
    }
    
    func applyFormatting(_ text: String) -> String {
        guard isRunning else {
            return text
        }
        
        var result = text
        let config = configManager.textProcessing
        
        // 应用格式化规则
        if config.trimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if config.autoCapitalization {
            result = result.capitalizingFirstLetter()
        }
        
        // 长度限制
        if result.count > config.maxTextLength {
            result = String(result.prefix(config.maxTextLength))
            logger.warning("⚠️ 文本长度超限，已截断至 \(config.maxTextLength) 字符")
        }
        
        return result
    }
    
    func getProcessingStatistics() -> TextProcessingStatistics {
        return processingQueue.sync { [weak self] in
            return self?.statistics ?? TextProcessingStatistics()
        }
    }
    
    func resetStatistics() {
        processingQueue.async { [weak self] in
            self?.statistics = TextProcessingStatistics()
            self?.processingTimes.removeAll()
            self?.logger.info("📊 文本处理统计已重置")
        }
    }
    
    // MARK: - Private Implementation
    
    private func performFullTextProcessing(_ text: String) -> TextProcessingResult {
        var currentText = text
        var appliedSteps: [TextProcessingStep] = []
        var hotWordReplacements = 0
        var punctuationAdditions = 0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. 验证输入
        guard validateInput(currentText) else {
            logger.warning("⚠️ 输入文本验证失败: \(text)")
            return TextProcessingResult(
                originalText: text,
                processedText: text,
                appliedSteps: [],
                processingTime: 0,
                hotWordReplacements: 0,
                punctuationAdditions: 0
            )
        }
        appliedSteps.append(.validation)
        
        // 2. 热词替换
        if configManager.textProcessing.enableHotwordReplacement {
            let beforeHotWord = currentText
            currentText = applyHotWordReplacement(currentText)
            if currentText != beforeHotWord {
                hotWordReplacements = countReplacements(before: beforeHotWord, after: currentText)
                appliedSteps.append(.hotWordReplacement)
            }
        }
        
        // 3. 标点符号处理
        if configManager.textProcessing.enablePunctuation {
            let beforePunctuation = currentText
            currentText = applyPunctuationProcessing(currentText)
            if currentText != beforePunctuation {
                punctuationAdditions = countPunctuationAdditions(before: beforePunctuation, after: currentText)
                appliedSteps.append(.punctuationProcessing)
            }
        }
        
        // 4. 格式化
        let beforeFormatting = currentText
        currentText = applyFormatting(currentText)
        if currentText != beforeFormatting {
            appliedSteps.append(.formatting)
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let result = TextProcessingResult(
            originalText: text,
            processedText: currentText,
            appliedSteps: appliedSteps,
            processingTime: processingTime,
            hotWordReplacements: hotWordReplacements,
            punctuationAdditions: punctuationAdditions
        )
        
        if result.wasProcessed {
            logger.debug("📝 文本处理完成: \"\(text)\" -> \"\(currentText)\" (步骤: \(appliedSteps.map { $0.displayName }.joined(separator: ", ")))")
        }
        
        return result
    }
    
    private func validateInput(_ text: String) -> Bool {
        let config = configManager.textProcessing
        
        // 检查最小长度
        guard text.count >= config.minTextLength else {
            return false
        }
        
        // 检查最大长度
        guard text.count <= config.maxTextLength else {
            return false
        }
        
        return true
    }
    
    private func countReplacements(before: String, after: String) -> Int {
        // 简单实现：通过字符差异估算替换次数
        // 实际实现可能需要更复杂的逻辑
        return before == after ? 0 : 1
    }
    
    private func countPunctuationAdditions(before: String, after: String) -> Int {
        // 计算标点符号增加数量
        let beforePunctuationCount = before.components(separatedBy: CharacterSet.punctuationCharacters).count - 1
        let afterPunctuationCount = after.components(separatedBy: CharacterSet.punctuationCharacters).count - 1
        return max(0, afterPunctuationCount - beforePunctuationCount)
    }
    
    private func updateStatistics(with result: TextProcessingResult, processingTime: TimeInterval) {
        // 更新统计信息
        statistics.totalProcessed += 1
        statistics.hotWordReplacements += result.hotWordReplacements
        statistics.punctuationAdditions += result.punctuationAdditions
        statistics.lastProcessedAt = Date()
        
        if result.appliedSteps.contains(.formatting) {
            statistics.formattingApplications += 1
        }
        
        // 更新平均处理时间
        processingTimes.append(processingTime * 1000) // 转换为毫秒
        if processingTimes.count > maxProcessingTimeRecords {
            processingTimes.removeFirst()
        }
        
        statistics.averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        
        // 发布统计更新（主线程）
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    private func setupConfigurationObserver() {
        // 监听配置变化
        if let observableConfig = configManager as? ConfigurationManager {
            observableConfig.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    self?.handleConfigurationChange()
                }
                .store(in: &cancellables)
        }
    }
    
    private func handleConfigurationChange() {
        let config = configManager.textProcessing
        logger.info("⚙️ 文本处理配置已更新:")
        logger.info("   - 热词替换: \(config.enableHotwordReplacement)")
        logger.info("   - 标点符号: \(config.enablePunctuation)")
        logger.info("   - 自动大写: \(config.autoCapitalization)")
        logger.info("   - 清理空格: \(config.trimWhitespace)")
        
        // 如果热词功能被禁用，重新加载热词服务配置
        if !config.enableHotwordReplacement {
            logger.info("🔕 热词替换已禁用")
        } else {
            logger.info("🔛 热词替换已启用")
        }
    }
}

// MARK: - ServiceStatusProtocol

extension TextProcessingService: ServiceStatusProtocol {
    var statusDescription: String {
        let stats = getProcessingStatistics()
        return """
        文本处理服务状态:
        - 已初始化: \(isInitialized)
        - 运行中: \(isRunning)
        - \(stats.summary)
        """
    }
}

// MARK: - Error Types

enum TextProcessingServiceError: Error, LocalizedError {
    case serviceNotInitialized
    case hotWordServiceError(Error)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "文本处理服务未初始化"
        case .hotWordServiceError(let error):
            return "热词服务错误: \(error.localizedDescription)"
        case .configurationError(let message):
            return "配置错误: \(message)"
        }
    }
}

// MARK: - String Extensions

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}