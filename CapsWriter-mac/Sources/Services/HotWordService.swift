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
    
    /// 获取热词统计信息
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
    
    private let configManager: ConfigurationManagerProtocol
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
    
    init(configManager: ConfigurationManagerProtocol = DIContainer.shared.resolve(ConfigurationManagerProtocol.self)) {
        self.configManager = configManager
        
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
            }
        }
    }
    
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
                if (error as NSError).code == NSFileReadNoSuchFileError {
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
        
        logger.info("📊 热词加载完成: \(statistics.summary)")
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
        logger.debug("🔨 扁平字典重建完成，共 \(flatDictionary.count) 条")
    }
    
    private func performTextReplacement(_ text: String) -> String {
        var result = text
        var replacementCount = 0
        
        // 1. 先处理正则表达式规则
        if let ruleDict = hotWordDictionaries[.rule] {
            for (pattern, entry) in ruleDict {
                if let regex = getOrCreateRegex(pattern) {
                    let range = NSRange(location: 0, length: result.utf16.count)
                    if regex.firstMatch(in: result, options: [], range: range) != nil {
                        result = regex.stringByReplacingMatches(
                            in: result,
                            options: [],
                            range: range,
                            withTemplate: entry.replacement
                        )
                        replacementCount += 1
                    }
                }
            }
        }
        
        // 2. 处理普通字符串替换（按优先级）
        for (original, entry) in flatDictionary.sorted(by: { $0.value.priority > $1.value.priority }) {
            if entry.type != .rule && result.contains(original) {
                result = result.replacingOccurrences(of: original, with: entry.replacement)
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
    
    private func getOrCreateRegex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] {
            return cached
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            regexCache[pattern] = regex
            return regex
        } catch {
            logger.error("❌ 无效正则表达式: \(pattern), 错误: \(error.localizedDescription)")
            return nil
        }
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
        
        for (type, path) in hotWordPaths {
            if FileManager.default.fileExists(atPath: path) {
                let watcher = FileWatcher(path: path) { [weak self] in
                    self?.logger.info("📁 检测到文件变化: \(path)")
                    self?.reloadHotWords()
                }
                fileWatchers.append(watcher)
                watcher.start()
            }
        }
        
        logger.info("👁️ 文件监听器设置完成，共监听 \(fileWatchers.count) 个文件")
    }
    
    private func setupConfigurationObserver() {
        // 监听配置变化
        configManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                if self?.configManager.textProcessing.enableHotwordReplacement == false {
                    self?.logger.info("🔕 热词替换已在配置中禁用")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - ServiceStatusProtocol

extension HotWordService: ServiceStatusProtocol {
    var statusDescription: String {
        let stats = getStatistics()
        return """
        热词服务状态:
        - 已初始化: \(isInitialized)
        - 运行中: \(isRunning)
        - \(stats.summary)
        """
    }
}

// MARK: - Error Types

enum HotWordServiceError: Error, LocalizedError {
    case serviceNotInitialized
    case fileNotFound(String)
    case invalidFileFormat(String)
    case regexCompilationFailed(String)
    
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
        }
    }
}

// MARK: - File Watcher Helper

/// 简单的文件监听器实现
private class FileWatcher {
    private let path: String
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.capswriter.filewatcher")
    
    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback
    }
    
    func start() {
        guard let descriptor = open(path, O_EVTONLY) else {
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.callback()
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stop()
    }
}