//
//  LoggingService.swift
//  CapsWriter-mac
//
//  Created by Claude on 2025-01-18.
//  日志系统完善 - 任务3.3 结构化日志服务
//

import Foundation
import os.log

// MARK: - 日志级别定义

/// 日志级别枚举
enum LogLevel: String, CaseIterable, Comparable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    /// 级别优先级（用于比较和过滤）
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
    
    /// 级别显示颜色（控制台输出）
    var colorCode: String {
        switch self {
        case .debug: return "\u{001B}[36m"    // 青色
        case .info: return "\u{001B}[32m"     // 绿色
        case .warning: return "\u{001B}[33m"  // 黄色
        case .error: return "\u{001B}[31m"    // 红色
        case .critical: return "\u{001B}[35m" // 紫色
        }
    }
    
    /// 重置颜色代码
    static let resetColor = "\u{001B}[0m"
    
    /// 级别比较
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - 日志分类定义

/// 日志分类枚举
enum LogCategory: String, CaseIterable, Codable {
    case audio = "AUDIO"          // 音频处理
    case recognition = "ASR"      // 语音识别
    case hotword = "HOTWORD"      // 热词替换
    case ui = "UI"                // 界面操作
    case system = "SYSTEM"        // 系统事件
    case network = "NETWORK"      // 网络通信
    case file = "FILE"            // 文件操作
    case keyboard = "KEYBOARD"    // 键盘监听
    case config = "CONFIG"        // 配置管理
    case service = "SERVICE"      // 服务管理
    
    /// 分类图标（用于UI显示）
    var icon: String {
        switch self {
        case .audio: return "🎵"
        case .recognition: return "🗣️"
        case .hotword: return "🔄"
        case .ui: return "🖥️"
        case .system: return "⚙️"
        case .network: return "🌐"
        case .file: return "📁"
        case .keyboard: return "⌨️"
        case .config: return "🔧"
        case .service: return "🚀"
        }
    }
}

// MARK: - 日志条目结构

/// 日志条目结构
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int
    let thread: String
    
    /// 初始化日志条目
    init(level: LogLevel, category: LogCategory, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.thread = Thread.isMainThread ? "Main" : "Background"
    }
    
    /// 格式化时间戳
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    /// 完整格式化的日志字符串
    var formattedString: String {
        let levelStr = level.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
        let categoryStr = category.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "[\(formattedTimestamp)] [\(levelStr)] [\(categoryStr)] \(message) (\(file):\(line))"
    }
    
    /// 带颜色的控制台输出格式
    var coloredConsoleString: String {
        let levelStr = level.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
        let categoryStr = category.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "\(level.colorCode)[\(formattedTimestamp)] [\(levelStr)] [\(categoryStr)] \(message)\(LogLevel.resetColor) (\(file):\(line))"
    }
}

// MARK: - 日志输出目标

/// 日志输出目标枚举
enum LogDestination {
    case console     // 控制台输出
    case file       // 文件存储
    case memory     // 内存缓存(用于UI显示)
    case system     // 系统日志(os_log)
}

// MARK: - 日志服务协议

/// 日志服务协议
protocol LoggingServiceProtocol {
    /// 记录日志
    func log(_ level: LogLevel, category: LogCategory, message: String, file: String, function: String, line: Int)
    
    /// 便捷方法
    func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func info(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func error(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func critical(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// 日志管理
    func clearLogs()
    func getLogs(level: LogLevel?, category: LogCategory?, limit: Int?) -> [LogEntry]
    func getLogsCount() -> Int
    
    /// 配置管理
    func setMinLogLevel(_ level: LogLevel)
    func enableDestination(_ destination: LogDestination)
    func disableDestination(_ destination: LogDestination)
}

// MARK: - 日志服务实现

/// 日志服务实现类
class LoggingService: LoggingServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LoggingService()
    
    private init() {
        setupLogDestinations()
        setupFileLogging()
        print("📋 LoggingService 已初始化")
    }
    
    // MARK: - Private Properties
    
    /// 内存中的日志缓存
    @Published private var memoryLogs: [LogEntry] = []
    
    /// 最小日志级别
    private var minLogLevel: LogLevel = .debug
    
    /// 启用的输出目标
    private var enabledDestinations: Set<LogDestination> = [.console, .memory, .system]
    
    /// 线程安全队列
    private let loggingQueue = DispatchQueue(label: "com.capswriter.logging", qos: .utility)
    
    /// 系统日志器
    private let osLog = OSLog(subsystem: "com.capswriter.mac", category: "general")
    
    /// 文件日志器
    private var fileLogURL: URL?
    
    /// 最大内存日志条数
    private let maxMemoryLogs = 1000
    
    /// 最大文件大小（字节）
    private let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    
    // MARK: - Setup Methods
    
    /// 设置日志输出目标
    private func setupLogDestinations() {
        // 根据配置管理器的设置来确定启用的输出目标
        if let configManager = DIContainer.shared.resolve(ConfigurationManagerProtocol.self) {
            // 从配置中读取日志设置
            let debugMode = configManager.debug.enableVerboseLogging
            
            if debugMode {
                enabledDestinations.insert(.console)
                enabledDestinations.insert(.file)
                minLogLevel = .debug
            } else {
                enabledDestinations.remove(.console)
                minLogLevel = .info
            }
        }
    }
    
    /// 设置文件日志
    private func setupFileLogging() {
        guard enabledDestinations.contains(.file) else { return }
        
        let logDirectory = getLogDirectory()
        let logFileName = "capswriter-\(getDateString()).log"
        fileLogURL = logDirectory.appendingPathComponent(logFileName)
        
        // 创建日志目录
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // 清理旧日志文件
        cleanOldLogFiles()
    }
    
    /// 获取日志目录
    private func getLogDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CapsWriter-mac/Logs")
    }
    
    /// 获取日期字符串
    private func getDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// 清理旧日志文件（保留最近7天）
    private func cleanOldLogFiles() {
        let logDirectory = getLogDirectory()
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            // 忽略清理错误
        }
    }
    
    // MARK: - Public Interface
    
    /// 获取内存中的日志（用于UI显示）
    var logs: [LogEntry] {
        return memoryLogs
    }
    
    // MARK: - LoggingServiceProtocol Implementation
    
    func log(_ level: LogLevel, category: LogCategory, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // 级别过滤
        guard level >= minLogLevel else { return }
        
        let entry = LogEntry(level: level, category: category, message: message, file: file, function: function, line: line)
        
        loggingQueue.async { [weak self] in
            self?.processLogEntry(entry)
        }
    }
    
    func debug(_ message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message: message, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message: message, file: file, function: function, line: line)
    }
    
    func clearLogs() {
        loggingQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.memoryLogs.removeAll()
            }
        }
    }
    
    func getLogs(level: LogLevel? = nil, category: LogCategory? = nil, limit: Int? = nil) -> [LogEntry] {
        var filteredLogs = memoryLogs
        
        // 级别过滤
        if let level = level {
            filteredLogs = filteredLogs.filter { $0.level >= level }
        }
        
        // 分类过滤
        if let category = category {
            filteredLogs = filteredLogs.filter { $0.category == category }
        }
        
        // 数量限制
        if let limit = limit {
            filteredLogs = Array(filteredLogs.suffix(limit))
        }
        
        return filteredLogs
    }
    
    func getLogsCount() -> Int {
        return memoryLogs.count
    }
    
    func setMinLogLevel(_ level: LogLevel) {
        minLogLevel = level
    }
    
    func enableDestination(_ destination: LogDestination) {
        enabledDestinations.insert(destination)
        if destination == .file {
            setupFileLogging()
        }
    }
    
    func disableDestination(_ destination: LogDestination) {
        enabledDestinations.remove(destination)
    }
    
    // MARK: - Private Methods
    
    /// 处理日志条目
    private func processLogEntry(_ entry: LogEntry) {
        // 输出到各个目标
        for destination in enabledDestinations {
            outputToDestination(entry, destination: destination)
        }
    }
    
    /// 输出到指定目标
    private func outputToDestination(_ entry: LogEntry, destination: LogDestination) {
        switch destination {
        case .console:
            outputToConsole(entry)
        case .file:
            outputToFile(entry)
        case .memory:
            outputToMemory(entry)
        case .system:
            outputToSystemLog(entry)
        }
    }
    
    /// 输出到控制台
    private func outputToConsole(_ entry: LogEntry) {
        print(entry.coloredConsoleString)
    }
    
    /// 输出到文件
    private func outputToFile(_ entry: LogEntry) {
        guard let fileURL = fileLogURL else { return }
        
        // 检查文件大小，如果超过限制则轮转
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64,
           fileSize > maxFileSize {
            rotateLogFile()
        }
        
        let logString = entry.formattedString + "\n"
        
        if let data = logString.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // 追加到现有文件
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // 创建新文件
                try? data.write(to: fileURL)
            }
        }
    }
    
    /// 输出到内存
    private func outputToMemory(_ entry: LogEntry) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.memoryLogs.append(entry)
            
            // 保持最大条数限制
            if self.memoryLogs.count > self.maxMemoryLogs {
                self.memoryLogs.removeFirst(self.memoryLogs.count - self.maxMemoryLogs)
            }
        }
    }
    
    /// 输出到系统日志
    private func outputToSystemLog(_ entry: LogEntry) {
        let osLogType: OSLogType
        switch entry.level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        case .critical:
            osLogType = .fault
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, entry.formattedString)
    }
    
    /// 轮转日志文件
    private func rotateLogFile() {
        guard let currentURL = fileLogURL else { return }
        
        // 创建备份文件名
        let timestamp = DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = currentURL.appendingPathExtension("backup-\(timestamp)")
        
        try? FileManager.default.moveItem(at: currentURL, to: backupURL)
        
        // 重新设置文件日志
        setupFileLogging()
    }
}

// MARK: - 全局日志宏定义

/// 便捷的全局日志函数
func LogDebug(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.debug(message, category: category, file: file, function: function, line: line)
}

func LogInfo(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.info(message, category: category, file: file, function: function, line: line)
}

func LogWarning(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.warning(message, category: category, file: file, function: function, line: line)
}

func LogError(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.error(message, category: category, file: file, function: function, line: line)
}

func LogCritical(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
    LoggingService.shared.critical(message, category: category, file: file, function: function, line: line)
}