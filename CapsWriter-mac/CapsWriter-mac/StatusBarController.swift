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
        let mainWindows = NSApp.windows.filter { 
            $0.title == "CapsWriter-mac" && $0.isVisible 
        }
        
        if let existingWindow = mainWindows.first {
            // 如果窗口存在且可见，就激活它
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // 查找隐藏的窗口
            let hiddenWindows = NSApp.windows.filter { 
                $0.title == "CapsWriter-mac" && !$0.isVisible 
            }
            
            if let hiddenWindow = hiddenWindows.first {
                // 如果有隐藏的窗口，显示它
                hiddenWindow.makeKeyAndOrderFront(nil)
                hiddenWindow.orderFrontRegardless()
            } else {
                // 如果没有窗口，创建新窗口
                createNewMainWindow()
            }
        }
    }
    
    private func createNewMainWindow() {
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "CapsWriter-mac"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // 设置窗口关闭时不终止应用
        window.isReleasedWhenClosed = false
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    deinit {
        statusItem = nil
    }
}