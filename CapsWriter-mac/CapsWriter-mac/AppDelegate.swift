import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制设置应用为正常应用，确保在 Dock 中显示
        NSApp.setActivationPolicy(.regular)
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        
        // 手动激活应用，确保 Dock 图标显示
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        statusBarController = nil
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户在 Dock 中点击应用图标时，如果没有可见窗口，则显示主窗口
        if !flag {
            statusBarController?.openMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 当最后一个窗口关闭时，不退出应用（继续在菜单栏中运行）
        return false
    }
}