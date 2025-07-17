import Foundation
import Combine
import os.log

// MARK: - Punctuation Service Protocol

/// 标点符号处理服务协议
protocol PunctuationServiceProtocol: ServiceLifecycleProtocol {
    /// 处理文本，添加标点符号
    func processText(_ text: String) -> String
    
    /// 获取标点符号统计信息
    func getStatistics() -> PunctuationStatistics
    
    /// 重置统计信息
    func resetStatistics()
    
    /// 设置标点符号处理强度
    func setPunctuationIntensity(_ intensity: PunctuationIntensity)
}

// MARK: - Supporting Types

/// 标点符号处理强度
enum PunctuationIntensity: String, CaseIterable {
    case light = "light"        // 轻度：仅添加句号
    case medium = "medium"      // 中度：添加句号、逗号
    case heavy = "heavy"        // 重度：添加所有标点符号
    
    var displayName: String {
        switch self {
        case .light: return "轻度"
        case .medium: return "中度"
        case .heavy: return "重度"
        }
    }
    
    var weight: Double {
        switch self {
        case .light: return 0.3
        case .medium: return 0.6
        case .heavy: return 1.0
        }
    }
}

/// 标点符号类型
enum PunctuationType: String, CaseIterable {
    case period = "period"          // 句号 。
    case comma = "comma"            // 逗号 ，
    case question = "question"      // 问号 ？
    case exclamation = "exclamation" // 感叹号 ！
    case semicolon = "semicolon"    // 分号 ；
    case colon = "colon"           // 冒号 ：
    case pause = "pause"           // 顿号 、
    
    var symbol: String {
        switch self {
        case .period: return "。"
        case .comma: return "，"
        case .question: return "？"
        case .exclamation: return "！"
        case .semicolon: return "；"
        case .colon: return "："
        case .pause: return "、"
        }
    }
    
    var displayName: String {
        switch self {
        case .period: return "句号"
        case .comma: return "逗号"
        case .question: return "问号"
        case .exclamation: return "感叹号"
        case .semicolon: return "分号"
        case .colon: return "冒号"
        case .pause: return "顿号"
        }
    }
}

/// 标点符号统计信息
struct PunctuationStatistics {
    var totalProcessed: Int = 0
    var punctuationAdded: [PunctuationType: Int] = [:]
    var averageProcessingTime: Double = 0.0
    var lastProcessedAt: Date?
    
    var totalPunctuationAdded: Int {
        return punctuationAdded.values.reduce(0, +)
    }
    
    var summary: String {
        let addedSummary = punctuationAdded.map { type, count in
            "\(type.displayName): \(count)个"
        }.joined(separator: ", ")
        
        return """
        标点处理统计:
        - 总处理数: \(totalProcessed)
        - 添加标点: \(totalPunctuationAdded)个
        - 详细统计: \(addedSummary)
        - 平均耗时: \(String(format: "%.2f", averageProcessingTime))ms
        """
    }
}

/// 标点规则匹配结果
struct PunctuationMatch {
    let position: String.Index
    let type: PunctuationType
    let confidence: Double
    let context: String
}

// MARK: - Punctuation Service Implementation

/// 标点符号处理服务实现
/// 基于语言规则和语义特征自动添加中文标点符号
class PunctuationService: ObservableObject, PunctuationServiceProtocol {
    
    // MARK: - Dependencies
    
    private let configManager: ConfigurationManagerProtocol
    private let logger = Logger(subsystem: "com.capswriter.punctuation", category: "PunctuationService")
    
    // MARK: - Published Properties
    
    @Published var isInitialized: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastError: Error?
    @Published var statistics = PunctuationStatistics()
    
    // MARK: - Private Properties
    
    private let processingQueue = DispatchQueue(label: "com.capswriter.punctuation", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    /// 当前处理强度
    private var currentIntensity: PunctuationIntensity = .medium
    
    /// 处理时间记录
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeRecords = 50
    
    // MARK: - Language Rules Configuration
    
    /// 句子结束标记词汇
    private let sentenceEndMarkers = [
        // 确定性结束词
        "了", "的", "吧", "呢", "啊", "哦", "嗯", "好",
        // 结论性词汇
        "总之", "因此", "所以", "总的来说", "综上所述",
        // 完成态词汇
        "完成", "结束", "完毕", "好了", "行了"
    ]
    
    /// 疑问句标记词汇
    private let questionMarkers = [
        "吗", "呢", "吧", "什么", "哪里", "为什么", "怎么", "怎样",
        "多少", "几", "谁", "哪个", "哪些", "是否", "可否", "能否"
    ]
    
    /// 感叹句标记词汇
    private let exclamationMarkers = [
        "太", "真", "好", "糟", "哇", "哎", "唉", "咦", "哈哈", "呵呵",
        "太棒了", "太好了", "太糟了", "真是", "简直", "居然"
    ]
    
    /// 停顿标记词汇（需要逗号）
    private let pauseMarkers = [
        "然后", "接着", "然而", "但是", "不过", "可是", "另外", "此外",
        "首先", "其次", "最后", "同时", "另一方面", "一方面"
    ]
    
    /// 冒号标记词汇
    private let colonMarkers = [
        "说", "讲", "表示", "认为", "指出", "提到", "强调", "解释说"
    ]
    
    // MARK: - Initialization
    
    init(configManager: ConfigurationManagerProtocol = DIContainer.shared.resolve(ConfigurationManagerProtocol.self)) {
        self.configManager = configManager
        
        // 初始化统计信息
        for type in PunctuationType.allCases {
            statistics.punctuationAdded[type] = 0
        }
        
        logger.info("🔤 PunctuationService 已创建")
    }
    
    // MARK: - ServiceLifecycleProtocol Implementation
    
    func initialize() throws {
        logger.info("🚀 初始化标点符号处理服务...")
        
        do {
            // 设置配置监听
            setupConfigurationObserver()
            
            // 从配置中获取处理强度
            loadIntensityFromConfiguration()
            
            isInitialized = true
            logger.info("✅ 标点符号处理服务初始化成功 (强度: \(currentIntensity.displayName))")
            
        } catch {
            logger.error("❌ 标点符号处理服务初始化失败: \(error.localizedDescription)")
            lastError = error
            throw error
        }
    }
    
    func start() throws {
        guard isInitialized else {
            throw PunctuationServiceError.serviceNotInitialized
        }
        
        isRunning = true
        logger.info("▶️ 标点符号处理服务已启动")
    }
    
    func stop() {
        isRunning = false
        logger.info("⏹️ 标点符号处理服务已停止")
    }
    
    func cleanup() {
        stop()
        cancellables.removeAll()
        
        isInitialized = false
        logger.info("🧹 标点符号处理服务已清理")
    }
    
    // MARK: - PunctuationServiceProtocol Implementation
    
    func processText(_ text: String) -> String {
        guard isRunning && !text.isEmpty else {
            return text
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = processingQueue.sync { [weak self] in
            return self?.performPunctuationProcessing(text) ?? text
        }
        
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        updateStatistics(originalText: text, processedText: result, processingTime: processingTime)
        
        return result
    }
    
    func getStatistics() -> PunctuationStatistics {
        return processingQueue.sync { [weak self] in
            return self?.statistics ?? PunctuationStatistics()
        }
    }
    
    func resetStatistics() {
        processingQueue.async { [weak self] in
            self?.statistics = PunctuationStatistics()
            for type in PunctuationType.allCases {
                self?.statistics.punctuationAdded[type] = 0
            }
            self?.processingTimes.removeAll()
            self?.logger.info("📊 标点符号处理统计已重置")
        }
    }
    
    func setPunctuationIntensity(_ intensity: PunctuationIntensity) {
        processingQueue.async { [weak self] in
            self?.currentIntensity = intensity
            self?.logger.info("⚙️ 标点处理强度已设置为: \(intensity.displayName)")
        }
    }
    
    // MARK: - Core Processing Logic
    
    private func performPunctuationProcessing(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果文本已经有标点符号，谨慎处理
        if hasExistingPunctuation(result) {
            logger.debug("🔍 文本已包含标点符号，跳过处理: \(text)")
            return text
        }
        
        // 根据处理强度应用不同的标点规则
        switch currentIntensity {
        case .light:
            result = applyLightPunctuation(result)
        case .medium:
            result = applyMediumPunctuation(result)
        case .heavy:
            result = applyHeavyPunctuation(result)
        }
        
        if result != text {
            logger.debug("🔤 标点处理: \"\(text)\" -> \"\(result)\"")
        }
        
        return result
    }
    
    private func applyLightPunctuation(_ text: String) -> String {
        var result = text
        
        // 仅在句子末尾添加句号
        if shouldAddPeriod(result) {
            result = addPunctuationAtEnd(result, type: .period)
        }
        
        return result
    }
    
    private func applyMediumPunctuation(_ text: String) -> String {
        var result = text
        
        // 1. 添加逗号（在停顿词后）
        result = addCommasAfterPauseMarkers(result)
        
        // 2. 处理句子结尾
        if shouldAddQuestionMark(result) {
            result = addPunctuationAtEnd(result, type: .question)
        } else if shouldAddExclamationMark(result) {
            result = addPunctuationAtEnd(result, type: .exclamation)
        } else if shouldAddPeriod(result) {
            result = addPunctuationAtEnd(result, type: .period)
        }
        
        return result
    }
    
    private func applyHeavyPunctuation(_ text: String) -> String {
        var result = text
        
        // 1. 添加冒号
        result = addColonsAfterMarkers(result)
        
        // 2. 添加逗号
        result = addCommasAfterPauseMarkers(result)
        
        // 3. 添加分号（在长句中间）
        result = addSemicolonsInLongSentences(result)
        
        // 4. 处理句子结尾
        if shouldAddQuestionMark(result) {
            result = addPunctuationAtEnd(result, type: .question)
        } else if shouldAddExclamationMark(result) {
            result = addPunctuationAtEnd(result, type: .exclamation)
        } else if shouldAddPeriod(result) {
            result = addPunctuationAtEnd(result, type: .period)
        }
        
        return result
    }
    
    // MARK: - Punctuation Detection Rules
    
    private func shouldAddPeriod(_ text: String) -> Bool {
        // 检查是否以陈述句结束词结尾
        let hasEndMarker = sentenceEndMarkers.contains { marker in
            text.hasSuffix(marker)
        }
        
        // 长文本默认需要句号（但不包含强烈情感词汇）
        let isLongStatement = text.count > 5 && !shouldAddExclamationMark(text) && !shouldAddQuestionMark(text)
        
        return hasEndMarker || isLongStatement
    }
    
    private func shouldAddQuestionMark(_ text: String) -> Bool {
        // 检查疑问词
        return questionMarkers.contains { marker in
            text.contains(marker)
        }
    }
    
    private func shouldAddExclamationMark(_ text: String) -> Bool {
        // 检查感叹词
        return exclamationMarkers.contains { marker in
            text.contains(marker)
        }
    }
    
    private func addCommasAfterPauseMarkers(_ text: String) -> String {
        var result = text
        
        for marker in pauseMarkers {
            // 查找停顿词，在其后添加逗号，但要确保词完整匹配
            if let range = result.range(of: marker) {
                // 确保是完整的词，而不是词的一部分
                let beforeIndex = range.lowerBound
                let afterIndex = range.upperBound
                
                // 检查前后是否为词边界
                let isWordBoundary = (beforeIndex == result.startIndex || 
                                    String(result[result.index(before: beforeIndex)]).rangeOfCharacter(from: .whitespacesAndNewlines) != nil) &&
                                   (afterIndex == result.endIndex ||
                                    String(result[afterIndex]).rangeOfCharacter(from: .whitespacesAndNewlines) != nil ||
                                    afterIndex < result.endIndex)
                
                if isWordBoundary && afterIndex < result.endIndex {
                    let nextChar = result[afterIndex]
                    // 如果后面不是标点符号且不是空格，添加逗号
                    if !nextChar.isPunctuation && nextChar != " " {
                        result.insert("，", at: afterIndex)
                        incrementPunctuationCount(.comma)
                    }
                }
            }
        }
        
        return result
    }
    
    private func addColonsAfterMarkers(_ text: String) -> String {
        var result = text
        
        for marker in colonMarkers {
            if let range = result.range(of: marker) {
                let insertIndex = range.upperBound
                if insertIndex < result.endIndex {
                    let nextChar = result[insertIndex]
                    if !nextChar.isPunctuation {
                        result.insert("：", at: insertIndex)
                        incrementPunctuationCount(.colon)
                    }
                }
            }
        }
        
        return result
    }
    
    private func addSemicolonsInLongSentences(_ text: String) -> String {
        var result = text
        
        // 在长句子中间添加分号（简单实现：每40个字符添加一个分号）
        if text.count > 40 {
            let midPoint = text.index(text.startIndex, offsetBy: text.count / 2)
            // 寻找附近的适当位置插入分号
            if let nearbySpace = findNearbySpaceOrPause(in: text, around: midPoint) {
                result.insert("；", at: nearbySpace)
                incrementPunctuationCount(.semicolon)
            }
        }
        
        return result
    }
    
    private func addPunctuationAtEnd(_ text: String, type: PunctuationType) -> String {
        var result = text
        result.append(type.symbol)
        incrementPunctuationCount(type)
        return result
    }
    
    // MARK: - Helper Methods
    
    private func hasExistingPunctuation(_ text: String) -> Bool {
        let chinesePunctuation = CharacterSet(charactersIn: "。，！？；：、\"\"''（）【】《》")
        return text.rangeOfCharacter(from: chinesePunctuation) != nil
    }
    
    private func findNearbySpaceOrPause(in text: String, around index: String.Index) -> String.Index? {
        let range = max(0, text.distance(from: text.startIndex, to: index) - 5)...
                   min(text.count - 1, text.distance(from: text.startIndex, to: index) + 5)
        
        for offset in range {
            let currentIndex = text.index(text.startIndex, offsetBy: offset)
            let char = text[currentIndex]
            if char == " " || pauseMarkers.contains(String(char)) {
                return currentIndex
            }
        }
        
        return nil
    }
    
    private func incrementPunctuationCount(_ type: PunctuationType) {
        statistics.punctuationAdded[type, default: 0] += 1
    }
    
    private func updateStatistics(originalText: String, processedText: String, processingTime: TimeInterval) {
        statistics.totalProcessed += 1
        statistics.lastProcessedAt = Date()
        
        // 更新平均处理时间
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingTimeRecords {
            processingTimes.removeFirst()
        }
        
        statistics.averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        
        // 发布统计更新
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: - Configuration Management
    
    private func setupConfigurationObserver() {
        configManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleConfigurationChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleConfigurationChange() {
        let config = configManager.textProcessing
        logger.info("⚙️ 标点处理配置已更新:")
        logger.info("   - 标点处理: \(config.enablePunctuation)")
        
        // 更新处理强度（从配置中读取，如果有的话）
        loadIntensityFromConfiguration()
    }
    
    private func loadIntensityFromConfiguration() {
        // 这里可以从配置中读取强度设置
        // 目前使用默认的 medium 强度
        currentIntensity = .medium
    }
}

// MARK: - ServiceStatusProtocol

extension PunctuationService: ServiceStatusProtocol {
    var statusDescription: String {
        let stats = getStatistics()
        return """
        标点符号处理服务状态:
        - 已初始化: \(isInitialized)
        - 运行中: \(isRunning)
        - 处理强度: \(currentIntensity.displayName)
        - \(stats.summary)
        """
    }
}

// MARK: - Error Types

enum PunctuationServiceError: Error, LocalizedError {
    case serviceNotInitialized
    case configurationError(String)
    case processingError(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "标点符号处理服务未初始化"
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .processingError(let message):
            return "处理错误: \(message)"
        }
    }
}

// MARK: - Character Extensions

private extension Character {
    var isPunctuation: Bool {
        let chinesePunctuation = CharacterSet(charactersIn: "。，！？；：、\"\"''（）【】《》")
        return String(self).rangeOfCharacter(from: chinesePunctuation) != nil ||
               String(self).rangeOfCharacter(from: .punctuationCharacters) != nil
    }
}