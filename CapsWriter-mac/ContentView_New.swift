import SwiftUI

// MARK: - 新的 ContentView 使用新UI组件系统
struct ContentView_New: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var selectedTab = 0
    @State private var permissionCheckTimer: Timer?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 主页面 - 使用新的组件
            MainDashboard_New()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
                .tag(0)
            
            // 录音控制页面
            RecordingControlView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("录音控制")
                }
                .tag(1)
            
            // 实时转录页面
            RealTimeTranscriptionView_New()
                .tabItem {
                    Image(systemName: "text.bubble")
                    Text("实时转录")
                }
                .tag(2)
            
            // 系统状态页面
            SystemStatusView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("系统状态")
                }
                .tag(3)
        }
        .onAppear {
            checkPermissionStatus()
            startPeriodicStatusCheck()
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }
    
    // MARK: - 权限检查方法
    private func checkPermissionStatus() {
        recordingState.refreshPermissionStatus()
    }
    
    private func startPeriodicStatusCheck() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            checkPermissionStatus()
        }
    }
}

// MARK: - 新的主仪表盘
struct MainDashboard_New: View {
    @ObservedObject var recordingState = RecordingState.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: CWTheme.spacing.sectionSpacing) {
                // 应用头部
                appHeader
                
                // 录音指示器
                RecordingIndicator(
                    recordingState: recordingState,
                    style: .professional,
                    size: .large
                )
                .padding(.vertical, CWTheme.spacing.xl)
                
                // 系统状态卡片
                SystemStatusCard(
                    recordingState: recordingState,
                    onPermissionAction: { permission in
                        handlePermissionAction(permission)
                    }
                )
                
                // 性能监控卡片
                PerformanceCard()
                
                // 快速操作按钮
                quickActionButtons
            }
            .padding()
        }
        .background(CWTheme.colors.background)
        .navigationTitle("CapsWriter-mac")
    }
    
    // MARK: - 应用头部
    private var appHeader: some View {
        VStack(spacing: CWTheme.spacing.m) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(CWTheme.colors.primary)
                .breathing()
            
            VStack(spacing: CWTheme.spacing.xs) {
                Text("CapsWriter for macOS")
                    .font(CWTheme.fonts.title)
                    .fontWeight(.semibold)
                    .foregroundColor(CWTheme.colors.primaryText)
                
                Text("智能语音转录工具")
                    .font(CWTheme.fonts.subheadline)
                    .foregroundColor(CWTheme.colors.secondaryText)
            }
        }
    }
    
    // MARK: - 快速操作按钮
    private var quickActionButtons: some View {
        VStack(spacing: CWTheme.spacing.m) {
            HStack(spacing: CWTheme.spacing.m) {
                CWButton(
                    recordingState.isRecording ? "停止录音" : "开始录音",
                    icon: recordingState.isRecording ? "stop.fill" : "mic.fill",
                    style: recordingState.isRecording ? .error : .primary,
                    size: .large
                ) {
                    toggleRecording()
                }
                
                CWButton(
                    "刷新状态",
                    icon: "arrow.clockwise",
                    style: .secondary,
                    size: .large
                ) {
                    recordingState.refreshPermissionStatus()
                }
            }
            
            HStack(spacing: CWTheme.spacing.s) {
                CWButton(
                    "清空历史",
                    icon: "trash",
                    style: .ghost,
                    size: .small,
                    isDisabled: recordingState.transcriptHistory.isEmpty
                ) {
                    recordingState.clearTranscriptHistory()
                }
                
                CWButton(
                    "导出结果",
                    icon: "square.and.arrow.up",
                    style: .ghost,
                    size: .small,
                    isDisabled: recordingState.transcriptHistory.isEmpty
                ) {
                    exportTranscript()
                }
                
                CWButton(
                    "系统设置",
                    icon: "gear",
                    style: .ghost,
                    size: .small
                ) {
                    openSystemSettings()
                }
            }
        }
    }
    
    // MARK: - 操作方法
    private func toggleRecording() {
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
            if recordingState.isRecording {
                appDelegate.stopRecording()
            } else {
                appDelegate.startRecording()
            }
        }
    }
    
    private func handlePermissionAction(_ permission: PermissionType) {
        switch permission {
        case .accessibility:
            KeyboardMonitor.requestAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                recordingState.refreshPermissionStatus()
            }
        case .microphone:
            requestMicrophonePermission()
        }
    }
    
    private func requestMicrophonePermission() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .authorized:
            recordingState.refreshPermissionStatus()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.recordingState.refreshPermissionStatus()
                }
            }
        case .denied, .restricted:
            openMicrophoneSettings()
        @unknown default:
            openMicrophoneSettings()
        }
    }
    
    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func exportTranscript() {
        let transcript = recordingState.transcriptHistory
            .map { entry in "[\(entry.formattedTime)] \(entry.text)" }
            .joined(separator: "\n")
        
        let savePanel = NSSavePanel()
        savePanel.title = "导出转录文本"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "转录结果_\(Date().timeIntervalSince1970).txt"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try transcript.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ 转录文本已导出到: \(url.path)")
                } catch {
                    print("❌ 导出失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 录音控制视图
struct RecordingControlView: View {
    @ObservedObject var recordingState = RecordingState.shared
    
    var body: some View {
        VStack(spacing: CWTheme.spacing.sectionSpacing) {
            // 录音控制面板
            RecordingPanel(
                recordingState: recordingState,
                style: .prominent,
                onStartRecording: {
                    startRecording()
                },
                onStopRecording: {
                    stopRecording()
                },
                onToggleService: {
                    toggleASRService()
                }
            )
            
            // 音频可视化
            if recordingState.isRecording {
                CWCard(
                    title: "实时音频",
                    headerIcon: "waveform",
                    style: .highlighted
                ) {
                    VStack(spacing: CWTheme.spacing.m) {
                        AudioWaveform(
                            style: .colorful,
                            isAnimated: true
                        )
                        .frame(height: 80)
                        
                        SpectrumAnalyzer(
                            style: .default,
                            isAnimated: true
                        )
                        .frame(height: 120)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(CWTheme.colors.background)
        .navigationTitle("录音控制")
    }
    
    private func startRecording() {
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
            appDelegate.startRecording()
        }
    }
    
    private func stopRecording() {
        if let appDelegate = CapsWriterApp.sharedAppDelegate ?? (NSApplication.shared.delegate as? AppDelegate) {
            appDelegate.stopRecording()
        }
    }
    
    private func toggleASRService() {
        let controller = VoiceInputController.shared
        if recordingState.isASRServiceRunning {
            controller.stopListening()
        } else {
            controller.startListening()
        }
        controller.updateServiceStatusesImmediately()
    }
}

// MARK: - 新的实时转录视图
struct RealTimeTranscriptionView_New: View {
    @ObservedObject var recordingState = RecordingState.shared
    @State private var isAutoScroll = true
    
    var body: some View {
        VStack(spacing: CWTheme.spacing.sectionSpacing) {
            // 转录控制区域
            transcriptionControls
            
            // 当前转录显示
            if !recordingState.partialTranscript.isEmpty {
                currentTranscriptionCard
            }
            
            // 转录历史列表
            transcriptionHistory
        }
        .padding()
        .background(CWTheme.colors.background)
        .navigationTitle("实时转录")
    }
    
    // MARK: - 转录控制
    private var transcriptionControls: some View {
        CWCard(
            title: "转录控制",
            subtitle: "共 \(recordingState.transcriptHistory.count) 条记录",
            headerIcon: "text.bubble",
            style: .default
        ) {
            VStack(spacing: CWTheme.spacing.m) {
                // 录音状态指示器
                SimpleRecordingIndicator(
                    recordingState: recordingState,
                    size: 60
                )
                
                // 控制按钮
                HStack(spacing: CWTheme.spacing.m) {
                    CWButton(
                        recordingState.isRecording ? "停止录音" : "开始录音",
                        icon: recordingState.isRecording ? "stop.fill" : "mic.fill",
                        style: recordingState.isRecording ? .error : .primary
                    ) {
                        toggleRecording()
                    }
                    
                    CWButton(
                        "清空转录",
                        icon: "trash",
                        style: .secondary,
                        isDisabled: recordingState.transcriptHistory.isEmpty
                    ) {
                        recordingState.clearTranscriptHistory()
                    }
                }
                
                // 自动滚动开关
                Toggle("自动滚动", isOn: $isAutoScroll)
                    .toggleStyle(SwitchToggleStyle())
            }
        }
    }
    
    // MARK: - 当前转录卡片
    private var currentTranscriptionCard: some View {
        CWCard(
            title: "正在识别...",
            headerIcon: "mic.fill",
            style: .highlighted
        ) {
            Text(recordingState.partialTranscript)
                .font(CWTheme.fonts.body)
                .foregroundColor(CWTheme.colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                        .fill(CWTheme.colors.warning.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                                .stroke(CWTheme.colors.warning.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - 转录历史
    private var transcriptionHistory: some View {
        CWCard(
            title: "转录历史",
            subtitle: recordingState.transcriptHistory.isEmpty ? "暂无记录" : nil,
            headerIcon: "doc.text",
            style: .default
        ) {
            if recordingState.transcriptHistory.isEmpty {
                VStack(spacing: CWTheme.spacing.m) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(CWTheme.colors.secondaryText)
                        .opacity(0.5)
                    
                    Text("暂无转录记录")
                        .font(CWTheme.fonts.subheadline)
                        .foregroundColor(CWTheme.colors.secondaryText)
                    
                    Text("开始录音以查看转录结果")
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(CWTheme.colors.tertiaryText)
                }
                .padding(CWTheme.spacing.xl)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: CWTheme.spacing.s) {
                            ForEach(recordingState.transcriptHistory) { entry in
                                TranscriptEntryCard(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, CWTheme.spacing.s)
                    }
                    .onChange(of: recordingState.transcriptHistory.count) {
                        if isAutoScroll && !recordingState.transcriptHistory.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(recordingState.transcriptHistory.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
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
}

// MARK: - 转录条目卡片
struct TranscriptEntryCard: View {
    let entry: TranscriptEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: CWTheme.spacing.m) {
            // 时间戳
            VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                Text(entry.formattedTime)
                    .font(CWTheme.fonts.monospacedDigits)
                    .foregroundColor(CWTheme.colors.primaryText)
                
                if entry.isPartial {
                    CWLabel("部分", style: .badge)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // 转录文本
            Text(entry.text)
                .font(CWTheme.fonts.body)
                .foregroundColor(CWTheme.colors.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CWTheme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                .fill(CWTheme.colors.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                        .stroke(CWTheme.colors.border.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - 系统状态视图
struct SystemStatusView: View {
    @ObservedObject var recordingState = RecordingState.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: CWTheme.spacing.sectionSpacing) {
                // 系统状态卡片
                SystemStatusCard(
                    recordingState: recordingState,
                    onPermissionAction: { permission in
                        handlePermissionAction(permission)
                    }
                )
                
                // 性能监控卡片
                PerformanceCard()
                
                // 日志卡片
                LogCard()
            }
            .padding()
        }
        .background(CWTheme.colors.background)
        .navigationTitle("系统状态")
    }
    
    private func handlePermissionAction(_ permission: PermissionType) {
        switch permission {
        case .accessibility:
            KeyboardMonitor.requestAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                recordingState.refreshPermissionStatus()
            }
        case .microphone:
            requestMicrophonePermission()
        }
    }
    
    private func requestMicrophonePermission() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.recordingState.refreshPermissionStatus()
                }
            }
        case .denied, .restricted:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
}

// MARK: - 日志卡片
struct LogCard: View {
    @State private var logs: [String] = [
        "应用启动成功",
        "正在初始化语音识别服务...",
        "Sherpa-ONNX 引擎加载完成",
        "键盘监听器启动完成",
        "音频采集服务就绪",
        "系统状态检查完成"
    ]
    
    var body: some View {
        CWCard(
            title: "运行日志",
            subtitle: "最近 \(logs.count) 条记录",
            headerIcon: "doc.text.magnifyingglass",
            style: .default
        ) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                        HStack(alignment: .top, spacing: CWTheme.spacing.s) {
                            Text("\(index + 1)")
                                .font(CWTheme.fonts.caption2)
                                .foregroundColor(CWTheme.colors.secondaryText)
                                .frame(width: 24, alignment: .trailing)
                            
                            Text(log)
                                .font(CWTheme.fonts.caption)
                                .foregroundColor(CWTheme.colors.primaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, CWTheme.spacing.xs)
                        .padding(.vertical, CWTheme.spacing.xxs)
                        .background(
                            index % 2 == 0 ? Color.clear : CWTheme.colors.cardBackground.opacity(0.5)
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

// MARK: - 预览
#Preview {
    ContentView_New()
        .frame(width: 800, height: 600)
}