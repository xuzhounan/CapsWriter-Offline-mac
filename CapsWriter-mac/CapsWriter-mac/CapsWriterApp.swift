import SwiftUI

@main
struct CapsWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 创建静态引用来保存appDelegate
    static var sharedAppDelegate: AppDelegate?
    
    init() {
        // 在应用启动时保存appDelegate引用
        print("🚀 CapsWriterApp init() - 开始初始化")
    }
    
    var body: some Scene {
        Window("CapsWriter-mac", id: "main") {
            ContentView()
                .onAppear {
                    // 保存appDelegate到静态变量
                    CapsWriterApp.sharedAppDelegate = appDelegate
                    print("✅ 已保存appDelegate到静态变量")
                }
        }
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}