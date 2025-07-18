import SwiftUI

// MARK: - Shortcut Settings View

/// 快捷键设置界面
struct ShortcutSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 键盘监听设置
                KeyboardMonitoringSection(configManager: configManager)
                
                // 主要快捷键设置
                PrimaryShortcutSection(configManager: configManager)
                
                // 快捷键行为设置
                ShortcutBehaviorSection(configManager: configManager)
                
                // 快捷键帮助
                ShortcutHelpSection()
            }
            .padding()
        }
    }
}

// MARK: - Keyboard Monitoring Section

struct KeyboardMonitoringSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var monitoringStatus: KeyboardMonitoringStatus = .unknown
    
    var body: some View {
        SettingsSection(
            title: "键盘监听",
            description: "配置系统级键盘事件监听和权限设置"
        ) {
            VStack(spacing: 16) {
                // 监听状态
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("监听状态")
                            .font(.system(size: 14, weight: .medium))
                        
                        HStack {
                            Image(systemName: monitoringStatus.icon)
                                .foregroundColor(monitoringStatus.color)
                            
                            Text(monitoringStatus.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if monitoringStatus == .unauthorized {
                        Button("申请权限") {
                            requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("检查状态") {
                            checkMonitoringStatus()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                if monitoringStatus == .unauthorized {
                    WarningCard(
                        title: "需要辅助功能权限",
                        description: "应用需要辅助功能权限才能监听键盘事件。请在系统设置 > 隐私与安全性 > 辅助功能中启用 CapsWriter。"
                    )
                }
                
                Divider()
                
                // 自动启动监听
                SettingsToggle(
                    title: "启动时自动开始监听",
                    description: "应用启动时自动开始键盘事件监听",
                    isOn: $configManager.appBehavior.autoStartKeyboardMonitor
                )
            }
        }
        .onAppear {
            checkMonitoringStatus()
        }
    }
    
    private func checkMonitoringStatus() {
        // 检查辅助功能权限状态
        let trusted = AXIsProcessTrusted()
        monitoringStatus = trusted ? .authorized : .unauthorized
    }
    
    private func requestAccessibilityPermission() {
        // 请求辅助功能权限
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            monitoringStatus = .authorized
        } else {
            // 系统会自动弹出权限请求对话框
            print("🔐 请求辅助功能权限")
        }
    }
}

// MARK: - Primary Shortcut Section

struct PrimaryShortcutSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "主要快捷键",
            description: "配置录音触发和窗口控制的快捷键"
        ) {
            VStack(spacing: 16) {
                // 主键码设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("触发按键")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        Picker("按键", selection: $configManager.keyboard.primaryKeyCode) {
                            Text("O 键 (推荐)").tag(UInt16(31))
                            Text("P 键").tag(UInt16(35))
                            Text("L 键").tag(UInt16(37))
                            Text("K 键").tag(UInt16(40))
                            Text("J 键").tag(UInt16(38))
                            Text("H 键").tag(UInt16(4))
                            Text("G 键").tag(UInt16(5))
                            Text("F 键").tag(UInt16(3))
                            Text("D 键").tag(UInt16(2))
                            Text("S 键").tag(UInt16(1))
                            Text("A 键").tag(UInt16(0))
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 200)
                        
                        Spacer()
                        
                        Text("键码: \(configManager.keyboard.primaryKeyCode)")
                            .font(.system(size: 12, family: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("选择用于触发录音的按键，建议使用不常用的按键避免误触")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 连击次数
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("连击次数")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.keyboard.requiredClicks) 次")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(configManager.keyboard.requiredClicks) },
                            set: { configManager.keyboard.requiredClicks = Int($0) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    
                    HStack {
                        Text("1 次")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("推荐: 3 次")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("5 次")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("需要连续按键的次数才能触发录音，建议3次以避免误触")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 连击间隔
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("连击间隔")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(Int(configManager.keyboard.clickInterval * 1000)) ms")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.keyboard.clickInterval,
                        in: 0.2...2.0,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("200 ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("推荐: 800 ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("2000 ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("连击之间的最大时间间隔，超过此时间将重新计算连击次数")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 防抖间隔
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("防抖间隔")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(Int(configManager.keyboard.debounceInterval * 1000)) ms")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.keyboard.debounceInterval,
                        in: 0.05...0.5,
                        step: 0.01
                    )
                    
                    Text("按键防抖时间，防止按键弹跳导致的误触发")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Shortcut Behavior Section

struct ShortcutBehaviorSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "快捷键行为",
            description: "配置快捷键的触发行为和反馈设置"
        ) {
            VStack(spacing: 16) {
                // 启用快捷键
                SettingsToggle(
                    title: "启用快捷键监听",
                    description: "总开关，关闭后所有快捷键都不会响应",
                    isOn: $configManager.keyboard.enabled
                )
                
                if configManager.keyboard.enabled {
                    Divider()
                    
                    // 触发反馈设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("触发反馈")
                            .font(.system(size: 14, weight: .medium))
                        
                        VStack(spacing: 8) {
                            // 系统声音反馈
                            SettingsToggle(
                                title: "播放系统提示音",
                                description: "快捷键触发时播放系统提示音",
                                isOn: .constant(true) // 临时绑定，需要添加到配置
                            )
                            
                            // 视觉反馈
                            SettingsToggle(
                                title: "显示录音指示器",
                                description: "快捷键触发时显示录音状态指示器",
                                isOn: .constant(true) // 临时绑定，需要添加到配置
                            )
                            
                            // 菜单栏反馈
                            SettingsToggle(
                                title: "菜单栏图标变化",
                                description: "录音时改变菜单栏图标样式",
                                isOn: .constant(true) // 临时绑定，需要添加到配置
                            )
                        }
                    }
                    
                    Divider()
                    
                    // 录音控制行为
                    VStack(alignment: .leading, spacing: 12) {
                        Text("录音控制")
                            .font(.system(size: 14, weight: .medium))
                        
                        VStack(spacing: 8) {
                            // 录音模式
                            VStack(alignment: .leading, spacing: 6) {
                                Text("录音模式")
                                    .font(.system(size: 13, weight: .medium))
                                
                                Picker("录音模式", selection: .constant("toggle")) {
                                    Text("切换模式").tag("toggle")
                                    Text("按住模式").tag("hold")
                                    Text("单次模式").tag("once")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                Text("切换模式：按一次开始，再按一次停止；按住模式：按住期间录音；单次模式：按一次录音固定时长")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            // 最大录音时长
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("最大录音时长")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("30 秒")  // 临时硬编码
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: .constant(30), in: 5...120, step: 5)
                                
                                Text("录音的最大持续时间，超过后自动停止")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shortcut Help Section

struct ShortcutHelpSection: View {
    var body: some View {
        SettingsSection(
            title: "快捷键帮助",
            description: "了解如何使用和自定义快捷键"
        ) {
            VStack(spacing: 16) {
                // 使用说明
                InfoCard(
                    title: "使用说明",
                    description: "连续按指定按键即可开始录音。录音过程中会显示录音指示器，再次按快捷键或等待自动结束录音。",
                    icon: "info.circle",
                    backgroundColor: .blue
                )
                
                // 常见问题
                VStack(alignment: .leading, spacing: 12) {
                    Text("常见问题")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(spacing: 8) {
                        ShortcutHelpItem(
                            question: "快捷键不响应",
                            answer: "请检查是否已授予辅助功能权限，并确保没有其他应用占用相同快捷键。"
                        )
                        
                        ShortcutHelpItem(
                            question: "误触频繁",
                            answer: "可以增加连击次数或调整连击间隔，建议设置为3次连击，间隔800ms。"
                        )
                        
                        ShortcutHelpItem(
                            question: "反应延迟",
                            answer: "减少防抖间隔可以提高响应速度，但可能增加误触风险。"
                        )
                        
                        ShortcutHelpItem(
                            question: "与其他应用冲突",
                            answer: "更换触发按键为不常用的按键，如 O、P、L 等。"
                        )
                    }
                }
                
                Divider()
                
                // 键码参考
                VStack(alignment: .leading, spacing: 12) {
                    Text("键码参考")
                        .font(.system(size: 14, weight: .medium))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(commonKeyCodes, id: \.0) { key, code in
                            VStack(spacing: 2) {
                                Text(key)
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(code)")
                                    .font(.system(size: 10, family: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        }
                    }
                }
                
                Divider()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button("测试快捷键") {
                        testShortcut()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("重置为默认") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("导出配置") {
                        exportShortcutConfig()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
        }
    }
    
    private let commonKeyCodes: [(String, UInt16)] = [
        ("A", 0), ("S", 1), ("D", 2), ("F", 3),
        ("G", 5), ("H", 4), ("J", 38), ("K", 40),
        ("L", 37), ("O", 31), ("P", 35), ("U", 32),
        ("I", 34), ("Y", 16), ("T", 17), ("R", 15)
    ]
    
    private func testShortcut() {
        print("🧪 测试快捷键功能")
        // 实现快捷键测试逻辑
    }
    
    private func resetToDefaults() {
        print("🔄 重置快捷键为默认设置")
        // 实现重置逻辑
    }
    
    private func exportShortcutConfig() {
        print("📤 导出快捷键配置")
        // 实现配置导出逻辑
    }
}

// MARK: - Shortcut Help Item

struct ShortcutHelpItem: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Keyboard Monitoring Status

enum KeyboardMonitoringStatus {
    case unknown
    case authorized
    case unauthorized
    case error
    
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .authorized: return "checkmark.circle"
        case .unauthorized: return "xmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .authorized: return .green
        case .unauthorized: return .red
        case .error: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "权限状态检查中..."
        case .authorized: return "已授权，可以监听键盘事件"
        case .unauthorized: return "未授权，需要辅助功能权限"
        case .error: return "权限检查出错"
        }
    }
}

// MARK: - Preview

#Preview {
    ShortcutSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 1000)
}