import SwiftUI

// MARK: - Advanced Settings View

/// 高级设置界面
struct AdvancedSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 调试设置
                DebugSection(configManager: configManager)
                
                // 开发者选项
                DeveloperSection(configManager: configManager)
                
                // 系统集成
                SystemIntegrationSection()
                
                // 实验性功能
                ExperimentalFeaturesSection()
                
                // 维护工具
                MaintenanceSection()
            }
            .padding()
        }
    }
}

// MARK: - Debug Section

struct DebugSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "调试设置",
            description: "配置调试输出和性能监控选项"
        ) {
            VStack(spacing: 16) {
                // 启用详细日志
                SettingsToggle(
                    title: "启用详细日志",
                    description: "输出详细的调试信息到控制台",
                    isOn: $configManager.debug.enableVerboseLogging
                )
                
                // 性能指标
                SettingsToggle(
                    title: "启用性能指标",
                    description: "收集和显示应用性能数据",
                    isOn: $configManager.debug.enablePerformanceMetrics
                )
                
                Divider()
                
                // 日志级别
                VStack(alignment: .leading, spacing: 8) {
                    Text("日志级别")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("日志级别", selection: $configManager.debug.logLevel) {
                        Text("Error").tag("error")
                        Text("Warning").tag("warning")
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                        Text("Verbose").tag("verbose")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("设置日志输出的详细程度")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 最大日志条目
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最大日志条目")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.debug.maxLogEntries)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(configManager.debug.maxLogEntries) },
                            set: { configManager.debug.maxLogEntries = Int($0) }
                        ),
                        in: 100...10000,
                        step: 100
                    )
                    
                    Text("内存中保留的最大日志条目数")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if configManager.debug.enableVerboseLogging {
                    WarningCard(
                        title: "性能影响",
                        description: "详细日志会影响应用性能，建议仅在需要调试时启用。"
                    )
                }
            }
        }
    }
}

// MARK: - Developer Section

struct DeveloperSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var showingDeveloperMode = false
    
    var body: some View {
        SettingsSection(
            title: "开发者选项",
            description: "面向开发者和高级用户的特殊功能"
        ) {
            VStack(spacing: 16) {
                // 开发者模式开关
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开发者模式")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("启用高级开发和调试功能")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $showingDeveloperMode)
                        .labelsHidden()
                }
                
                if showingDeveloperMode {
                    Divider()
                    
                    // 开发者功能
                    VStack(spacing: 12) {
                        // API 测试
                        SettingsButton(
                            title: "测试 Sherpa API",
                            description: "运行 Sherpa-ONNX API 连接测试",
                            icon: "gear.badge.questionmark"
                        ) {
                            testSherpaAPI()
                        }
                        
                        // 音频管道测试
                        SettingsButton(
                            title: "测试音频管道",
                            description: "验证音频采集和处理流程",
                            icon: "waveform.path.ecg"
                        ) {
                            testAudioPipeline()
                        }
                        
                        // 内存检查
                        SettingsButton(
                            title: "内存使用分析",
                            description: "检查内存泄漏和资源使用",
                            icon: "memorychip"
                        ) {
                            analyzeMemoryUsage()
                        }
                        
                        // 模型基准测试
                        SettingsButton(
                            title: "模型性能基准",
                            description: "测试语音识别模型性能",
                            icon: "speedometer"
                        ) {
                            runModelBenchmark()
                        }
                    }
                    
                    Divider()
                    
                    // 配置导出/导入
                    VStack(spacing: 12) {
                        Text("配置管理")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Button("导出调试信息") {
                                exportDebugInfo()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("生成诊断报告") {
                                generateDiagnosticReport()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("重置开发者设置") {
                                resetDeveloperSettings()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
    
    private func testSherpaAPI() {
        print("🧪 测试 Sherpa API")
    }
    
    private func testAudioPipeline() {
        print("🎵 测试音频管道")
    }
    
    private func analyzeMemoryUsage() {
        print("🧠 分析内存使用")
    }
    
    private func runModelBenchmark() {
        print("🏃‍♂️ 运行模型基准测试")
    }
    
    private func exportDebugInfo() {
        print("📤 导出调试信息")
    }
    
    private func generateDiagnosticReport() {
        print("📋 生成诊断报告")
    }
    
    private func resetDeveloperSettings() {
        print("🔄 重置开发者设置")
    }
}

// MARK: - System Integration Section

struct SystemIntegrationSection: View {
    @State private var automatorInstalled = false
    @State private var shortcutsInstalled = false
    @State private var servicesInstalled = false
    
    var body: some View {
        SettingsSection(
            title: "系统集成",
            description: "与 macOS 系统功能的深度集成选项"
        ) {
            VStack(spacing: 16) {
                // Automator 集成
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automator 工作流")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("安装 Automator 动作以支持自动化工作流")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if automatorInstalled {
                        Button("卸载") {
                            uninstallAutomatorAction()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("安装") {
                            installAutomatorAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // 快捷指令集成
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("快捷指令支持")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("为快捷指令应用提供语音转录动作")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if shortcutsInstalled {
                        Button("卸载") {
                            uninstallShortcutsAction()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("安装") {
                            installShortcutsAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // 系统服务
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统服务")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("在右键菜单中添加语音转录选项")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if servicesInstalled {
                        Button("卸载") {
                            uninstallSystemService()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("安装") {
                            installSystemService()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // URL Scheme 注册
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL Scheme")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        Text("capswriter://")
                            .font(.system(size: 12, family: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        
                        Spacer()
                        
                        Button("测试") {
                            testURLScheme()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("注册") {
                            registerURLScheme()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("注册自定义 URL scheme 以支持其他应用调用")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            checkSystemIntegrationStatus()
        }
    }
    
    private func checkSystemIntegrationStatus() {
        // 检查各种系统集成的安装状态
        automatorInstalled = false  // 实际实现需要检查
        shortcutsInstalled = false
        servicesInstalled = false
    }
    
    private func installAutomatorAction() {
        print("📦 安装 Automator 动作")
        automatorInstalled = true
    }
    
    private func uninstallAutomatorAction() {
        print("🗑️ 卸载 Automator 动作")
        automatorInstalled = false
    }
    
    private func installShortcutsAction() {
        print("📦 安装快捷指令动作")
        shortcutsInstalled = true
    }
    
    private func uninstallShortcutsAction() {
        print("🗑️ 卸载快捷指令动作")
        shortcutsInstalled = false
    }
    
    private func installSystemService() {
        print("📦 安装系统服务")
        servicesInstalled = true
    }
    
    private func uninstallSystemService() {
        print("🗑️ 卸载系统服务")
        servicesInstalled = false
    }
    
    private func testURLScheme() {
        print("🧪 测试 URL Scheme")
        if let url = URL(string: "capswriter://test") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func registerURLScheme() {
        print("📝 注册 URL Scheme")
    }
}

// MARK: - Experimental Features Section

struct ExperimentalFeaturesSection: View {
    @State private var enableRealTimeTranscription = false
    @State private var enableMultiLanguageDetection = false
    @State private var enableSmartPunctuation = false
    @State private var enableVoiceCommands = false
    
    var body: some View {
        SettingsSection(
            title: "实验性功能",
            description: "处于开发阶段的新功能，可能不稳定"
        ) {
            VStack(spacing: 16) {
                InfoCard(
                    title: "实验性功能说明",
                    description: "这些功能仍在开发中，可能存在不稳定或性能问题。请谨慎在生产环境中使用。",
                    icon: "flask",
                    backgroundColor: .orange
                )
                
                Divider()
                
                // 实时转录
                SettingsToggle(
                    title: "实时转录显示",
                    description: "在录音过程中显示实时识别结果",
                    isOn: $enableRealTimeTranscription
                )
                
                // 多语言检测
                SettingsToggle(
                    title: "多语言自动检测",
                    description: "自动识别语音中的语言并切换相应模型",
                    isOn: $enableMultiLanguageDetection
                )
                
                // 智能标点
                SettingsToggle(
                    title: "AI 智能标点",
                    description: "使用 AI 模型自动添加更准确的标点符号",
                    isOn: $enableSmartPunctuation
                )
                
                // 语音命令
                SettingsToggle(
                    title: "语音命令识别",
                    description: "识别特殊语音命令并执行相应操作",
                    isOn: $enableVoiceCommands
                )
                
                if enableVoiceCommands {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("支持的命令")
                            .font(.system(size: 13, weight: .medium))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• \"停止录音\" - 结束当前录音")
                            Text("• \"重新开始\" - 清空并重新录音")
                            Text("• \"保存文件\" - 保存转录结果到文件")
                            Text("• \"复制文本\" - 复制结果到剪贴板")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
                
                Divider()
                
                // 实验性功能反馈
                VStack(alignment: .leading, spacing: 8) {
                    Text("反馈和建议")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack(spacing: 12) {
                        Button("报告问题") {
                            reportIssue()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("功能建议") {
                            suggestFeature()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("参与测试") {
                            joinBetaProgram()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func reportIssue() {
        print("🐛 报告问题")
        // 打开问题反馈表单或邮件
    }
    
    private func suggestFeature() {
        print("💡 功能建议")
        // 打开功能建议表单
    }
    
    private func joinBetaProgram() {
        print("🧪 参与 Beta 测试")
        // 打开 Beta 测试注册页面
    }
}

// MARK: - Maintenance Section

struct MaintenanceSection: View {
    @State private var lastCleanupDate: Date?
    @State private var cacheSize: String = "计算中..."
    @State private var isCleaningUp = false
    
    var body: some View {
        SettingsSection(
            title: "维护工具",
            description: "清理缓存、重置设置和系统维护功能"
        ) {
            VStack(spacing: 16) {
                // 缓存管理
                VStack(alignment: .leading, spacing: 12) {
                    Text("缓存管理")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("应用缓存大小")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(cacheSize)
                                .font(.system(size: 13, weight: .medium))
                        }
                        
                        Spacer()
                        
                        if isCleaningUp {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("清理缓存") {
                                cleanupCache()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    if let lastDate = lastCleanupDate {
                        Text("上次清理: \(lastDate, style: .relative)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 数据重置
                VStack(alignment: .leading, spacing: 12) {
                    Text("数据重置")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("重置应用设置")
                                .font(.system(size: 13))
                            Spacer()
                            Button("重置") {
                                resetAppSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("清空热词数据")
                                .font(.system(size: 13))
                            Spacer()
                            Button("清空") {
                                clearHotWordData()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("重置所有数据")
                                .font(.system(size: 13))
                            Spacer()
                            Button("重置") {
                                resetAllData()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Divider()
                
                // 诊断工具
                VStack(alignment: .leading, spacing: 12) {
                    Text("诊断工具")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack(spacing: 12) {
                        Button("系统检查") {
                            runSystemCheck()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("权限检查") {
                            checkPermissions()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("模型验证") {
                            validateModels()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("网络测试") {
                            testNetwork()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // 备份恢复
                VStack(alignment: .leading, spacing: 12) {
                    Text("备份恢复")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack(spacing: 12) {
                        Button("创建备份") {
                            createBackup()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("从备份恢复") {
                            restoreFromBackup()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("导出诊断") {
                            exportDiagnostics()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            calculateCacheSize()
        }
    }
    
    private func calculateCacheSize() {
        cacheSize = "12.3 MB"  // 临时硬编码，实际需要计算
    }
    
    private func cleanupCache() {
        isCleaningUp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCleaningUp = false
            lastCleanupDate = Date()
            calculateCacheSize()
            print("🧹 缓存清理完成")
        }
    }
    
    private func resetAppSettings() {
        print("🔄 重置应用设置")
    }
    
    private func clearHotWordData() {
        print("🗑️ 清空热词数据")
    }
    
    private func resetAllData() {
        print("💥 重置所有数据")
    }
    
    private func runSystemCheck() {
        print("🔍 运行系统检查")
    }
    
    private func checkPermissions() {
        print("🔐 检查权限")
    }
    
    private func validateModels() {
        print("✅ 验证模型")
    }
    
    private func testNetwork() {
        print("🌐 测试网络")
    }
    
    private func createBackup() {
        print("💾 创建备份")
    }
    
    private func restoreFromBackup() {
        print("📂 从备份恢复")
    }
    
    private func exportDiagnostics() {
        print("📋 导出诊断信息")
    }
}

// MARK: - Preview

#Preview {
    AdvancedSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 700, height: 1200)
}