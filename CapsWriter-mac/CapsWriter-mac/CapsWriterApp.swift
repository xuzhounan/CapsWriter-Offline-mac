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
                    
                    // 确保使用AppDelegate中已经初始化的监听器，而不是创建新的
                    setupGlobalKeyboardMonitorReference()
                }
        }
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
    
    private func setupGlobalKeyboardMonitorReference() {
        print("🔧 CapsWriterApp: 设置全局键盘监听器引用...")
        
        // 使用已经在AppDelegate中初始化的监听器，而不是创建新的
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔧 检查静态appDelegate: \(String(describing: CapsWriterApp.sharedAppDelegate))")
            
            if let appDelegate = CapsWriterApp.sharedAppDelegate,
               let existingMonitor = appDelegate.keyboardMonitor {
                // 使用AppDelegate中已经初始化的监听器
                ContentView.globalKeyboardMonitor = existingMonitor
                print("✅ 已将AppDelegate的监听器设置为全局引用")
            } else {
                print("⚠️ AppDelegate或其监听器不存在，使用备用方案")
                // 备用方案：通过NSApplication.shared.delegate获取
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                   let existingMonitor = appDelegate.keyboardMonitor {
                    ContentView.globalKeyboardMonitor = existingMonitor
                    print("✅ 通过NSApplication获取到AppDelegate的监听器")
                } else {
                    print("❌ 无法获取AppDelegate的监听器，可能需要等待初始化完成")
                    // 再次尝试，延迟更长时间
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.setupGlobalKeyboardMonitorReference()
                    }
                }
            }
        }
    }
}