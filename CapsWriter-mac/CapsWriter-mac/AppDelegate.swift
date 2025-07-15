import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        
        // 确保应用在 Dock 中显示（同时支持菜单栏）
        NSApp.setActivationPolicy(.regular)
        
        // 如果只想要菜单栏应用（不在 Dock 中显示），可以使用：
        // NSApp.setActivationPolicy(.accessory)
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