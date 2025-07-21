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
            
            // 创建内嵌的设置界面
            let settingsContent = TabView {
                VStack(spacing: 20) {
                    Text("通用设置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("应用行为")
                            .font(.headline)
                        Toggle("启用自动启动", isOn: .constant(false))
                        Toggle("显示状态栏图标", isOn: .constant(true))
                        Toggle("启用声音提示", isOn: .constant(true))
                        Toggle("显示录音指示器", isOn: .constant(true))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                    )
                    
                    Spacer()
                }
                .padding(40)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("通用")
                }
                .tag(0)
                
                VStack(spacing: 20) {
                    Text("音频设置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("音频配置")
                            .font(.headline)
                        
                        VStack(alignment: .leading) {
                            Text("采样率")
                            Picker("采样率", selection: .constant(16000)) {
                                Text("16 kHz").tag(16000)
                                Text("44.1 kHz").tag(44100)
                                Text("48 kHz").tag(48000)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle("启用降噪", isOn: .constant(false))
                        Toggle("启用音频增强", isOn: .constant(false))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                    )
                    
                    Spacer()
                }
                .padding(40)
                .tabItem {
                    Image(systemName: "speaker.wave.2")
                    Text("音频")
                }
                .tag(1)
                
                VStack(spacing: 20) {
                    Text("识别设置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("语音识别")
                            .font(.headline)
                        
                        VStack(alignment: .leading) {
                            Text("识别模型")
                            Picker("识别模型", selection: .constant("paraformer-zh")) {
                                Text("Paraformer 中文").tag("paraformer-zh")
                                Text("Paraformer 流式").tag("paraformer-zh-streaming")
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle("启用标点符号", isOn: .constant(true))
                        Toggle("启用数字转换", isOn: .constant(true))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                    )
                    
                    Spacer()
                }
                .padding(40)
                .tabItem {
                    Image(systemName: "brain")
                    Text("识别")
                }
                .tag(2)
                
                VStack(spacing: 20) {
                    Text("关于 CapsWriter")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        
                        Text("CapsWriter-mac")
                            .font(.title)
                            .fontWeight(.medium)
                        
                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("基于 Sherpa-ONNX 的离线语音转文字工具")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(40)
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("关于")
                }
                .tag(3)
            }
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