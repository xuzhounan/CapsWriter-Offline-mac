import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var animationScale: CGFloat = 1.0
    @State private var selectedTab = 0
    @State private var permissionCheckTimer: Timer?
    
    
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
            
            // 实时转录页面
            RealTimeTranscriptionView()
                .tabItem {
                    Image(systemName: "text.bubble")
                    Text("实时转录")
                }
                .tag(2)
        }
        .onAppear {
            animationScale = 1.2
            checkPermissionStatus()
            startPeriodicStatusCheck()
        }
        .onDisappear {
            // 停止定时器避免内存泄漏
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }
    
    // MARK: - 权限检查方法
    private func checkPermissionStatus() {
        recordingState.refreshPermissionStatus()
    }
    
    private func startPeriodicStatusCheck() {
        // 确保只有一个定时器运行
        permissionCheckTimer?.invalidate()
        
        // 每5秒检查一次权限状态（减少频率）
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            checkPermissionStatus()
        }
    }
}

// MARK: - 主仪表盘视图
struct MainDashboardView: View {
    @ObservedObject var recordingState: RecordingState
    @Binding var animationScale: CGFloat
    @State private var rotationAngle: Double = 0
    
    var headerSection: some View {
        VStack(spacing: 20) {
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
        }
    }
    
    var featuresSection: some View {
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
    }
    
    var statusSection: some View {
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
                    if recordingState.isASRServiceInitialized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if recordingState.isASRServiceRunning {
                        Image(systemName: "gear")
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(rotationAngle))
                            .onAppear {
                                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text("语音识别服务")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if recordingState.isASRServiceInitialized {
                        Text("就绪")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    } else if recordingState.isASRServiceRunning {
                        Text(recordingState.initializationProgress)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else {
                        Text("已停止")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
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
                
                // 语音输入服务状态
                HStack {
                    Image(systemName: recordingState.hasTextInputPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.hasTextInputPermission ? .green : .orange)
                    
                    Text("语音输入服务")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.hasTextInputPermission ? "已授权" : "等待授权")
                        .font(.caption)
                        .foregroundColor(recordingState.hasTextInputPermission ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                // 权限请求按钮
                VStack(spacing: 8) {
                    if !recordingState.hasAccessibilityPermission {
                        Button("请求辅助功能权限") {
                            KeyboardMonitor.requestAccessibilityPermission()
                            // 延迟检查权限状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                recordingState.refreshPermissionStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    if !recordingState.hasMicrophonePermission {
                        HStack(spacing: 8) {
                            Button("请求麦克风权限") {
                                requestMicrophonePermission()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("打开系统设置") {
                                openMicrophonePermissionSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                // 手动刷新按钮（调试用）
                HStack {
                    Button("刷新状态") {
                        print("🔄 手动刷新权限状态...")
                        let hasPermission = KeyboardMonitor.checkAccessibilityPermission()
                        print("📋 权限状态: \(hasPermission)")
                        recordingState.refreshPermissionStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(isKeyboardMonitorRunning(recordingState.keyboardMonitorStatus) ? "停止键盘监听" : "开始键盘监听") {
                        if isKeyboardMonitorRunning(recordingState.keyboardMonitorStatus) {
                            stopKeyboardMonitoring()
                        } else {
                            startKeyboardMonitoring()
                        }
                    }
                    .foregroundColor(isKeyboardMonitorRunning(recordingState.keyboardMonitorStatus) ? .white : .primary)
                    .background(isKeyboardMonitorRunning(recordingState.keyboardMonitorStatus) ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .controlSize(.small)
                    
                    Button(recordingState.isRecording ? "停止录音" : "开始录音") {
                        print("🎤 手动录音状态切换")
                        if recordingState.isRecording {
                            // 调用AppDelegate的停止录音方法
                            if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
                                appDelegate.stopRecording()
                            }
                        } else {
                            // 调用AppDelegate的开始录音方法
                            if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
                                appDelegate.startRecording()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(recordingState.isRecording ? .red : .blue)
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
    
    var recordingIndicator: some View {
        Group {
            
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
    }
    
    var body: some View {
        VStack(spacing: 30) {
            headerSection
            featuresSection
            statusSection
            recordingIndicator
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("CapsWriter-mac")
        .onAppear {
            animationScale = 1.2
        }
    }
    
    private func requestMicrophonePermission() {
        print("🎤 请求麦克风权限...")
        
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 当前麦克风权限状态: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            print("✅ 麦克风权限已授权")
            recordingState.refreshPermissionStatus()
            
        case .notDetermined:
            print("🔍 请求麦克风权限...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("🎤 麦克风权限请求结果: \(granted ? "已授权" : "被拒绝")")
                    self.recordingState.refreshPermissionStatus()
                }
            }
            
        case .denied, .restricted:
            print("❌ 麦克风权限被拒绝或受限，需要在系统设置中手动授权")
            openMicrophonePermissionSettings()
            
        @unknown default:
            print("⚠️ 未知的麦克风权限状态")
            openMicrophonePermissionSettings()
        }
    }
    
    private func openMicrophonePermissionSettings() {
        // 打开系统设置的隐私与安全性 -> 麦克风页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - 键盘监听控制方法
    
    private func isKeyboardMonitorRunning(_ status: String) -> Bool {
        return status == "已启动" || status == "正在监听"
    }
    
    private func startKeyboardMonitoring() {
        print("🎤 开始键盘监听...")
        
        // 简化AppDelegate获取，优先使用静态引用
        guard let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) else {
            print("❌ 无法获取AppDelegate")
            recordingState.updateKeyboardMonitorStatus("初始化失败")
            return
        }
        
        // 由于键盘监听器现在由 VoiceInputController 管理，直接调用其方法
        appDelegate.startKeyboardMonitoring()
        recordingState.userStartedKeyboardMonitor()
        print("✅ 键盘监听已启动")
    }
    
    private func stopKeyboardMonitoring() {
        print("⏹️ 停止键盘监听...")
        
        // 简化AppDelegate获取
        guard let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) else {
            print("❌ 无法获取AppDelegate")
            recordingState.userStoppedKeyboardMonitor()
            return
        }
        
        // 由于键盘监听器现在由 VoiceInputController 管理，直接调用其方法
        appDelegate.stopKeyboardMonitoring()
        recordingState.userStoppedKeyboardMonitor()
        print("✅ 键盘监听已停止")
    }
}

// MARK: - 临时占位符视图
struct ASRServicePlaceholderView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var isAutoScroll = true
    
    // 使用统一的ASR服务实例
    private var asrService: SherpaASRService? {
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
            return appDelegate.asrService
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 服务控制区域
            VStack(spacing: 16) {
                // 服务状态 - 使用统一的状态管理
                HStack {
                    if recordingState.isASRServiceInitialized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else if recordingState.isASRServiceRunning {
                        Image(systemName: "gear")
                            .foregroundColor(.orange)
                            .font(.title2)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("语音识别服务")
                            .font(.headline)
                        if recordingState.isASRServiceInitialized {
                            Text("已就绪")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if recordingState.isASRServiceRunning {
                            Text(recordingState.initializationProgress)
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("已停止")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
                
                // 控制按钮
                HStack(spacing: 12) {
                    Button(recordingState.isASRServiceRunning ? "停止服务" : "启动服务") {
                        if let service = asrService {
                            if recordingState.isASRServiceRunning {
                                service.stopService()
                            } else {
                                service.startService()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("清空日志") {
                        asrService?.logs.removeAll()
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
                            ForEach(Array((asrService?.logs ?? []).enumerated()), id: \.offset) { index, log in
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
                    .onChange(of: asrService?.logs.count ?? 0) {
                        if isAutoScroll && !(asrService?.logs.isEmpty ?? true) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo((asrService?.logs.count ?? 1) - 1, anchor: .bottom)
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

// MARK: - 实时转录视图
struct RealTimeTranscriptionView: View {
    @StateObject private var asrService: SherpaASRService
    @StateObject private var recordingState = RecordingState.shared
    @State private var isAutoScroll = true
    
    init() {
        // 获取现有的ASR服务实例
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate),
           let existingService = appDelegate.asrService {
            _asrService = StateObject(wrappedValue: existingService)
        } else {
            // 如果没有现有实例，创建新的（不应该发生）
            _asrService = StateObject(wrappedValue: SherpaASRService())
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 转录控制区域
            VStack(spacing: 16) {
                // 录音状态和控制
                HStack {
                    // 录音状态指示器
                    HStack {
                        Circle()
                            .fill(recordingState.isRecording ? Color.red : Color.gray)
                            .frame(width: 12, height: 12)
                            .scaleEffect(recordingState.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingState.isRecording)
                        
                        Text(recordingState.isRecording ? "正在录音" : "未录音")
                            .font(.headline)
                            .foregroundColor(recordingState.isRecording ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // 转录历史数量
                    Text("共 \(asrService.transcriptHistory.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 实时部分转录（当前正在识别的内容）
                if !asrService.partialTranscript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("正在识别...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(asrService.partialTranscript)
                            .font(.body)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 控制按钮
                HStack(spacing: 12) {
                    Button(recordingState.isRecording ? "停止录音" : "开始录音") {
                        toggleRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)
                    .tint(recordingState.isRecording ? .red : .blue)
                    
                    Button("清空转录") {
                        asrService.clearTranscriptHistory()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                    Button("导出文本") {
                        exportTranscript()
                    }
                    .buttonStyle(.bordered)
                    
                    Toggle("自动滚动", isOn: $isAutoScroll)
                        .toggleStyle(.switch)
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
            
            // 转录历史区域
            VStack(alignment: .leading, spacing: 8) {
                Text("转录历史")
                    .font(.headline)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(asrService.transcriptHistory) { entry in
                                TranscriptRowView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .onChange(of: asrService.transcriptHistory.count) {
                        if isAutoScroll && !asrService.transcriptHistory.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(asrService.transcriptHistory.last?.id, anchor: .bottom)
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
        .navigationTitle("实时转录")
    }
    
    private func toggleRecording() {
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
            if recordingState.isRecording {
                appDelegate.stopRecording()
            } else {
                appDelegate.startRecording()
            }
        }
    }
    
    private func exportTranscript() {
        let transcript = asrService.transcriptHistory
            .map { entry in "[\(entry.formattedTime)] \(entry.text)" }
            .joined(separator: "\n")
        
        let savePanel = NSSavePanel()
        savePanel.title = "导出转录文本"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "转录结果_\(Date().timeIntervalSince1970).txt"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try transcript.write(to: url, atomically: true, encoding: String.Encoding.utf8)
                    print("✅ 转录文本已导出到: \(url.path)")
                } catch {
                    print("❌ 导出失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 转录条目行视图
struct TranscriptRowView: View {
    let entry: TranscriptEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间戳
            Text(entry.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // 转录文本
            Text(entry.text)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 类型标识
            if entry.isPartial {
                Text("部分")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
    }
}

#Preview {
    ContentView()
}