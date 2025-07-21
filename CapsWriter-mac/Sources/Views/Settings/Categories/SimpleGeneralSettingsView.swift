import SwiftUI

// MARK: - Simple General Settings View

/// 简化的通用设置界面
struct SimpleGeneralSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 应用行为设置
                AppBehaviorSection(configManager: configManager)
                
                // 界面设置
                InterfaceSection(configManager: configManager)
                
                // 启动设置  
                StartupSection(configManager: configManager)
            }
            .padding()
        }
    }
}

// MARK: - App Behavior Section

struct AppBehaviorSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "应用行为") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "启动时最小化",
                    description: "应用启动后自动最小化到菜单栏",
                    isOn: $configManager.appBehavior.minimizeOnStartup
                )
                
                SettingsToggle(
                    title: "自动启动监听器",
                    description: "应用启动时自动开始键盘监听",
                    isOn: $configManager.appBehavior.autoStartKeyboardMonitor
                )
                
                SettingsToggle(
                    title: "启动时检查更新",
                    description: "应用启动时自动检查新版本",
                    isOn: $configManager.appBehavior.checkUpdatesOnStartup
                )
            }
        }
    }
}

// MARK: - Interface Section

struct InterfaceSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "界面设置") {
            VStack(spacing: 16) {
                // 主题选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("应用主题")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("选择应用的外观主题")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Picker("主题", selection: $configManager.ui.darkMode) {
                        Text("浅色模式").tag(false)
                        Text("深色模式").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Divider()
                
                // 菜单栏设置
                SettingsToggle(
                    title: "显示状态栏图标",
                    description: "在菜单栏显示应用图标和状态",
                    isOn: $configManager.ui.showStatusBarIcon
                )
                
                Divider()
                
                SettingsToggle(
                    title: "显示菜单栏图标",
                    description: "在菜单栏显示应用图标和状态",
                    isOn: $configManager.ui.showStatusBarIcon
                )
                
                SettingsToggle(
                    title: "菜单栏图标状态变化",
                    description: "根据录音状态改变菜单栏图标颜色",
                    isOn: $configManager.ui.enableMenuBarIconChange
                )
            }
        }
    }
}

// MARK: - Startup Section

struct StartupSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(title: "启动设置") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "开机自启动",
                    description: "系统启动时自动运行 CapsWriter",
                    isOn: $configManager.appBehavior.enableAutoLaunch
                )
                
                if configManager.appBehavior.enableAutoLaunch {
                    InfoCard(
                        title: "自启动已启用",
                        description: "CapsWriter 将在系统启动时自动运行",
                        icon: "checkmark.circle",
                        backgroundColor: .green
                    )
                }
                
                SettingsToggle(
                    title: "静默启动",
                    description: "启动时不显示主窗口",
                    isOn: $configManager.appBehavior.minimizeOnStartup
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SimpleGeneralSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 800)
}