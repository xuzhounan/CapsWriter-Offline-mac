import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化菜单栏控制器
        menuBarController = MenuBarController()
        
        // 设置应用为 Agent 应用（不显示在 Dock 中，但仍然可以有窗口）
        // 如果希望在 Dock 中显示，请注释掉下面这行
        // NSApp.setActivationPolicy(.accessory)
        
        // 确保应用在 Dock 中显示
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        menuBarController = nil
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户在 Dock 中点击应用图标时，如果没有可见窗口，则显示主窗口
        if !flag {
            menuBarController?.openMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 当最后一个窗口关闭时，不退出应用（继续在菜单栏中运行）
        return false
    }
}