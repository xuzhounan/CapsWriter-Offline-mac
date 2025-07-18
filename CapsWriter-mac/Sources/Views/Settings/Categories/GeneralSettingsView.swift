import SwiftUI

// MARK: - General Settings View

/// 通用设置界面
struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var selectedLanguage: SupportedLanguage = .simplifiedChinese
    @State private var selectedTheme: AppTheme = .system
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 应用行为设置
                AppBehaviorSection(configManager: configManager)
                
                // 界面设置
                InterfaceSection(
                    configManager: configManager,
                    selectedLanguage: $selectedLanguage,
                    selectedTheme: $selectedTheme
                )
                
                // 启动设置
                StartupSection(configManager: configManager)
                
                // 日志设置
                LoggingSection(configManager: configManager)
            }
            .padding()
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        // 加载当前设置值
        selectedLanguage = .simplifiedChinese // 从配置中加载
        selectedTheme = .system // 从配置中加载
    }
}

// MARK: - App Behavior Section

struct AppBehaviorSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "应用行为",
            description: "配置应用的基本行为和交互方式"
        ) {
            VStack(spacing: 16) {
                // 自动启动键盘监听
                SettingsToggle(
                    title: "自动启动键盘监听",
                    description: "应用启动时自动开始监听键盘快捷键",
                    isOn: $configManager.appBehavior.autoStartKeyboardMonitor
                )
                
                // 自动启动语音识别服务
                SettingsToggle(
                    title: "自动启动语音识别服务",
                    description: "应用启动时自动初始化语音识别引擎",
                    isOn: $configManager.appBehavior.autoStartASRService
                )
                
                // 后台模式
                SettingsToggle(
                    title: "后台模式",
                    description: "应用在后台时继续提供服务",
                    isOn: $configManager.appBehavior.backgroundMode
                )
                
                Divider()
                
                // 启动延迟设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("启动延迟")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.appBehavior.startupDelay, specifier: "%.1f")秒")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.appBehavior.startupDelay,
                        in: 0...5,
                        step: 0.1
                    )
                    
                    Text("应用启动后等待多长时间再初始化服务")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // 识别启动延迟
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("识别启动延迟")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.appBehavior.recognitionStartDelay, specifier: "%.1f")秒")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.appBehavior.recognitionStartDelay,
                        in: 0...5,
                        step: 0.1
                    )
                    
                    Text("开始录音后等待多长时间再启动识别")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // 权限检查延迟
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("权限检查延迟")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.appBehavior.permissionCheckDelay, specifier: "%.1f")秒")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.appBehavior.permissionCheckDelay,
                        in: 0...10,
                        step: 0.5
                    )
                    
                    Text("应用启动后等待多长时间再检查权限")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Interface Section

struct InterfaceSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @Binding var selectedLanguage: SupportedLanguage
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        SettingsSection(
            title: "界面设置",
            description: "自定义应用界面外观和交互体验"
        ) {
            VStack(spacing: 16) {
                // 语言设置
                SettingsPicker(
                    title: "界面语言",
                    description: "更改界面显示语言（需要重启应用）",
                    selection: $selectedLanguage,
                    options: SupportedLanguage.allCases
                ) { language in
                    Text(language.displayName)
                }
                
                Divider()
                
                // 主题设置
                SettingsPicker(
                    title: "主题",
                    description: "选择应用的颜色主题",
                    selection: $selectedTheme,
                    options: AppTheme.allCases
                ) { theme in
                    HStack {
                        Circle()
                            .fill(themeColor(for: theme))
                            .frame(width: 12, height: 12)
                        Text(theme.displayName)
                    }
                }
                
                Divider()
                
                // 状态栏图标
                SettingsToggle(
                    title: "显示状态栏图标",
                    description: "在菜单栏显示应用图标和快速操作",
                    isOn: $configManager.ui.showStatusBarIcon
                )
                
                // 主窗口显示
                SettingsToggle(
                    title: "启动时显示主窗口",
                    description: "应用启动时自动显示主界面窗口",
                    isOn: $configManager.ui.showMainWindow
                )
                
                // 深色模式
                SettingsToggle(
                    title: "启用深色模式",
                    description: "使用深色界面主题（覆盖系统设置）",
                    isOn: $configManager.ui.darkMode
                )
            }
        }
    }
    
    private func themeColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system: return .accentColor
        case .light: return .yellow
        case .dark: return .purple
        }
    }
}

// MARK: - Startup Section

struct StartupSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var autoStartEnabled = false
    
    var body: some View {
        SettingsSection(
            title: "启动设置",
            description: "配置应用的启动行为"
        ) {
            VStack(spacing: 16) {
                // 开机自启动
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开机自启动")
                            .font(.system(size: 14, weight: .medium))
                        Text("系统启动时自动运行 CapsWriter")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoStartEnabled)
                        .labelsHidden()
                        .onChange(of: autoStartEnabled) { value in
                            toggleAutoStart(enabled: value)
                        }
                }
                
                if autoStartEnabled {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text("应用将在系统启动时自动运行，并在后台提供服务")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                }
                
                Divider()
                
                // 启动时最小化
                SettingsToggle(
                    title: "启动时最小化到托盘",
                    description: "应用启动时不显示窗口，仅在状态栏显示图标",
                    isOn: .constant(true) // 临时绑定，需要添加到配置中
                )
                
                // 启动时检查更新
                SettingsToggle(
                    title: "启动时检查更新",
                    description: "应用启动时自动检查是否有新版本可用",
                    isOn: .constant(false) // 临时绑定，需要添加到配置中
                )
            }
        }
        .onAppear {
            checkAutoStartStatus()
        }
    }
    
    private func toggleAutoStart(enabled: Bool) {
        // 实现开机自启动逻辑
        if enabled {
            enableAutoStart()
        } else {
            disableAutoStart()
        }
    }
    
    private func enableAutoStart() {
        let appPath = Bundle.main.bundlePath
        let loginItems = LSSharedFileList.loginItems()
        
        // 添加到登录项
        // 注意：这里需要使用 LSSharedFileList API
        print("🚀 启用开机自启动: \(appPath)")
    }
    
    private func disableAutoStart() {
        // 从登录项移除
        print("❌ 禁用开机自启动")
    }
    
    private func checkAutoStartStatus() {
        // 检查当前是否已设置开机自启动
        autoStartEnabled = false // 实际实现中需要检查登录项
    }
}

// MARK: - Logging Section

struct LoggingSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "日志设置",
            description: "配置应用的日志记录和调试选项"
        ) {
            VStack(spacing: 16) {
                // 启用日志
                SettingsToggle(
                    title: "启用日志记录",
                    description: "记录应用运行过程中的关键信息和错误",
                    isOn: $configManager.ui.enableLogging
                )
                
                if configManager.ui.enableLogging {
                    Divider()
                    
                    // 日志级别
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("日志级别")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text(logLevelName(configManager.ui.logLevel))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("日志级别", selection: $configManager.ui.logLevel) {
                            Text("无日志").tag(0)
                            Text("基本").tag(1)
                            Text("详细").tag(2)
                            Text("调试").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text(logLevelDescription(configManager.ui.logLevel))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // 最大日志条目数
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最大日志条目数")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.ui.maxLogEntries)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(configManager.ui.maxLogEntries) },
                                set: { configManager.ui.maxLogEntries = Int($0) }
                            ),
                            in: 50...1000,
                            step: 50
                        )
                        
                        Text("超过此数量的日志条目将被自动清理")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 日志操作按钮
                    HStack(spacing: 12) {
                        Button("查看日志") {
                            openLogView()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("导出日志") {
                            exportLogs()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("清空日志") {
                            clearLogs()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func logLevelName(_ level: Int) -> String {
        switch level {
        case 0: return "无日志"
        case 1: return "基本"
        case 2: return "详细"
        case 3: return "调试"
        default: return "未知"
        }
    }
    
    private func logLevelDescription(_ level: Int) -> String {
        switch level {
        case 0: return "不记录任何日志信息"
        case 1: return "仅记录错误和重要事件"
        case 2: return "记录详细的操作信息"
        case 3: return "记录所有调试信息（影响性能）"
        default: return ""
        }
    }
    
    private func openLogView() {
        // 打开日志查看器
        print("📋 打开日志查看器")
    }
    
    private func exportLogs() {
        // 导出日志文件
        print("📤 导出日志文件")
    }
    
    private func clearLogs() {
        // 清空日志
        print("🗑️ 清空日志")
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 800)
}