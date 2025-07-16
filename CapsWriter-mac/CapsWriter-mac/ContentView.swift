import SwiftUI

struct ContentView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var animationScale: CGFloat = 1.0
    @State private var selectedTab = 0
    
    // 静态变量来持久化保存键盘监听器
    static var globalKeyboardMonitor: KeyboardMonitor?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 主页面 - 原有内容
            MainDashboardView(recordingState: recordingState, animationScale: $animationScale)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
                .tag(0)
            
            // 识别服务页面 - 临时内联实现
            ASRServicePlaceholderView()
                .tabItem {
                    Image(systemName: "waveform.and.mic")
                    Text("识别服务")
                }
                .tag(1)
        }
        .onAppear {
            animationScale = 1.2
            checkPermissionStatus()
            startPeriodicStatusCheck()
        }
    }
    
    // MARK: - 权限检查方法
    private func checkPermissionStatus() {
        recordingState.refreshPermissionStatus()
    }
    
    private func startPeriodicStatusCheck() {
        // 每2秒检查一次权限状态
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkPermissionStatus()
        }
    }
}

// MARK: - 主仪表盘视图
struct MainDashboardView: View {
    @ObservedObject var recordingState: RecordingState
    @Binding var animationScale: CGFloat
    
    var body: some View {
        VStack(spacing: 30) {
            // 应用图标区域
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            // 欢迎文字
            VStack(spacing: 10) {
                Text("Welcome to CapsWriter for macOS")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("音频转录工具")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 功能描述
            VStack(spacing: 8) {
                Text("功能特点：")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("实时语音转录")
                    }
                    
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.green)
                        Text("智能标点符号")
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.orange)
                        Text("多种输出格式")
                    }
                }
                .font(.subheadline)
            }
            
            // 权限和状态显示
            VStack(spacing: 12) {
                // 辅助功能权限状态
                HStack {
                    Image(systemName: recordingState.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.hasAccessibilityPermission ? .green : .red)
                    
                    Text("辅助功能权限")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.hasAccessibilityPermission ? "已授权" : "未授权")
                        .font(.caption)
                        .foregroundColor(recordingState.hasAccessibilityPermission ? .green : .red)
                        .fontWeight(.medium)
                }
                
                // 麦克风权限状态
                HStack {
                    Image(systemName: recordingState.hasMicrophonePermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.hasMicrophonePermission ? .green : .orange)
                    
                    Text("麦克风权限")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.hasMicrophonePermission ? "已授权" : "按需授权")
                        .font(.caption)
                        .foregroundColor(recordingState.hasMicrophonePermission ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                // 监听器状态
                HStack {
                    Image(systemName: "ear.fill")
                        .foregroundColor(.blue)
                    
                    Text("键盘监听器")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.keyboardMonitorStatus)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // 语音识别服务状态
                HStack {
                    Image(systemName: recordingState.isASRServiceRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.isASRServiceRunning ? .green : .red)
                    
                    Text("语音识别服务")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.isASRServiceRunning ? "运行中" : "已停止")
                        .font(.caption)
                        .foregroundColor(recordingState.isASRServiceRunning ? .green : .red)
                        .fontWeight(.medium)
                }
                
                // 音频采集服务状态
                HStack {
                    Image(systemName: recordingState.isAudioCaptureServiceReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.isAudioCaptureServiceReady ? .green : .orange)
                    
                    Text("音频采集服务")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.isAudioCaptureServiceReady ? "就绪" : "等待")
                        .font(.caption)
                        .foregroundColor(recordingState.isAudioCaptureServiceReady ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                // 权限请求按钮
                VStack(spacing: 8) {
                    if !recordingState.hasAccessibilityPermission {
                        Button("请求辅助功能权限") {
                            KeyboardMonitor.requestAccessibilityPermission()
                            // 延迟检查权限状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                checkPermissionStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    if !recordingState.hasMicrophonePermission {
                        Button("打开系统设置授权麦克风") {
                            openMicrophonePermissionSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // 手动刷新按钮（调试用）
                HStack {
                    Button("刷新状态") {
                        print("🔄 手动刷新权限状态...")
                        let hasPermission = KeyboardMonitor.checkAccessibilityPermission()
                        print("📋 权限状态: \(hasPermission)")
                        checkPermissionStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("同步AppDelegate监听器") {
                        print("🔄 同步AppDelegate中的键盘监听器...")
                        
                        // 优先使用AppDelegate中的监听器
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            print("✅ 找到AppDelegate")
                            
                            if let existingMonitor = appDelegate.keyboardMonitor {
                                // 使用AppDelegate中现有的监听器
                                ContentView.globalKeyboardMonitor = existingMonitor
                                print("✅ 已同步AppDelegate的监听器到全局引用")
                            } else {
                                print("⚠️ AppDelegate的监听器为nil，尝试重新初始化")
                                // 调用AppDelegate的监听器设置方法
                                appDelegate.setupKeyboardMonitor()
                                
                                // 延迟获取新创建的监听器
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if let newMonitor = appDelegate.keyboardMonitor {
                                        ContentView.globalKeyboardMonitor = newMonitor
                                        print("✅ 重新初始化后已同步监听器")
                                    } else {
                                        print("❌ 重新初始化后仍无法获取监听器")
                                    }
                                }
                            }
                        } else if let staticAppDelegate = CapsWriterApp.sharedAppDelegate {
                            print("✅ 使用静态AppDelegate引用")
                            
                            if let existingMonitor = staticAppDelegate.keyboardMonitor {
                                ContentView.globalKeyboardMonitor = existingMonitor
                                print("✅ 已同步静态AppDelegate的监听器到全局引用")
                            } else {
                                print("⚠️ 静态AppDelegate的监听器为nil")
                            }
                        } else {
                            print("❌ 无法找到任何AppDelegate引用")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("重置监听器") {
                        print("🔄 重置键盘监听器...")
                        
                        // 优先使用静态变量中的监听器
                        if let monitor = ContentView.globalKeyboardMonitor {
                            print("✅ 使用静态变量中的监听器进行重置")
                            monitor.resetMonitoring()
                        } else if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                                  let monitor = appDelegate.keyboardMonitor {
                            print("✅ 使用AppDelegate中的监听器进行重置")
                            monitor.resetMonitoring()
                        } else {
                            print("❌ 没有找到活跃的监听器，请先点击'强制初始化键盘监听'")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("测试录音") {
                        print("🧪 测试录音状态切换")
                        if recordingState.isRecording {
                            recordingState.stopRecording()
                        } else {
                            recordingState.startRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            )
            
            // 录音状态显示
            if recordingState.isRecording {
                VStack(spacing: 15) {
                    // 录音动画指示器
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                            .scaleEffect(animationScale)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                                value: animationScale
                            )
                        
                        Text("正在录音...")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    // 录音提示
                    Text("连击3下 O 键进行语音输入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 录音波形效果（模拟）
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 3, height: CGFloat.random(in: 10...40))
                                .animation(
                                    .easeInOut(duration: 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.05),
                                    value: recordingState.isRecording
                                )
                        }
                    }
                    .frame(height: 50)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            } else {
                // 默认状态信息
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("服务已准备就绪")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("连击3下 O 键开始录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("CapsWriter-mac")
        .onAppear {
            animationScale = 1.2
            checkPermissionStatus()
            startPeriodicStatusCheck()
        }
    }
    
    // MARK: - 权限检查方法
    private func checkPermissionStatus() {
        recordingState.refreshPermissionStatus()
    }
    
    private func startPeriodicStatusCheck() {
        // 每2秒检查一次权限状态
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkPermissionStatus()
        }
    }
    
    private func openMicrophonePermissionSettings() {
        // 打开系统设置的隐私与安全性 -> 麦克风页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 临时占位符视图
struct ASRServicePlaceholderView: View {
    @StateObject private var asrService = SherpaASRService()
    @State private var isAutoScroll = true
    
    var body: some View {
        VStack(spacing: 20) {
            // 服务控制区域
            VStack(spacing: 16) {
                // 服务状态
                HStack {
                    Image(systemName: asrService.isServiceRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(asrService.isServiceRunning ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("语音识别服务")
                            .font(.headline)
                        Text(asrService.isServiceRunning ? "运行中" : "已停止")
                            .font(.caption)
                            .foregroundColor(asrService.isServiceRunning ? .green : .red)
                    }
                    
                    Spacer()
                }
                
                // 控制按钮
                HStack(spacing: 12) {
                    Button(asrService.isServiceRunning ? "停止服务" : "启动服务") {
                        if asrService.isServiceRunning {
                            asrService.stopService()
                        } else {
                            asrService.startService()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("清空日志") {
                        asrService.logs.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            )
            
            // 日志区域
            VStack(alignment: .leading, spacing: 8) {
                Text("运行日志")
                    .font(.headline)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(asrService.logs.enumerated()), id: \.offset) { index, log in
                                HStack(alignment: .top) {
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                    
                                    Text(log)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    index % 2 == 0 ? Color.clear : Color(.controlBackgroundColor).opacity(0.5)
                                )
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .onChange(of: asrService.logs.count) {
                        if isAutoScroll && !asrService.logs.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(asrService.logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("识别服务")
    }
}

#Preview {
    ContentView()
}