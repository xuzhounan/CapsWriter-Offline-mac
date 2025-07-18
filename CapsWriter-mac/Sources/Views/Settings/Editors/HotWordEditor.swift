import SwiftUI
import UniformTypeIdentifiers

// MARK: - Hot Word Editor

/// 热词编辑器主界面
struct HotWordEditor: View {
    @StateObject private var hotWordService = DIContainer.shared.resolve(HotWordService.self)!
    @State private var selectedCategory: HotWordCategory = .chinese
    @State private var selectedEntry: HotWordEntry?
    @State private var searchText = ""
    @State private var sortBy: HotWordSortBy = .alphabetical
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingAddEntry = false
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: HotWordEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HotWordToolbar(
                selectedCategory: $selectedCategory,
                searchText: $searchText,
                sortBy: $sortBy,
                showingImporter: $showingImporter,
                showingExporter: $showingExporter,
                showingAddEntry: $showingAddEntry
            )
            
            Divider()
            
            HSplitView {
                // 左侧热词列表
                HotWordList(
                    category: selectedCategory,
                    searchText: searchText,
                    sortBy: sortBy,
                    selectedEntry: $selectedEntry,
                    entryToDelete: $entryToDelete,
                    showingDeleteAlert: $showingDeleteAlert
                )
                .frame(minWidth: 350, maxWidth: 500)
                
                // 右侧编辑区域
                HotWordEditPane(
                    entry: $selectedEntry,
                    category: selectedCategory
                )
                .frame(minWidth: 400)
            }
        }
        .navigationTitle("热词管理")
        .navigationSubtitle("管理和编辑语音识别热词替换规则")
        // 导入文件
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        // 导出文件
        .fileExporter(
            isPresented: $showingExporter,
            document: HotWordExportDocument(
                category: selectedCategory,
                hotWordService: hotWordService
            ),
            contentType: .plainText,
            defaultFilename: "热词-\(selectedCategory.displayName)-\(formattedDate())"
        ) { result in
            handleExport(result)
        }
        // 添加条目弹窗
        .sheet(isPresented: $showingAddEntry) {
            AddHotWordEntryView(
                category: selectedCategory,
                hotWordService: hotWordService
            )
        }
        // 删除确认弹窗
        .alert("删除热词", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("确定要删除热词 \"\(entry.originalText)\" 吗？此操作无法撤销。")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importHotWords(from: url)
        case .failure(let error):
            print("❌ 热词导入失败: \(error)")
        }
    }
    
    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ 热词已导出到: \(url.path)")
        case .failure(let error):
            print("❌ 热词导出失败: \(error)")
        }
    }
    
    private func importHotWords(from url: URL) {
        // 实现热词导入逻辑
        print("📥 导入热词文件: \(url.path)")
    }
    
    private func deleteEntry(_ entry: HotWordEntry) {
        hotWordService.removeHotWord(entry.originalText, category: entry.category)
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Hot Word Toolbar

struct HotWordToolbar: View {
    @Binding var selectedCategory: HotWordCategory
    @Binding var searchText: String
    @Binding var sortBy: HotWordSortBy
    @Binding var showingImporter: Bool
    @Binding var showingExporter: Bool
    @Binding var showingAddEntry: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 分类选择和操作按钮
            HStack {
                // 分类选择
                Picker("分类", selection: $selectedCategory) {
                    ForEach(HotWordCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 400)
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 8) {
                    Button(action: { showingAddEntry = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("添加")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button(action: { showingImporter = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12))
                            Text("导入")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: { showingExporter = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                            Text("导出")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // 搜索和排序
            HStack {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("搜索热词...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 300)
                
                Spacer()
                
                // 排序选择
                HStack(spacing: 6) {
                    Text("排序:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Picker("排序", selection: $sortBy) {
                        ForEach(HotWordSortBy.allCases, id: \.self) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Hot Word List

struct HotWordList: View {
    let category: HotWordCategory
    let searchText: String
    let sortBy: HotWordSortBy
    @Binding var selectedEntry: HotWordEntry?
    @Binding var entryToDelete: HotWordEntry?
    @Binding var showingDeleteAlert: Bool
    
    @StateObject private var hotWordService = DIContainer.shared.resolve(HotWordService.self)!
    @State private var entries: [HotWordEntry] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 列表标题
            HStack {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text("\(filteredEntries.count) 条")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 热词列表
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(emptyStateMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                List(filteredEntries, id: \.id, selection: $selectedEntry) { entry in
                    HotWordRow(
                        entry: entry,
                        onDelete: {
                            entryToDelete = entry
                            showingDeleteAlert = true
                        }
                    )
                    .tag(entry)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            loadEntries()
        }
        .onChange(of: category) { _ in
            loadEntries()
        }
    }
    
    private var filteredEntries: [HotWordEntry] {
        var result = entries
        
        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { entry in
                entry.originalText.localizedCaseInsensitiveContains(searchText) ||
                entry.replacementText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 排序
        switch sortBy {
        case .alphabetical:
            result = result.sorted { $0.originalText < $1.originalText }
        case .priority:
            result = result.sorted { $0.priority > $1.priority }
        case .dateCreated:
            result = result.sorted { $0.createdDate > $1.createdDate }
        case .dateModified:
            result = result.sorted { $0.lastModified > $1.lastModified }
        case .usage:
            // 暂时按字母顺序排序，实际需要统计使用频率
            result = result.sorted { $0.originalText < $1.originalText }
        }
        
        return result
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "没有找到匹配 \"\(searchText)\" 的热词"
        } else {
            return "还没有添加任何\(category.displayName)\n点击上方的添加按钮开始创建"
        }
    }
    
    private func loadEntries() {
        // 从 HotWordService 加载对应分类的热词
        // 这里需要实现从服务获取数据的逻辑
        entries = [] // 临时为空，实际需要从服务加载
    }
}

// MARK: - Hot Word Row

struct HotWordRow: View {
    let entry: HotWordEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.originalText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if !entry.isEnabled {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    
                    if entry.priority > 0 {
                        Text("P\(entry.priority)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue)
                            )
                    }
                }
                
                Text("→ \(entry.replacementText)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if entry.isCaseSensitive {
                        Text("Aa")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    if entry.isWholeWordMatch {
                        Text("Word")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: entry.lastModified, relativeTo: Date()))
                        .font(.system(size: 9))
                        .foregroundColor(.tertiary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            VStack(spacing: 4) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("删除热词")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Hot Word Edit Pane

struct HotWordEditPane: View {
    @Binding var entry: HotWordEntry?
    let category: HotWordCategory
    
    @State private var originalText = ""
    @State private var replacementText = ""
    @State private var isEnabled = true
    @State private var priority = 0
    @State private var isCaseSensitive = false
    @State private var isWholeWordMatch = true
    @State private var hasUnsavedChanges = false
    
    @StateObject private var hotWordService = DIContainer.shared.resolve(HotWordService.self)!
    
    var body: some View {
        VStack(spacing: 0) {
            // 编辑区标题
            HStack {
                Text(entry != nil ? "编辑热词" : "选择热词进行编辑")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                if hasUnsavedChanges {
                    Text("有未保存的更改")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if let currentEntry = entry {
                // 编辑表单
                ScrollView {
                    VStack(spacing: 20) {
                        // 基本信息
                        HotWordBasicInfo(
                            originalText: $originalText,
                            replacementText: $replacementText,
                            isEnabled: $isEnabled,
                            hasUnsavedChanges: $hasUnsavedChanges
                        )
                        
                        // 高级设置
                        HotWordAdvancedSettings(
                            priority: $priority,
                            isCaseSensitive: $isCaseSensitive,
                            isWholeWordMatch: $isWholeWordMatch,
                            hasUnsavedChanges: $hasUnsavedChanges
                        )
                        
                        // 统计信息
                        HotWordStatistics(entry: currentEntry)
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
                
                Divider()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button("保存") {
                        saveEntry()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    
                    Button("重置") {
                        resetEntry()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasUnsavedChanges)
                    
                    Spacer()
                    
                    Button("删除") {
                        // 删除逻辑在父视图处理
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("选择热词进行编辑")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("从左侧列表选择一个热词条目进行编辑，或点击添加按钮新建热词。")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .onChange(of: entry) { newEntry in
            loadEntryData(newEntry)
        }
    }
    
    private var canSave: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originalText != replacementText &&
        hasUnsavedChanges
    }
    
    private func loadEntryData(_ entry: HotWordEntry?) {
        guard let entry = entry else {
            resetForm()
            return
        }
        
        originalText = entry.originalText
        replacementText = entry.replacementText
        isEnabled = entry.isEnabled
        priority = entry.priority
        isCaseSensitive = entry.isCaseSensitive
        isWholeWordMatch = entry.isWholeWordMatch
        hasUnsavedChanges = false
    }
    
    private func resetForm() {
        originalText = ""
        replacementText = ""
        isEnabled = true
        priority = 0
        isCaseSensitive = false
        isWholeWordMatch = true
        hasUnsavedChanges = false
    }
    
    private func saveEntry() {
        guard let currentEntry = entry else { return }
        
        let updatedEntry = HotWordEntry(
            originalText: originalText.trimmingCharacters(in: .whitespacesAndNewlines),
            replacementText: replacementText.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            priority: priority,
            category: currentEntry.category,
            isCaseSensitive: isCaseSensitive,
            isWholeWordMatch: isWholeWordMatch,
            createdDate: currentEntry.createdDate,
            lastModified: Date()
        )
        
        // 保存到 HotWordService
        hotWordService.updateHotWord(
            originalText: currentEntry.originalText,
            newText: updatedEntry.replacementText,
            category: currentEntry.category
        )
        
        hasUnsavedChanges = false
        print("✅ 热词保存成功")
    }
    
    private func resetEntry() {
        loadEntryData(entry)
    }
}

// MARK: - Hot Word Basic Info

struct HotWordBasicInfo: View {
    @Binding var originalText: String
    @Binding var replacementText: String
    @Binding var isEnabled: Bool
    @Binding var hasUnsavedChanges: Bool
    
    var body: some View {
        SettingsSection(title: "基本信息") {
            VStack(spacing: 16) {
                // 原始文本
                VStack(alignment: .leading, spacing: 6) {
                    Text("原始文本")
                        .font(.system(size: 13, weight: .medium))
                    
                    TextField("输入要被替换的文本", text: $originalText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: originalText) { _ in
                            hasUnsavedChanges = true
                        }
                    
                    Text("语音识别结果中出现此文本时将被替换")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // 替换文本
                VStack(alignment: .leading, spacing: 6) {
                    Text("替换文本")
                        .font(.system(size: 13, weight: .medium))
                    
                    TextField("输入替换后的文本", text: $replacementText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: replacementText) { _ in
                            hasUnsavedChanges = true
                        }
                    
                    Text("原始文本将被替换为此内容")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 启用状态
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("启用此热词")
                            .font(.system(size: 13, weight: .medium))
                        
                        Text("禁用的热词不会参与替换")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .onChange(of: isEnabled) { _ in
                            hasUnsavedChanges = true
                        }
                }
            }
        }
    }
}

// MARK: - Hot Word Advanced Settings

struct HotWordAdvancedSettings: View {
    @Binding var priority: Int
    @Binding var isCaseSensitive: Bool
    @Binding var isWholeWordMatch: Bool
    @Binding var hasUnsavedChanges: Bool
    
    var body: some View {
        SettingsSection(title: "高级设置") {
            VStack(spacing: 16) {
                // 优先级设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("优先级")
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        Text("\(priority)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(priority) },
                            set: { 
                                priority = Int($0)
                                hasUnsavedChanges = true
                            }
                        ),
                        in: 0...10,
                        step: 1
                    )
                    
                    HStack {
                        Text("0 (最低)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("5 (中等)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("10 (最高)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("优先级越高的热词越先被处理，相同文本时优先级高的生效")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 匹配选项
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("大小写敏感")
                                .font(.system(size: 13, weight: .medium))
                            
                            Text("区分大小写进行匹配")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isCaseSensitive)
                            .labelsHidden()
                            .onChange(of: isCaseSensitive) { _ in
                                hasUnsavedChanges = true
                            }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("整词匹配")
                                .font(.system(size: 13, weight: .medium))
                            
                            Text("只匹配完整的单词，不匹配词的一部分")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isWholeWordMatch)
                            .labelsHidden()
                            .onChange(of: isWholeWordMatch) { _ in
                                hasUnsavedChanges = true
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Hot Word Statistics

struct HotWordStatistics: View {
    let entry: HotWordEntry
    
    var body: some View {
        SettingsSection(title: "统计信息") {
            VStack(spacing: 12) {
                HStack {
                    Text("创建时间")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(entry.createdDate, style: .date)
                        .font(.system(size: 13))
                }
                
                HStack {
                    Text("最后修改")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(entry.lastModified, style: .relative)
                        .font(.system(size: 13))
                }
                
                HStack {
                    Text("使用次数")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("0 次")  // 暂时硬编码，需要实现统计功能
                        .font(.system(size: 13))
                }
            }
        }
    }
}

// MARK: - Add Hot Word Entry View

struct AddHotWordEntryView: View {
    let category: HotWordCategory
    let hotWordService: HotWordService
    
    @State private var originalText = ""
    @State private var replacementText = ""
    @State private var priority = 0
    @State private var isCaseSensitive = false
    @State private var isWholeWordMatch = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("添加\(category.displayName)")
                    .font(.headline)
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 表单内容
            ScrollView {
                VStack(spacing: 20) {
                    HotWordBasicInfo(
                        originalText: $originalText,
                        replacementText: $replacementText,
                        isEnabled: .constant(true),
                        hasUnsavedChanges: .constant(false)
                    )
                    
                    HotWordAdvancedSettings(
                        priority: $priority,
                        isCaseSensitive: $isCaseSensitive,
                        isWholeWordMatch: $isWholeWordMatch,
                        hasUnsavedChanges: .constant(false)
                    )
                }
                .padding()
            }
            
            Divider()
            
            // 操作按钮
            HStack {
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("添加") {
                    addEntry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 600)
    }
    
    private var canAdd: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originalText.trimmingCharacters(in: .whitespacesAndNewlines) != replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func addEntry() {
        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        hotWordService.addHotWord(
            original: trimmedOriginal,
            replacement: trimmedReplacement,
            category: category
        )
        
        print("✅ 添加热词成功: \(trimmedOriginal) → \(trimmedReplacement)")
        dismiss()
    }
}

// MARK: - Hot Word Export Document

struct HotWordExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    let category: HotWordCategory
    let hotWordService: HotWordService
    
    init(category: HotWordCategory, hotWordService: HotWordService) {
        self.category = category
        self.hotWordService = hotWordService
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("HotWordExportDocument should only be used for export")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 导出热词为文本格式
        let content = generateExportContent()
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
    
    private func generateExportContent() -> String {
        // 生成导出内容，格式：原始文本|替换文本
        return "# \(category.displayName) 导出文件\n# 格式：原始文本|替换文本\n\n"
    }
}

// MARK: - Preview

#Preview {
    HotWordEditor()
        .frame(width: 1000, height: 700)
}