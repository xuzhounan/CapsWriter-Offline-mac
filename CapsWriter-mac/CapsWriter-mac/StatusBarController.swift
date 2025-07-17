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
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    deinit {
        statusItem = nil
    }
}