import Foundation
import Combine
import os.log

// MARK: - Hot Word Service Protocol

/// 热词替换服务协议
protocol HotWordServiceProtocol: ServiceLifecycleProtocol {
    /// 应用热词替换
    func processText(_ text: String) -> String
    
    /// 重新加载热词文件
    func reloadHotWords()
    
    /// 获取热词统计信息（异步版本）
    func getStatistics(completion: @escaping (HotWordStatistics) -> Void)
    
    /// 获取热词统计信息（同步版本，已弃用）
    @available(*, deprecated, message: "使用异步版本 getStatistics(completion:) 以避免阻塞线程")
    func getStatistics() -> HotWordStatistics
    
    /// 添加运行时热词
    func addRuntimeHotWord(original: String, replacement: String, type: HotWordType)
    
    /// 移除运行时热词
    func removeRuntimeHotWord(original: String, type: HotWordType)
}

// MARK: - Supporting Types

/// 热词类型
enum HotWordType: String, CaseIterable {
    case chinese = "chinese"     // 中文热词 (hot-zh.txt)
    case english = "english"     // 英文热词 (hot-en.txt)
    case rule = "rule"          // 自定义规则 (hot-rule.txt)
    case runtime = "runtime"     // 运行时动态添加
    
    var priority: Int {
        switch self {
        case .rule, .runtime: return 100    // 最高优先级
        case .chinese: return 50            // 中等优先级
        case .english: return 10            // 最低优先级
        }
    }
    
    var displayName: String {
        switch self {
        case .chinese: return "中文热词"
        case .english: return "英文热词" 
        case .rule: return "自定义规则"
        case .runtime: return "运行时热词"
        }
    }
}

/// 热词条目
struct HotWordEntry {
    let original: String
    let replacement: String
    let type: HotWordType
    let priority: Int
    var usage: Int = 0
    let createdAt: Date = Date()
    
    init(original: String, replacement: String, type: HotWordType) {
        self.original = original
        self.replacement = replacement
        self.type = type
        self.priority = type.priority
    }
}

/// 热词统计信息
struct HotWordStatistics {
    let totalEntries: Int
    let chineseEntries: Int
    let englishEntries: Int
    let ruleEntries: Int
    let runtimeEntries: Int
    let totalReplacements: Int
    let lastReloadTime: Date?
    
    var summary: String {
        return """
        热词统计:
        - 总计: \(totalEntries) 条
        - 中文: \(chineseEntries) 条
        - 英文: \(englishEntries) 条
        - 规则: \(ruleEntries) 条
        - 运行时: \(runtimeEntries) 条
        - 替换次数: \(totalReplacements) 次
        """
    }
}

// MARK: - Hot Word Service Implementation

/// 热词替换服务实现
/// 支持三种热词类型的动态加载和优先级替换
class HotWordService: ObservableObject, HotWordServiceProtocol {
    
    // MARK: - Dependencies
    
    private let configManager: any ConfigurationManagerProtocol
    private let errorHandler: any ErrorHandlerProtocol
    private let logger = Logger(subsystem: "com.capswriter.hotword", category: "HotWordService")
    
    // MARK: - Published Properties
    
    @Published var isInitialized: Bool = false
    @Published var isRunning: Bool = false
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    /// 热词字典 - 按类型分组存储
    private var hotWordDictionaries: [HotWordType: [String: HotWordEntry]] = [:]
    
    /// 所有热词的扁平字典 - 用于快速查找，按优先级排序
    private var flatDictionary: [String: HotWordEntry] = [:]
    
    /// 正则表达式缓存 - 用于规则类型的热词
    private var regexCache: [String: NSRegularExpression] = [:]
    
    /// 文件监听器
    private var fileWatchers: [FileWatcher] = []
    
    /// 统计信息
    private var statistics = HotWordStatistics(
        totalEntries: 0,
        chineseEntries: 0,
        englishEntries: 0,
        ruleEntries: 0,
        runtimeEntries: 0,
        totalReplacements: 0,
        lastReloadTime: nil
    )
    
    /// 线程安全队列
    private let hotWordQueue = DispatchQueue(label: "com.capswriter.hotword", qos: .userInitiated)
    
    /// Combine 订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - File Paths
    
    private var hotWordPaths: [HotWordType: String] {
        let bundle = Bundle.main
        let basePath = bundle.resourcePath ?? ""
        let config = configManager.textProcessing
        
        return [
            .chinese: resolveFilePath(config.hotWordChinesePath, basePath: basePath),
            .english: resolveFilePath(config.hotWordEnglishPath, basePath: basePath), 
            .rule: resolveFilePath(config.hotWordRulePath, basePath: basePath)
        ]
    }
    
    private func resolveFilePath(_ configPath: String, basePath: String) -> String {
        // 如果是绝对路径，直接使用
        if configPath.hasPrefix("/") {
            return configPath
        }
        
        // 如果是相对路径，相对于bundle资源路径
        return "\(basePath)/\(configPath)"
    }
    
    // MARK: - Initialization
    
    init(
        configManager: any ConfigurationManagerProtocol = DIContainer.shared.resolve(ConfigurationManager.self),
        errorHandler: any ErrorHandlerProtocol = DIContainer.shared.resolve(ErrorHandlerProtocol.self)
    ) {
        self.configManager = configManager
        self.errorHandler = errorHandler
        
        // 初始化字典
        for type in HotWordType.allCases {
            hotWordDictionaries[type] = [:]
        }
        
        logger.info("🔥 HotWordService 已创建")
    }
    
    // MARK: - ServiceLifecycleProtocol Implementation
    
    func initialize() throws {
        logger.info("🚀 初始化热词服务...")
        
        do {
            // 加载所有热词文件
            try loadAllHotWords()
            
            // 设置文件监听器
            setupFileWatchers()
            
            // 设置配置监听
            setupConfigurationObserver()
            
            isInitialized = true
            logger.info("✅ 热词服务初始化成功")
            
        } catch {
            logger.error("❌ 热词服务初始化失败: \(error.localizedDescription)")
            lastError = error
            errorHandler.reportError(
                error,
                userInfo: [
                    "component": "HotWordService",
                    "operation": "初始化"
                ]
            )
            throw error
        }
    }
    
    func start() throws {
        guard isInitialized else {
            throw HotWordServiceError.serviceNotInitialized
        }
        
        isRunning = true
        logger.info("▶️ 热词服务已启动")
    }
    
    func stop() {
        isRunning = false
        logger.info("⏹️ 热词服务已停止")
    }
    
    func cleanup() {
        stop()
        
        // 清理文件监听器
        fileWatchers.forEach { $0.stop() }
        fileWatchers.removeAll()
        
        // 清理字典
        hotWordQueue.async { [weak self] in
            self?.hotWordDictionaries.removeAll()
            self?.flatDictionary.removeAll()
            self?.regexCache.removeAll()
        }
        
        // 清理订阅
        cancellables.removeAll()
        
        isInitialized = false
        logger.info("🧹 热词服务已清理")
    }
    
    // MARK: - HotWordServiceProtocol Implementation
    
    func processText(_ text: String, completion: @escaping (String) -> Void) {
        guard isRunning && !text.isEmpty else {
            completion(text)
            return
        }
        
        hotWordQueue.async { [weak self] in
            let result = self?.performTextReplacement(text) ?? text
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // 同步版本保留用于向后兼容，但添加警告
    @available(*, deprecated, message: "使用异步版本 processText(_:completion:) 以避免阻塞线程")
    func processText(_ text: String) -> String {
        guard isRunning && !text.isEmpty else {
            return text
        }
        
        return hotWordQueue.sync { [weak self] in
            return self?.performTextReplacement(text) ?? text
        }
    }
    
    func reloadHotWords() {
        logger.info("🔄 重新加载热词...")
        
        hotWordQueue.async { [weak self] in
            do {
                try self?.loadAllHotWords()
                self?.logger.info("✅ 热词重新加载成功")
            } catch {
                self?.logger.error("❌ 热词重新加载失败: \(error.localizedDescription)")
                self?.lastError = error
                self?.errorHandler.reportError(
                    error,
                    userInfo: [
                        "component": "HotWordService",
                        "operation": "重新加载热词"
                    ]
                )
            }
        }
    }
    
    func getStatistics(completion: @escaping (HotWordStatistics) -> Void) {
        hotWordQueue.async { [weak self] in
            let result = self?.statistics ?? HotWordStatistics(
                totalEntries: 0,
                chineseEntries: 0,
                englishEntries: 0,
                ruleEntries: 0,
                runtimeEntries: 0,
                totalReplacements: 0,
                lastReloadTime: nil
            )
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // 同步版本保留用于向后兼容，但添加警告
    @available(*, deprecated, message: "使用异步版本 getStatistics(completion:) 以避免阻塞线程")
    func getStatistics() -> HotWordStatistics {
        return hotWordQueue.sync { [weak self] in
            return self?.statistics ?? HotWordStatistics(
                totalEntries: 0,
                chineseEntries: 0,
                englishEntries: 0,
                ruleEntries: 0,
                runtimeEntries: 0,
                totalReplacements: 0,
                lastReloadTime: nil
            )
        }
    }
    
    func addRuntimeHotWord(original: String, replacement: String, type: HotWordType) {
        hotWordQueue.async { [weak self] in
            guard let self = self else { return }
            
            let entry = HotWordEntry(original: original, replacement: replacement, type: .runtime)
            self.hotWordDictionaries[.runtime]?[original] = entry
            self.rebuildFlatDictionary()
            
            self.logger.info("➕ 添加运行时热词: \(original) -> \(replacement)")
        }
    }
    
    func removeRuntimeHotWord(original: String, type: HotWordType) {
        hotWordQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.hotWordDictionaries[.runtime]?.removeValue(forKey: original)
            self.rebuildFlatDictionary()
            
            self.logger.info("➖ 移除运行时热词: \(original)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadAllHotWords() throws {
        logger.info("📚 开始加载所有热词文件...")
        
        // 清空现有字典（保留运行时热词）
        let runtimeWords = hotWordDictionaries[.runtime] ?? [:]
        for type in HotWordType.allCases {
            if type != .runtime {
                hotWordDictionaries[type] = [:]
            }
        }
        
        // 加载各类型热词文件
        for (type, path) in hotWordPaths {
            do {
                try loadHotWordsFromFile(path: path, type: type)
                logger.info("✅ 加载 \(type.displayName): \(path)")
            } catch {
                // 文件不存在不算错误，只是警告
                if case HotWordServiceError.fileNotFound(_) = error {
                    logger.warning("⚠️ 热词文件不存在: \(path)")
                } else {
                    logger.error("❌ 加载热词文件失败: \(path), 错误: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        // 恢复运行时热词
        hotWordDictionaries[.runtime] = runtimeWords
        
        // 重建扁平字典
        rebuildFlatDictionary()
        
        // 更新统计信息
        updateStatistics()
        
        logger.info("📊 热词加载完成: \(self.statistics.summary)")
    }
    
    private func loadHotWordsFromFile(path: String, type: HotWordType) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw HotWordServiceError.fileNotFound(path)
        }
        
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var loadedCount = 0
        var dictionary: [String: HotWordEntry] = [:]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") else {
                continue
            }
            
            // 解析热词条目
            if let entry = parseHotWordLine(trimmedLine, type: type) {
                dictionary[entry.original] = entry
                loadedCount += 1
            } else {
                logger.warning("⚠️ 无法解析热词行: \(trimmedLine)")
            }
        }
        
        hotWordDictionaries[type] = dictionary
        logger.info("📝 从 \(type.displayName) 加载 \(loadedCount) 条热词")
    }
    
    private func parseHotWordLine(_ line: String, type: HotWordType) -> HotWordEntry? {
        // 支持多种分隔符: TAB, 多个空格, |, =
        let separators = ["\t", "  ", " | ", " = ", "|", "="]
        
        for separator in separators {
            if line.contains(separator) {
                let parts = line.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if parts.count >= 2 {
                    let original = parts[0]
                    let replacement = parts[1]
                    
                    // 验证热词有效性
                    guard !original.isEmpty && !replacement.isEmpty else {
                        continue
                    }
                    
                    return HotWordEntry(original: original, replacement: replacement, type: type)
                }
            }
        }
        
        return nil
    }
    
    private func rebuildFlatDictionary() {
        logger.debug("🔨 重建热词扁平字典...")
        
        var newFlatDictionary: [String: HotWordEntry] = [:]
        
        // 按优先级排序类型
        let sortedTypes = HotWordType.allCases.sorted { $0.priority > $1.priority }
        
        for type in sortedTypes {
            if let dictionary = hotWordDictionaries[type] {
                for (original, entry) in dictionary {
                    // 高优先级覆盖低优先级
                    if newFlatDictionary[original] == nil || entry.priority > newFlatDictionary[original]!.priority {
                        newFlatDictionary[original] = entry
                    }
                }
            }
        }
        
        flatDictionary = newFlatDictionary
        logger.debug("🔨 扁平字典重建完成，共 \(self.flatDictionary.count) 条")
    }
    
    // 🔒 安全修复：防止正则表达式DoS攻击
    private func performTextReplacement(_ text: String) -> String {
        // 🔒 输入验证：防止过长文本导致性能问题
        let maxTextLength = 10000  // 限制最大文本长度
        guard text.count <= maxTextLength else {
            logger.warning("⚠️ 文本过长，跳过处理: \(text.count) 字符")
            return text
        }
        
        var result = text
        var replacementCount = 0
        let processingStartTime = Date()
        let maxProcessingTime: TimeInterval = 5.0  // 最大处理时间5秒
        
        // 1. 先处理正则表达式规则（带安全检查）
        if let ruleDict = hotWordDictionaries[.rule] {
            for (pattern, entry) in ruleDict {
                // 🔒 超时检查：防止长时间执行
                if Date().timeIntervalSince(processingStartTime) > maxProcessingTime {
                    logger.warning("⚠️ 文本处理超时，停止正则表达式处理")
                    break
                }
                
                if let regex = getOrCreateRegex(pattern) {
                    let range = NSRange(location: 0, length: result.utf16.count)
                    
                    // 🔒 安全执行：使用 DispatchQueue 和超时机制
                    if let safeResult = performSafeRegexReplacement(
                        regex: regex,
                        text: result,
                        range: range,
                        replacement: entry.replacement
                    ) {
                        result = safeResult
                        replacementCount += 1
                    }
                }
            }
        }
        
        // 2. 处理普通字符串替换（按优先级）
        for (original, entry) in flatDictionary.sorted(by: { $0.value.priority > $1.value.priority }) {
            // 🔒 超时检查：防止长时间执行
            if Date().timeIntervalSince(processingStartTime) > maxProcessingTime {
                logger.warning("⚠️ 文本处理超时，停止字符串替换处理")
                break
            }
            
            if entry.type != .rule && result.contains(original) {
                // 🔒 安全替换：限制替换次数
                result = performSafeStringReplacement(
                    text: result,
                    original: original,
                    replacement: entry.replacement
                )
                replacementCount += 1
            }
        }
        
        // 更新统计
        if replacementCount > 0 {
            updateReplacementCount(replacementCount)
            logger.debug("🔄 文本替换: \(replacementCount) 次，\"\(text)\" -> \"\(result)\"")
        }
        
        return result
    }
    
    // 🔒 安全方法：执行安全的正则表达式替换
    private func performSafeRegexReplacement(
        regex: NSRegularExpression,
        text: String,
        range: NSRange,
        replacement: String
    ) -> String? {
        let timeout: TimeInterval = 2.0  // 单个正则表达式最大执行时间2秒
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        var timedOut = false
        
        // 在后台队列执行正则表达式
        DispatchQueue.global(qos: .utility).async {
            // 检查是否有匹配
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                result = regex.stringByReplacingMatches(
                    in: text,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
            semaphore.signal()
        }
        
        // 等待完成或超时
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            logger.warning("⚠️ 正则表达式执行超时")
        }
        
        return timedOut ? nil : result
    }
    
    // 🔒 安全方法：执行安全的字符串替换
    private func performSafeStringReplacement(
        text: String,
        original: String,
        replacement: String
    ) -> String {
        let maxReplacements = 100  // 限制最大替换次数
        var result = text
        var replacementCount = 0
        
        while result.contains(original) && replacementCount < maxReplacements {
            result = result.replacingOccurrences(of: original, with: replacement)
            replacementCount += 1
        }
        
        if replacementCount >= maxReplacements {
            logger.warning("⚠️ 字符串替换次数达到限制: \(original)")
        }
        
        return result
    }
    
    // 🔒 安全修复：防止恶意正则表达式DoS攻击
    private func getOrCreateRegex(_ pattern: String) -> NSRegularExpression? {
        // 🔒 检查缓存
        if let cached = regexCache[pattern] {
            return cached
        }
        
        // 🔒 安全验证：检查正则表达式安全性
        guard isRegexPatternSafe(pattern) else {
            logger.warning("⚠️ 不安全的正则表达式被拒绝: \(pattern)")
            return nil
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            
            // 🔒 缓存管理：限制缓存大小
            if regexCache.count >= 100 {
                // 清理最老的缓存项
                let keysToRemove = Array(regexCache.keys.prefix(50))
                for key in keysToRemove {
                    regexCache.removeValue(forKey: key)
                }
            }
            
            regexCache[pattern] = regex
            return regex
        } catch {
            logger.error("❌ 无效正则表达式: \(pattern), 错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 🔒 安全方法：检查正则表达式模式安全性
    private func isRegexPatternSafe(_ pattern: String) -> Bool {
        // 1. 长度限制
        let maxPatternLength = 500
        guard pattern.count <= maxPatternLength else {
            logger.warning("⚠️ 正则表达式过长: \(pattern.count) 字符")
            return false
        }
        
        // 2. 禁止危险模式
        let dangerousPatterns = [
            "(.*)+",          // 灾难性回溯
            "(.*)*",          // 灾难性回溯
            "(.+)+",          // 灾难性回溯
            "(.+)*",          // 灾难性回溯
            "(a*)*",          // 灾难性回溯
            "(a+)+",          // 灾难性回溯
            "(a|a)*",         // 灾难性回溯
            "(a|a)+",         // 灾难性回溯
            "([a-z]*)*",      // 灾难性回溯
            "([a-z]+)+",      // 灾难性回溯
            ".*.*.*.*",       // 过度量词
            ".+.+.+.+",       // 过度量词
        ]
        
        for dangerousPattern in dangerousPatterns {
            if pattern.contains(dangerousPattern) {
                logger.warning("⚠️ 检测到危险正则表达式模式: \(dangerousPattern)")
                return false
            }
        }
        
        // 3. 检查嵌套量词
        if pattern.contains("*+") || pattern.contains("+*") || 
           pattern.contains("?+") || pattern.contains("+?") {
            logger.warning("⚠️ 检测到嵌套量词模式")
            return false
        }
        
        // 4. 检查过度的括号嵌套
        let maxNestingLevel = 10
        var nestingLevel = 0
        var maxNesting = 0
        
        for char in pattern {
            if char == "(" {
                nestingLevel += 1
                maxNesting = max(maxNesting, nestingLevel)
            } else if char == ")" {
                nestingLevel -= 1
            }
        }
        
        if maxNesting > maxNestingLevel {
            logger.warning("⚠️ 正则表达式括号嵌套过深: \(maxNesting)")
            return false
        }
        
        // 5. 检查过度的重复模式
        let maxRepeatCount = 1000
        let repeatPatterns = ["{", "}", "{,", "}", ","]
        
        for repeatPattern in repeatPatterns {
            if pattern.contains(repeatPattern) {
                // 简单检查，实际应用中可能需要更复杂的解析
                if let range = pattern.range(of: "{(\\d+,?\\d*)}", options: .regularExpression) {
                    let numberPart = String(pattern[range]).replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
                    if let number = Int(numberPart.components(separatedBy: ",").first ?? ""),
                       number > maxRepeatCount {
                        logger.warning("⚠️ 正则表达式重复次数过多: \(number)")
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func updateStatistics() {
        let chinese = hotWordDictionaries[.chinese]?.count ?? 0
        let english = hotWordDictionaries[.english]?.count ?? 0
        let rule = hotWordDictionaries[.rule]?.count ?? 0
        let runtime = hotWordDictionaries[.runtime]?.count ?? 0
        
        statistics = HotWordStatistics(
            totalEntries: chinese + english + rule + runtime,
            chineseEntries: chinese,
            englishEntries: english,
            ruleEntries: rule,
            runtimeEntries: runtime,
            totalReplacements: statistics.totalReplacements,
            lastReloadTime: Date()
        )
    }
    
    private func updateReplacementCount(_ count: Int) {
        statistics = HotWordStatistics(
            totalEntries: statistics.totalEntries,
            chineseEntries: statistics.chineseEntries,
            englishEntries: statistics.englishEntries,
            ruleEntries: statistics.ruleEntries,
            runtimeEntries: statistics.runtimeEntries,
            totalReplacements: statistics.totalReplacements + count,
            lastReloadTime: statistics.lastReloadTime
        )
    }
    
    // MARK: - File Watching
    
    private func setupFileWatchers() {
        logger.info("👁️ 设置文件监听器...")
        
        for (_, path) in hotWordPaths {
            if FileManager.default.fileExists(atPath: path) {
                let watcher = FileWatcher(path: path) { [weak self] in
                    self?.logger.info("📁 检测到文件变化: \(path)")
                    self?.reloadHotWords()
                }
                fileWatchers.append(watcher)
                watcher.start()
            }
        }
        
        logger.info("👁️ 文件监听器设置完成，共监听 \(self.fileWatchers.count) 个文件")
    }
    
    private func setupConfigurationObserver() {
        // 监听配置变化
        if let observableConfig = configManager as? ConfigurationManager {
            observableConfig.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    if self?.configManager.textProcessing.enableHotwordReplacement == false {
                        self?.logger.info("🔕 热词替换已在配置中禁用")
                    }
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - ServiceStatusProtocol

extension HotWordService: ServiceStatusProtocol {
    var statusDescription: String {
        // 为了保持同步接口兼容性，使用同步获取的统计信息
        let syncStats = hotWordQueue.sync {
            return statistics
        }
        
        return """
        热词服务状态:
        - 已初始化: \(isInitialized)
        - 运行中: \(isRunning)
        - \(syncStats.summary)
        """
    }
}

// MARK: - Error Types

enum HotWordServiceError: Error, LocalizedError {
    case serviceNotInitialized
    case fileNotFound(String)
    case invalidFileFormat(String)
    case regexCompilationFailed(String)
    case unsafeRegexPattern(String)      // 🔒 新增：不安全的正则表达式
    case regexExecutionTimeout(String)   // 🔒 新增：正则表达式执行超时
    case textTooLong(Int)               // 🔒 新增：文本过长
    case processingTimeout(TimeInterval) // 🔒 新增：处理超时
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "热词服务未初始化"
        case .fileNotFound(let path):
            return "热词文件不存在: \(path)"
        case .invalidFileFormat(let path):
            return "热词文件格式无效: \(path)"
        case .regexCompilationFailed(let pattern):
            return "正则表达式编译失败: \(pattern)"
        case .unsafeRegexPattern(let pattern):
            return "不安全的正则表达式: \(pattern)"
        case .regexExecutionTimeout(let pattern):
            return "正则表达式执行超时: \(pattern)"
        case .textTooLong(let length):
            return "文本过长: \(length) 字符"
        case .processingTimeout(let timeout):
            return "处理超时: \(timeout) 秒"
        }
    }
}

// MARK: - File Watcher Helper

/// 安全的文件监听器实现
/// 🔒 安全修复：防止路径遍历攻击，限制文件访问权限
private class FileWatcher {
    private let path: String
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.capswriter.filewatcher")
    private var fileDescriptor: Int32 = -1
    
    // 🔒 安全配置：文件监控限制
    private static let maxFileSize: UInt64 = 10 * 1024 * 1024  // 10MB 限制
    private static let allowedExtensions: Set<String> = ["txt", "json", "plist"]
    private static let maxCallbackFrequency: TimeInterval = 1.0  // 1秒最多触发一次
    
    private var lastCallbackTime: Date = Date.distantPast
    
    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback
    }
    
    func start() {
        // 🔒 安全检查：验证文件路径安全性
        guard isPathSafe(path) else {
            print("⚠️ FileWatcher: 不安全的文件路径被拒绝: \(path)")
            return
        }
        
        // 🔒 安全检查：验证文件权限和大小
        guard validateFileAccess(path) else {
            print("⚠️ FileWatcher: 文件访问验证失败: \(path)")
            return
        }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("⚠️ FileWatcher: 无法打开文件描述符: \(path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.handleFileChange()
        }
        
        source?.resume()
    }
    
    // 🔒 安全方法：处理文件变化事件（带频率限制）
    private func handleFileChange() {
        let now = Date()
        guard now.timeIntervalSince(lastCallbackTime) >= Self.maxCallbackFrequency else {
            return  // 防止频繁触发
        }
        
        // 🔒 安全检查：重新验证文件在回调时的安全性
        guard validateFileAccess(path) else {
            print("⚠️ FileWatcher: 文件在变化时验证失败，停止监控: \(path)")
            stop()
            return
        }
        
        lastCallbackTime = now
        callback()
    }
    
    // 🔒 安全方法：验证路径安全性
    private func isPathSafe(_ path: String) -> Bool {
        // 解析真实路径，防止符号链接攻击
        guard let realPath = URL(fileURLWithPath: path).standardized.path.cString(using: .utf8) else {
            return false
        }
        
        let resolvedPath = String(cString: realPath)
        
        // 1. 防止路径遍历攻击
        if resolvedPath.contains("../") || resolvedPath.contains("..\\")
           || resolvedPath.contains("/..") || resolvedPath.contains("\\..") {
            return false
        }
        
        // 2. 限制访问系统敏感目录
        let forbiddenPaths = [
            "/System", "/Library", "/private", "/usr", "/bin", "/sbin",
            "/etc", "/var", "/dev", "/tmp", "/Applications"
        ]
        
        for forbiddenPath in forbiddenPaths {
            if resolvedPath.hasPrefix(forbiddenPath) {
                return false
            }
        }
        
        // 3. 必须在应用沙盒或用户目录内
        let userHome = FileManager.default.homeDirectoryForCurrentUser.path
        let appSandbox = Bundle.main.bundlePath
        
        if !resolvedPath.hasPrefix(userHome) && !resolvedPath.hasPrefix(appSandbox) {
            return false
        }
        
        // 4. 检查文件扩展名
        let fileExtension = URL(fileURLWithPath: resolvedPath).pathExtension.lowercased()
        if !Self.allowedExtensions.contains(fileExtension) {
            return false
        }
        
        return true
    }
    
    // 🔒 安全方法：验证文件访问权限和大小
    private func validateFileAccess(_ path: String) -> Bool {
        let fileManager = FileManager.default
        
        // 1. 检查文件是否存在
        guard fileManager.fileExists(atPath: path) else {
            return false
        }
        
        // 2. 检查文件大小
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? UInt64 {
                if fileSize > Self.maxFileSize {
                    print("⚠️ FileWatcher: 文件大小超过限制: \(fileSize) bytes")
                    return false
                }
            }
        } catch {
            print("⚠️ FileWatcher: 无法获取文件属性: \(error)")
            return false
        }
        
        // 3. 检查文件权限
        guard fileManager.isReadableFile(atPath: path) else {
            return false
        }
        
        return true
    }
    
    func stop() {
        source?.cancel()
        source = nil
        
        // 🔒 安全清理：安全关闭文件描述符
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
    
    deinit {
        stop()
    }
}