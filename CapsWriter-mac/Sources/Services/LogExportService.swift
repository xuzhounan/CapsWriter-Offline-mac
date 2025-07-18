//
//  LogExportService.swift
//  CapsWriter-mac
//
//  Created by Claude on 2025-01-18.
//  日志系统完善 - 任务3.3 日志导出功能
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 导出格式定义

/// 日志导出格式
enum LogExportFormat: String, CaseIterable, Identifiable {
    case txt = "TXT"
    case json = "JSON"
    case csv = "CSV"
    case html = "HTML"
    
    var id: String { rawValue }
    
    /// 文件扩展名
    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .json: return "json"
        case .csv: return "csv"
        case .html: return "html"
        }
    }
    
    /// UTType
    var utType: UTType {
        switch self {
        case .txt: return .plainText
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .html: return .html
        }
    }
    
    /// 描述
    var description: String {
        switch self {
        case .txt: return "纯文本格式，易于阅读"
        case .json: return "JSON格式，便于程序处理"
        case .csv: return "CSV格式，可用Excel打开"
        case .html: return "HTML格式，支持样式和颜色"
        }
    }
}

// MARK: - 导出配置

/// 日志导出配置
struct LogExportConfiguration {
    var format: LogExportFormat
    var includeTimestamp: Bool
    var includeLevel: Bool
    var includeCategory: Bool
    var includeLocation: Bool
    var includeThread: Bool
    var dateRange: DateInterval?
    var levels: Set<LogLevel>
    var categories: Set<LogCategory>
    var maxEntries: Int?
    var sortOrder: SortOrder
    
    enum SortOrder {
        case chronological  // 按时间顺序
        case reverseChronological  // 按时间倒序
    }
    
    /// 默认配置
    static let `default` = LogExportConfiguration(
        format: .txt,
        includeTimestamp: true,
        includeLevel: true,
        includeCategory: true,
        includeLocation: true,
        includeThread: false,
        dateRange: nil,
        levels: Set(LogLevel.allCases),
        categories: Set(LogCategory.allCases),
        maxEntries: nil,
        sortOrder: .chronological
    )
}

// MARK: - 导出结果

/// 导出结果
struct LogExportResult {
    let success: Bool
    let fileURL: URL?
    let exportedCount: Int
    let error: Error?
    let fileSize: Int64?
    
    /// 成功结果
    static func success(fileURL: URL, count: Int, fileSize: Int64) -> LogExportResult {
        return LogExportResult(success: true, fileURL: fileURL, exportedCount: count, error: nil, fileSize: fileSize)
    }
    
    /// 失败结果
    static func failure(error: Error) -> LogExportResult {
        return LogExportResult(success: false, fileURL: nil, exportedCount: 0, error: error, fileSize: nil)
    }
}

// MARK: - 日志导出服务协议

protocol LogExportServiceProtocol {
    func exportLogs(_ logs: [LogEntry], configuration: LogExportConfiguration) async -> LogExportResult
    func generateFileName(for configuration: LogExportConfiguration) -> String
    func shareByEmail(fileURL: URL, logs: [LogEntry])
}

// MARK: - 日志导出服务实现

class LogExportService: LogExportServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = LogExportService()
    
    private init() {
        LogInfo("LogExportService 已初始化", category: .service)
    }
    
    // MARK: - Public Methods
    
    func exportLogs(_ logs: [LogEntry], configuration: LogExportConfiguration) async -> LogExportResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performExport(logs, configuration: configuration)
                    continuation.resume(returning: result)
                } catch {
                    LogError("日志导出失败: \(error.localizedDescription)", category: .file)
                    continuation.resume(returning: .failure(error: error))
                }
            }
        }
    }
    
    func generateFileName(for configuration: LogExportConfiguration) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let levelStr = configuration.levels.count == LogLevel.allCases.count ? "all" : configuration.levels.map { $0.rawValue.lowercased() }.joined(separator: "-")
        let categoryStr = configuration.categories.count == LogCategory.allCases.count ? "all" : configuration.categories.map { $0.rawValue.lowercased() }.joined(separator: "-")
        
        return "capswriter-logs_\(timestamp)_\(levelStr)_\(categoryStr).\(configuration.format.fileExtension)"
    }
    
    func shareByEmail(fileURL: URL, logs: [LogEntry]) {
        // 实现邮件分享功能
        let subject = "CapsWriter 日志导出 - \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        let body = """
        这是 CapsWriter 的日志导出文件。
        
        导出信息:
        - 日志条数: \(logs.count)
        - 导出时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))
        - 文件大小: \(ByteCountFormatter.string(fromByteCount: fileURL.fileSize, countStyle: .file))
        
        请在邮件中附加导出的日志文件。
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func performExport(_ logs: [LogEntry], configuration: LogExportConfiguration) throws -> LogExportResult {
        // 过滤日志
        let filteredLogs = filterLogs(logs, configuration: configuration)
        
        // 生成内容
        let content = try generateContent(filteredLogs, configuration: configuration)
        
        // 保存到文件
        let fileName = generateFileName(for: configuration)
        let fileURL = try saveToFile(content: content, fileName: fileName)
        
        // 获取文件大小
        let fileSize = fileURL.fileSize
        
        LogInfo("日志导出成功: \(filteredLogs.count) 条记录，文件大小: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))", category: .file)
        
        return .success(fileURL: fileURL, count: filteredLogs.count, fileSize: fileSize)
    }
    
    private func filterLogs(_ logs: [LogEntry], configuration: LogExportConfiguration) -> [LogEntry] {
        var filteredLogs = logs
        
        // 级别过滤
        filteredLogs = filteredLogs.filter { configuration.levels.contains($0.level) }
        
        // 分类过滤
        filteredLogs = filteredLogs.filter { configuration.categories.contains($0.category) }
        
        // 日期范围过滤
        if let dateRange = configuration.dateRange {
            filteredLogs = filteredLogs.filter { dateRange.contains($0.timestamp) }
        }
        
        // 排序
        switch configuration.sortOrder {
        case .chronological:
            filteredLogs.sort { $0.timestamp < $1.timestamp }
        case .reverseChronological:
            filteredLogs.sort { $0.timestamp > $1.timestamp }
        }
        
        // 数量限制
        if let maxEntries = configuration.maxEntries {
            filteredLogs = Array(filteredLogs.prefix(maxEntries))
        }
        
        return filteredLogs
    }
    
    private func generateContent(_ logs: [LogEntry], configuration: LogExportConfiguration) throws -> String {
        switch configuration.format {
        case .txt:
            return generateTxtContent(logs, configuration: configuration)
        case .json:
            return try generateJsonContent(logs, configuration: configuration)
        case .csv:
            return generateCsvContent(logs, configuration: configuration)
        case .html:
            return generateHtmlContent(logs, configuration: configuration)
        }
    }
    
    // MARK: - 格式生成方法
    
    private func generateTxtContent(_ logs: [LogEntry], configuration: LogExportConfiguration) -> String {
        var content = "CapsWriter 日志导出\n"
        content += "导出时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))\n"
        content += "日志条数: \(logs.count)\n"
        content += "格式: 纯文本\n"
        content += "=" + String(repeating: "=", count: 50) + "\n\n"
        
        for entry in logs {
            var line = ""
            
            if configuration.includeTimestamp {
                line += "[\(entry.formattedTimestamp)] "
            }
            
            if configuration.includeLevel {
                line += "[\(entry.level.rawValue)] "
            }
            
            if configuration.includeCategory {
                line += "[\(entry.category.rawValue)] "
            }
            
            line += entry.message
            
            if configuration.includeLocation {
                line += " (\(entry.file):\(entry.line))"
            }
            
            if configuration.includeThread && entry.thread != "Main" {
                line += " [Thread: \(entry.thread)]"
            }
            
            content += line + "\n"
        }
        
        return content
    }
    
    private func generateJsonContent(_ logs: [LogEntry], configuration: LogExportConfiguration) throws -> String {
        let exportData: [String: Any] = [
            "metadata": [
                "exportTime": ISO8601DateFormatter().string(from: Date()),
                "exportCount": logs.count,
                "format": "JSON",
                "configuration": [
                    "includeTimestamp": configuration.includeTimestamp,
                    "includeLevel": configuration.includeLevel,
                    "includeCategory": configuration.includeCategory,
                    "includeLocation": configuration.includeLocation,
                    "includeThread": configuration.includeThread
                ]
            ],
            "logs": logs.map { entry in
                var logData: [String: Any] = [:]
                
                if configuration.includeTimestamp {
                    logData["timestamp"] = ISO8601DateFormatter().string(from: entry.timestamp)
                }
                
                if configuration.includeLevel {
                    logData["level"] = entry.level.rawValue
                }
                
                if configuration.includeCategory {
                    logData["category"] = entry.category.rawValue
                }
                
                logData["message"] = entry.message
                
                if configuration.includeLocation {
                    logData["file"] = entry.file
                    logData["function"] = entry.function
                    logData["line"] = entry.line
                }
                
                if configuration.includeThread {
                    logData["thread"] = entry.thread
                }
                
                return logData
            }
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "LogExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法生成JSON字符串"])
        }
        
        return jsonString
    }
    
    private func generateCsvContent(_ logs: [LogEntry], configuration: LogExportConfiguration) -> String {
        var content = ""
        
        // CSV 头部
        var headers: [String] = []
        if configuration.includeTimestamp { headers.append("时间戳") }
        if configuration.includeLevel { headers.append("级别") }
        if configuration.includeCategory { headers.append("分类") }
        headers.append("消息")
        if configuration.includeLocation {
            headers.append("文件")
            headers.append("函数")
            headers.append("行号")
        }
        if configuration.includeThread { headers.append("线程") }
        
        content += headers.joined(separator: ",") + "\n"
        
        // CSV 数据
        for entry in logs {
            var fields: [String] = []
            
            if configuration.includeTimestamp {
                fields.append(csvEscape(entry.formattedTimestamp))
            }
            
            if configuration.includeLevel {
                fields.append(csvEscape(entry.level.rawValue))
            }
            
            if configuration.includeCategory {
                fields.append(csvEscape(entry.category.rawValue))
            }
            
            fields.append(csvEscape(entry.message))
            
            if configuration.includeLocation {
                fields.append(csvEscape(entry.file))
                fields.append(csvEscape(entry.function))
                fields.append("\(entry.line)")
            }
            
            if configuration.includeThread {
                fields.append(csvEscape(entry.thread))
            }
            
            content += fields.joined(separator: ",") + "\n"
        }
        
        return content
    }
    
    private func generateHtmlContent(_ logs: [LogEntry], configuration: LogExportConfiguration) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>CapsWriter 日志导出</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; margin: 20px; }
                .header { border-bottom: 2px solid #e1e5e9; padding-bottom: 20px; margin-bottom: 20px; }
                .log-entry { margin-bottom: 10px; padding: 8px; border-radius: 4px; border-left: 4px solid #ddd; }
                .debug { border-left-color: #17a2b8; background-color: #f8f9fa; }
                .info { border-left-color: #28a745; background-color: #f8f9fa; }
                .warning { border-left-color: #ffc107; background-color: #fff3cd; }
                .error { border-left-color: #dc3545; background-color: #f8d7da; }
                .critical { border-left-color: #6f42c1; background-color: #e2d9f3; }
                .timestamp { color: #6c757d; font-size: 0.9em; }
                .level { font-weight: bold; text-transform: uppercase; }
                .category { background-color: #e9ecef; padding: 2px 6px; border-radius: 3px; font-size: 0.8em; }
                .message { margin: 4px 0; }
                .location { color: #6c757d; font-size: 0.8em; }
                .thread { color: #6c757d; font-size: 0.8em; font-style: italic; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>CapsWriter 日志导出</h1>
                <p>导出时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))</p>
                <p>日志条数: \(logs.count)</p>
                <p>格式: HTML</p>
            </div>
        """
        
        for entry in logs {
            let levelClass = entry.level.rawValue.lowercased()
            html += "<div class=\"log-entry \(levelClass)\">"
            
            if configuration.includeTimestamp {
                html += "<span class=\"timestamp\">[\(entry.formattedTimestamp)]</span> "
            }
            
            if configuration.includeLevel {
                html += "<span class=\"level \(levelClass)\">[\(entry.level.rawValue)]</span> "
            }
            
            if configuration.includeCategory {
                html += "<span class=\"category\">[\(entry.category.rawValue)]</span> "
            }
            
            html += "<div class=\"message\">\(htmlEscape(entry.message))</div>"
            
            if configuration.includeLocation {
                html += "<div class=\"location\">(\(entry.file):\(entry.line) in \(entry.function))</div>"
            }
            
            if configuration.includeThread && entry.thread != "Main" {
                html += "<div class=\"thread\">[Thread: \(entry.thread)]</div>"
            }
            
            html += "</div>"
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - 辅助方法
    
    private func saveToFile(content: String, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsPath = documentsPath.appendingPathComponent("CapsWriter-Exports")
        
        // 创建导出目录
        try FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
        
        let fileURL = exportsPath.appendingPathComponent(fileName)
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    private func csvEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    private func htmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - URL 扩展

extension URL {
    var fileSize: Int64 {
        do {
            let resourceValues = try resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
}

// MARK: - 日志导出界面

struct LogExportView: View {
    let logs: [LogEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = LogExportConfiguration.default
    @State private var isExporting = false
    @State private var exportResult: LogExportResult?
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 配置选项
                configurationSection
                
                Divider()
                
                // 预览信息
                previewSection
                
                Spacer()
                
                // 操作按钮
                actionButtons
            }
            .padding()
            .frame(width: 500, height: 600)
            .navigationTitle("导出日志")
            // .navigationBarTitleDisplayMode(.inline) // macOS不支持
        }
        .sheet(isPresented: $showingFilePicker) {
            if let result = exportResult, result.success, let fileURL = result.fileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出配置")
                .font(.headline)
            
            // 格式选择
            VStack(alignment: .leading, spacing: 8) {
                Text("格式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("格式", selection: $configuration.format) {
                    ForEach(LogExportFormat.allCases) { format in
                        VStack(alignment: .leading) {
                            Text(format.rawValue)
                                .font(.headline)
                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 包含选项
            VStack(alignment: .leading, spacing: 8) {
                Text("包含信息")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("时间戳", isOn: $configuration.includeTimestamp)
                    Toggle("日志级别", isOn: $configuration.includeLevel)
                    Toggle("分类", isOn: $configuration.includeCategory)
                    Toggle("位置信息", isOn: $configuration.includeLocation)
                    Toggle("线程信息", isOn: $configuration.includeThread)
                }
                .toggleStyle(.checkbox)
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出预览")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总日志条数:")
                    Spacer()
                    Text("\(logs.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("文件名:")
                    Spacer()
                    Text(LogExportService.shared.generateFileName(for: configuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("格式:")
                    Spacer()
                    Text(configuration.format.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var actionButtons: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("导出") {
                exportLogs()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || logs.isEmpty)
        }
    }
    
    private func exportLogs() {
        isExporting = true
        
        Task {
            let result = await LogExportService.shared.exportLogs(logs, configuration: configuration)
            
            await MainActor.run {
                self.exportResult = result
                self.isExporting = false
                
                if result.success {
                    showingFilePicker = true
                } else {
                    // 显示错误信息
                    print("导出失败: \(result.error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
}

// MARK: - 分享界面

struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}