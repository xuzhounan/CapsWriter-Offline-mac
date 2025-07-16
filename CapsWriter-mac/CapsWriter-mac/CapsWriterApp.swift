import SwiftUI

@main
struct CapsWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // 在应用启动时直接初始化键盘监听器
        print("🚀 CapsWriterApp init() - 开始初始化")
        setupGlobalKeyboardMonitor()
    }
    
    var body: some Scene {
        Window("CapsWriter-mac", id: "main") {
            ContentView()
        }
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
    
    private func setupGlobalKeyboardMonitor() {
        print("🔧 CapsWriterApp: 设置全局键盘监听器...")
        
        // 延迟一点确保应用完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔧 开始创建键盘监听器...")
            
            let monitor = KeyboardMonitor()
            
            // 设置回调 - 调用AppDelegate的实际录音方法
            monitor.setCallbacks(
                startRecording: {
                    print("🎤 全局回调: 开始录音")
                    print("🔍 正在查找AppDelegate...")
                    print("🔍 NSApplication.shared.delegate = \(String(describing: NSApplication.shared.delegate))")
                    DispatchQueue.main.async {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            print("✅ 找到AppDelegate，调用startRecording()")
                            appDelegate.startRecording()
                        } else {
                            print("❌ 找不到AppDelegate，只更新UI状态")
                            print("❌ Delegate类型: \(type(of: NSApplication.shared.delegate))")
                            RecordingState.shared.startRecording()
                        }
                    }
                },
                stopRecording: {
                    print("⏹️ 全局回调: 停止录音")
                    print("🔍 正在查找AppDelegate...")
                    DispatchQueue.main.async {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            print("✅ 找到AppDelegate，调用stopRecording()")
                            appDelegate.stopRecording()
                        } else {
                            print("❌ 找不到AppDelegate，只更新UI状态")
                            print("❌ Delegate类型: \(type(of: NSApplication.shared.delegate))")
                            RecordingState.shared.stopRecording()
                        }
                    }
                }
            )
            
            // 启动监听
            monitor.startMonitoring()
            
            // 保存到静态变量
            ContentView.globalKeyboardMonitor = monitor
            print("✅ 全局键盘监听器已自动启动")
        }
    }
}