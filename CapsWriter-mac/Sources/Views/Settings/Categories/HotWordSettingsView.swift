import SwiftUI

// MARK: - Hot Word Settings View

/// 热词设置界面 - 作为设置页面中的热词分类
struct HotWordSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var showingHotWordEditor = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 热词功能开关
                HotWordToggleSection(configManager: configManager)
                
                // 热词管理
                HotWordManagementSection(showingEditor: $showingHotWordEditor)
                
                // 热词处理设置
                HotWordProcessingSection(configManager: configManager)
                
                // 标点符号处理设置
                PunctuationProcessingSection(configManager: configManager)
                
                // 热词文件监控设置
                HotWordFileWatchingSection(configManager: configManager)
            }
            .padding()
        }
        .sheet(isPresented: $showingHotWordEditor) {
            Text("热词编辑器")
                .font(.title)
                .padding()
                .frame(minWidth: 1000, minHeight: 700)
        }
    }
}

// MARK: - Hot Word Toggle Section

struct HotWordToggleSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "热词替换功能") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "启用热词替换",
                    description: "对语音识别结果进行热词替换处理",
                    isOn: $configManager.textProcessing.enableHotwordReplacement
                )
                
                if configManager.textProcessing.enableHotwordReplacement {
                    Divider()
                    
                    // 处理超时设置
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("处理超时时间")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.textProcessing.hotWordProcessingTimeout, specifier: "%.1f")秒")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $configManager.textProcessing.hotWordProcessingTimeout,
                            in: 1...10,
                            step: 0.5
                        )
                        
                        Text("热词处理的最大等待时间，超时后将使用原始识别结果")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Hot Word Management Section

struct HotWordManagementSection: View {
    @Binding var showingEditor: Bool
    @StateObject private var hotWordService = DIContainer.shared.resolve(HotWordService.self)!
    @State private var hotWordStats = HotWordStats()
    
    var body: some View {
        SettingsSection(title: "热词管理") {
            VStack(spacing: 16) {
                // 热词统计
                VStack(spacing: 12) {
                    HStack {
                        HotWordCategoryCard(
                            category: .chinese,
                            count: hotWordStats.chineseCount,
                            icon: "textformat.abc",
                            color: .blue
                        )
                        
                        HotWordCategoryCard(
                            category: .english,
                            count: hotWordStats.englishCount,
                            icon: "textformat.alt", 
                            color: .green
                        )
                    }
                    
                    HStack {
                        HotWordCategoryCard(
                            category: .rules,
                            count: hotWordStats.rulesCount,
                            icon: "arrow.triangle.2.circlepath",
                            color: .orange
                        )
                        
                        HotWordCategoryCard(
                            category: .custom,
                            count: hotWordStats.customCount,
                            icon: "plus.circle",
                            color: .purple
                        )
                    }
                }
                
                Divider()
                
                // 管理操作
                VStack(spacing: 12) {
                    Button("打开热词编辑器") {
                        showingEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    HStack(spacing: 12) {
                        Button("重新加载热词") {
                            reloadHotWords()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("清理无效热词") {
                            cleanInvalidHotWords()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("导出全部热词") {
                            exportAllHotWords()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear {
            updateHotWordStats()
        }
    }
    
    private func updateHotWordStats() {
        // 更新热词统计信息
        hotWordStats = HotWordStats(
            chineseCount: 0,  // 从服务获取实际数量
            englishCount: 0,
            rulesCount: 0,
            customCount: 0
        )
    }
    
    private func reloadHotWords() {
        print("🔄 重新加载热词")
        // 触发热词服务重新加载
        updateHotWordStats()
    }
    
    private func cleanInvalidHotWords() {
        print("🧹 清理无效热词")
        // 清理无效的热词条目
        updateHotWordStats()
    }
    
    private func exportAllHotWords() {
        print("📤 导出全部热词")
        // 导出所有分类的热词
    }
}

// MARK: - Hot Word Category Card

struct HotWordCategoryCard: View {
    let category: HotWordCategory
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(category.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Text("条热词")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hot Word Processing Section

struct HotWordProcessingSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "热词处理设置") {
            VStack(spacing: 16) {
                // 文件路径配置
                VStack(alignment: .leading, spacing: 12) {
                    Text("热词文件路径")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(spacing: 8) {
                        HotWordFilePathRow(
                            title: "中文热词文件",
                            path: $configManager.textProcessing.hotWordChinesePath,
                            placeholder: "hot-zh.txt"
                        )
                        
                        HotWordFilePathRow(
                            title: "英文热词文件",
                            path: $configManager.textProcessing.hotWordEnglishPath,
                            placeholder: "hot-en.txt"
                        )
                        
                        HotWordFilePathRow(
                            title: "替换规则文件",
                            path: $configManager.textProcessing.hotWordRulePath,
                            placeholder: "hot-rule.txt"
                        )
                    }
                }
                
                Divider()
                
                // 性能设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("性能优化")
                        .font(.system(size: 14, weight: .medium))
                    
                    // 处理超时
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("处理超时时间")
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(configManager.textProcessing.hotWordProcessingTimeout, specifier: "%.1f")秒")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $configManager.textProcessing.hotWordProcessingTimeout,
                            in: 1...10,
                            step: 0.5
                        )
                        
                        Text("超过此时间的热词处理将被中断")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Punctuation Processing Section

struct PunctuationProcessingSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "标点符号处理") {
            VStack(spacing: 16) {
                // 启用标点符号处理
                SettingsToggle(
                    title: "启用标点符号处理",
                    description: "对识别结果进行自动标点符号添加",
                    isOn: $configManager.textProcessing.enablePunctuation
                )
                
                if configManager.textProcessing.enablePunctuation {
                    Divider()
                    
                    // 标点符号强度
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标点符号强度")
                            .font(.system(size: 14, weight: .medium))
                        
                        Picker("标点符号强度", selection: $configManager.textProcessing.punctuationIntensity) {
                            Text("轻量").tag("light")
                            Text("中等").tag("medium")
                            Text("重度").tag("heavy")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text(punctuationIntensityDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 智能标点符号
                    SettingsToggle(
                        title: "智能标点符号",
                        description: "使用 AI 模型分析语义，添加更准确的标点符号",
                        isOn: $configManager.textProcessing.enableSmartPunctuation
                    )
                    
                    Divider()
                    
                    // 具体标点符号选项
                    VStack(alignment: .leading, spacing: 12) {
                        Text("标点符号类型")
                            .font(.system(size: 14, weight: .medium))
                        
                        VStack(spacing: 8) {
                            SettingsToggle(
                                title: "自动添加句号",
                                description: "在句子结尾自动添加句号",
                                isOn: $configManager.textProcessing.autoAddPeriod
                            )
                            
                            SettingsToggle(
                                title: "自动添加逗号",
                                description: "在适当位置自动添加逗号",
                                isOn: $configManager.textProcessing.autoAddComma
                            )
                            
                            SettingsToggle(
                                title: "自动添加问号",
                                description: "识别疑问句并添加问号",
                                isOn: $configManager.textProcessing.autoAddQuestionMark
                            )
                            
                            SettingsToggle(
                                title: "自动添加感叹号",
                                description: "识别感叹句并添加感叹号",
                                isOn: $configManager.textProcessing.autoAddExclamationMark
                            )
                        }
                    }
                    
                    Divider()
                    
                    // 处理选项
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsToggle(
                            title: "跳过已有标点",
                            description: "如果文本已包含标点符号，则跳过处理",
                            isOn: $configManager.textProcessing.skipExistingPunctuation
                        )
                        
                        // 标点处理超时
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("标点处理超时")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("\(configManager.textProcessing.punctuationProcessingTimeout, specifier: "%.1f")秒")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: $configManager.textProcessing.punctuationProcessingTimeout,
                                in: 0.5...5.0,
                                step: 0.1
                            )
                            
                            Text("标点符号处理的最大等待时间")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var punctuationIntensityDescription: String {
        switch configManager.textProcessing.punctuationIntensity {
        case "light":
            return "仅添加基本的句号和逗号"
        case "medium":
            return "添加常用标点符号，平衡准确性和自然性"
        case "heavy":
            return "添加全面的标点符号，包括括号、引号等"
        default:
            return "标准标点符号处理"
        }
    }
}

// MARK: - Hot Word File Path Row

struct HotWordFilePathRow: View {
    let title: String
    @Binding var path: String
    let placeholder: String
    
    @State private var showingFilePicker = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                
                TextField(placeholder, text: $path)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
            }
            
            Button("选择") {
                showingFilePicker = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    path = url.path
                }
            case .failure(let error):
                print("文件选择失败: \(error)")
            }
        }
    }
}

// MARK: - Hot Word File Watching Section

struct HotWordFileWatchingSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "文件监控") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "启用文件监控",
                    description: "监控热词文件的修改，自动重新加载更新的内容",
                    isOn: $configManager.textProcessing.enableHotWordFileWatching
                )
                
                if configManager.textProcessing.enableHotWordFileWatching {
                    InfoCard(
                        title: "文件监控已启用",
                        description: "系统将自动检测热词文件的变化并重新加载。修改热词文件后无需重启应用即可生效。",
                        icon: "eye.circle",
                        backgroundColor: .green
                    )
                }
            }
        }
    }
}

// MARK: - Hot Word Stats

struct HotWordStats {
    var chineseCount: Int = 0
    var englishCount: Int = 0
    var rulesCount: Int = 0
    var customCount: Int = 0
    
    var totalCount: Int {
        chineseCount + englishCount + rulesCount + customCount
    }
}

// MARK: - Preview

#Preview {
    HotWordSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 800)
}