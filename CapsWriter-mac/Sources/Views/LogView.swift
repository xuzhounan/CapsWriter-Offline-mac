//
//  LogView.swift
//  CapsWriter-mac
//
//  Created by Claude on 2025-01-18.
//  日志系统完善 - 任务3.3 实时日志显示界面
//

import SwiftUI

// MARK: - 主日志视图

struct LogView: View {
    @StateObject private var loggingService = LoggingService.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var selectedCategory: LogCategory? = nil
    @State private var searchText = ""
    @State private var isAutoScroll = true
    @State private var showingExportSheet = false
    @State private var showingLogDetail: LogEntry? = nil
    @State private var isFilterExpanded = false
    
    // 过滤后的日志
    private var filteredLogs: [LogEntry] {
        var logs = loggingService.logs
        
        // 级别过滤
        if let level = selectedLevel {
            logs = logs.filter { $0.level >= level }
        }
        
        // 分类过滤
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }
        
        // 搜索过滤
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.function.localizedCaseInsensitiveContains(searchText) ||
                entry.file.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarSection
            
            // 过滤器面板
            if isFilterExpanded {
                filterSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 日志列表
            logListSection
        }
        .navigationTitle("系统日志")
        .sheet(isPresented: $showingExportSheet) {
            LogExportView(logs: filteredLogs)
        }
        .sheet(item: $showingLogDetail) { entry in
            LogDetailView(entry: entry)
        }
    }
    
    // MARK: - 工具栏部分
    
    private var toolbarSection: some View {
        VStack(spacing: 12) {
            // 第一行：状态信息和主要操作
            HStack {
                // 日志统计信息
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("共 \(loggingService.getLogsCount()) 条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.green)
                        Text("显示 \(filteredLogs.count) 条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 主要操作按钮
                HStack(spacing: 8) {
                    // 过滤器切换
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFilterExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("过滤")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(isFilterExpanded ? .blue : .primary)
                    
                    // 导出按钮
                    Button("导出") {
                        showingExportSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    // 清空按钮
                    Button("清空") {
                        loggingService.clearLogs()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                    
                    // 自动滚动切换
                    Toggle("自动滚动", isOn: $isAutoScroll)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
            
            // 第二行：搜索栏
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索日志内容、函数名或文件名...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                
                // 快速级别过滤按钮
                HStack(spacing: 4) {
                    ForEach([LogLevel.error, LogLevel.warning], id: \.self) { level in
                        Button(level.rawValue) {
                            selectedLevel = selectedLevel == level ? nil : level
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundColor(selectedLevel == level ? .white : levelColor(level))
                        .background(selectedLevel == level ? levelColor(level) : Color.clear)
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - 过滤器部分
    
    private var filterSection: some View {
        VStack(spacing: 16) {
            // 级别过滤
            VStack(alignment: .leading, spacing: 8) {
                Text("日志级别")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Button("全部") {
                        selectedLevel = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(selectedLevel == nil ? .white : .primary)
                    .background(selectedLevel == nil ? Color.blue : Color.clear)
                    .cornerRadius(6)
                    
                    ForEach(LogLevel.allCases.reversed(), id: \.self) { level in
                        Button(level.rawValue) {
                            selectedLevel = selectedLevel == level ? nil : level
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(selectedLevel == level ? .white : levelColor(level))
                        .background(selectedLevel == level ? levelColor(level) : Color.clear)
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                }
            }
            
            // 分类过滤
            VStack(alignment: .leading, spacing: 8) {
                Text("日志分类")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    Button("全部") {
                        selectedCategory = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(selectedCategory == nil ? .white : .primary)
                    .background(selectedCategory == nil ? Color.blue : Color.clear)
                    .cornerRadius(6)
                    
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        Button("\(category.icon) \(category.rawValue)") {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(selectedCategory == category ? .white : .blue)
                        .background(selectedCategory == category ? Color.blue : Color.clear)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - 日志列表部分
    
    private var logListSection: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { entry in
                    LogRowView(entry: entry) {
                        showingLogDetail = entry
                    }
                    .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: filteredLogs.count) {
                if isAutoScroll && !filteredLogs.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(filteredLogs.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .cyan
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - 日志行视图

struct LogRowView: View {
    let entry: LogEntry
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间戳
            Text(entry.formattedTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .monospacedDigit()
            
            // 级别指示器
            HStack(spacing: 4) {
                Circle()
                    .fill(levelColor(entry.level))
                    .frame(width: 8, height: 8)
                
                Text(entry.level.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(levelColor(entry.level))
                    .frame(width: 50, alignment: .leading)
            }
            
            // 分类图标
            Text(entry.category.icon)
                .frame(width: 20)
            
            // 日志内容
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(entry.category.rawValue) • \(entry.file):\(entry.line)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 线程标识
            if entry.thread != "Main" {
                Text(entry.thread)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("查看详情") {
                onTap()
            }
            
            Button("复制消息") {
                copyToClipboard(entry.message)
            }
            
            Button("复制完整日志") {
                copyToClipboard(entry.formattedString)
            }
        }
    }
    
    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .cyan
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - 日志详情视图

struct LogDetailView: View {
    let entry: LogEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // 基本信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("基本信息")
                        .font(.headline)
                    
                    InfoRow(label: "时间", value: DateFormatter.fullDateTime.string(from: entry.timestamp))
                    InfoRow(label: "级别", value: entry.level.rawValue, valueColor: levelColor(entry.level))
                    InfoRow(label: "分类", value: "\(entry.category.icon) \(entry.category.rawValue)")
                    InfoRow(label: "线程", value: entry.thread)
                }
                
                Divider()
                
                // 位置信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("位置信息")
                        .font(.headline)
                    
                    InfoRow(label: "文件", value: entry.file)
                    InfoRow(label: "函数", value: entry.function)
                    InfoRow(label: "行号", value: "\(entry.line)")
                }
                
                Divider()
                
                // 日志内容
                VStack(alignment: .leading, spacing: 12) {
                    Text("日志内容")
                        .font(.headline)
                    
                    ScrollView {
                        Text(entry.message)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack {
                    Button("复制消息") {
                        copyToClipboard(entry.message)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("复制完整日志") {
                        copyToClipboard(entry.formattedString)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 500, height: 600)
            .navigationTitle("日志详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .cyan
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - 信息行视图

struct InfoRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    
    init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor ?? .primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// MARK: - DateFormatter 扩展

extension DateFormatter {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - 预览

#Preview {
    LogView()
}