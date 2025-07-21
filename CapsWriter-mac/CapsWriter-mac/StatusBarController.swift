import SwiftUI
import AppKit

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    
    init() {
        createStatusItem()
    }
    
    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 使用系统图标作为菜单栏图标
            button.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "CapsWriter")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
            
            // 设置按钮样式
            button.imagePosition = .imageOnly
            button.toolTip = "CapsWriter - 音频转录工具"
            
            // 设置菜单
            let menu = NSMenu()
            menu.autoenablesItems = false
            
            // 添加应用标题（不可点击）
            let titleItem = NSMenuItem(title: "CapsWriter", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            
            // 分隔线
            menu.addItem(NSMenuItem.separator())
            
            // 打开主窗口菜单项
            let openWindowItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "")
            openWindowItem.target = self
            menu.addItem(openWindowItem)
            
            // 分隔线
            menu.addItem(NSMenuItem.separator())
            
            // 键盘监听控制菜单项
            let startMonitoringItem = NSMenuItem(title: "启动键盘监听", action: #selector(startKeyboardMonitoring), keyEquivalent: "")
            startMonitoringItem.target = self
            menu.addItem(startMonitoringItem)
            
            let stopMonitoringItem = NSMenuItem(title: "停止键盘监听", action: #selector(stopKeyboardMonitoring), keyEquivalent: "")
            stopMonitoringItem.target = self
            menu.addItem(stopMonitoringItem)
            
            // 分隔线
            menu.addItem(NSMenuItem.separator())
            
            // 设置菜单项
            let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            // 分隔线
            menu.addItem(NSMenuItem.separator())
            
            // 退出应用菜单项
            let quitItem = NSMenuItem(title: "退出 CapsWriter", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusItem?.menu = menu
        }
    }
    
    @objc func openMainWindow() {
        // 激活应用并显示主窗口
        NSApp.activate(ignoringOtherApps: true)
        
        // 查找现有的主窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "CapsWriter-mac" }) {
            // 如果窗口存在，就激活它
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        }
    }
    
    @objc private func startKeyboardMonitoring() {
        // 获取AppDelegate实例并启动键盘监听
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.startKeyboardMonitoring()
        }
    }
    
    @objc private func stopKeyboardMonitoring() {
        // 获取AppDelegate实例并停止键盘监听
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.stopKeyboardMonitoring()
        }
    }
    
    @objc private func openSettings() {
        // 激活应用并打开设置窗口
        NSApp.activate(ignoringOtherApps: true)
        
        // 查找现有的设置窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "设置" }) {
            // 如果设置窗口存在，就激活它
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // 创建新的设置窗口
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            
            // 创建设置界面 - 使用响应式配置管理
            let configManager = ConfigurationManager.shared
            let settingsContent = VStack(spacing: 20) {
                Text("CapsWriter 设置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("应用行为")
                        .font(.headline)
                    
                    // 使用实际的配置绑定而非 .constant()
                    SettingsToggleRow(
                        title: "启用自动启动",
                        isOn: Binding(
                            get: { configManager.appBehavior.enableAutoLaunch },
                            set: { configManager.appBehavior.enableAutoLaunch = $0 }
                        )
                    )
                    
                    SettingsToggleRow(
                        title: "显示状态栏图标",
                        isOn: Binding(
                            get: { configManager.ui.showStatusBarIcon },
                            set: { configManager.ui.showStatusBarIcon = $0 }
                        )
                    )
                    
                    SettingsToggleRow(
                        title: "启用声音提示",
                        isOn: Binding(
                            get: { configManager.ui.enableSoundEffects },
                            set: { configManager.ui.enableSoundEffects = $0 }
                        )
                    )
                    
                    SettingsToggleRow(
                        title: "显示录音指示器",
                        isOn: Binding(
                            get: { configManager.ui.showRecordingIndicator },
                            set: { configManager.ui.showRecordingIndicator = $0 }
                        )
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                )
                
                Spacer()
            }
            .padding(40)
            .frame(minWidth: 500, minHeight: 400)
            
            settingsWindow.contentView = NSHostingView(rootView: settingsContent)
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    deinit {
        statusItem = nil
    }
}

// MARK: - Settings UI Components
struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}