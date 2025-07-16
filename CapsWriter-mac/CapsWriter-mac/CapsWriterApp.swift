import SwiftUI

@main
struct CapsWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 创建静态引用来保存appDelegate
    static var sharedAppDelegate: AppDelegate?
    
    init() {
        // 在应用启动时直接初始化键盘监听器
        print("🚀 CapsWriterApp init() - 开始初始化")
        setupGlobalKeyboardMonitor()
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
    
    private func setupGlobalKeyboardMonitor() {
        print("🔧 CapsWriterApp: 设置全局键盘监听器...")
        
        // 延迟一点确保应用完全启动和appDelegate已设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔧 开始创建键盘监听器...")
            print("🔧 检查静态appDelegate: \(String(describing: CapsWriterApp.sharedAppDelegate))")
            
            let monitor = KeyboardMonitor()
            
            // 设置回调 - 使用静态引用
            monitor.setCallbacks(
                startRecording: {
                    print("🎤 全局回调: 开始录音")
                    DispatchQueue.main.async {
                        if let appDelegate = CapsWriterApp.sharedAppDelegate {
                            print("✅ 使用静态appDelegate调用startRecording()")
                            appDelegate.startRecording()
                        } else {
                            print("❌ 静态appDelegate为nil，尝试NSApplication.shared.delegate")
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                print("✅ 通过NSApplication找到AppDelegate，调用startRecording()")
                                appDelegate.startRecording()
                            } else {
                                print("❌ 完全找不到AppDelegate，只更新UI状态")
                                RecordingState.shared.startRecording()
                            }
                        }
                    }
                },
                stopRecording: {
                    print("⏹️ 全局回调: 停止录音")
                    DispatchQueue.main.async {
                        if let appDelegate = CapsWriterApp.sharedAppDelegate {
                            print("✅ 使用静态appDelegate调用stopRecording()")
                            appDelegate.stopRecording()
                        } else {
                            print("❌ 静态appDelegate为nil，尝试NSApplication.shared.delegate")
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                print("✅ 通过NSApplication找到AppDelegate，调用stopRecording()")
                                appDelegate.stopRecording()
                            } else {
                                print("❌ 完全找不到AppDelegate，只更新UI状态")
                                RecordingState.shared.stopRecording()
                            }
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