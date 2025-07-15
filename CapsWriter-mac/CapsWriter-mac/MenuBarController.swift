import SwiftUI
import AppKit

class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
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
            
            // 设置菜单
            let menu = NSMenu()
            
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
        let mainWindows = NSApp.windows.filter { $0.title == "CapsWriter-mac" }
        
        if let existingWindow = mainWindows.first {
            // 如果窗口存在，就激活它
            existingWindow.makeKeyAndOrderFront(nil)
        } else {
            // 如果主窗口被关闭，重新创建
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
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    deinit {
        statusItem = nil
    }
}