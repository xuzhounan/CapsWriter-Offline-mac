import SwiftUI

// MARK: - 录音控制面板组件
struct RecordingPanel: View {
    @ObservedObject var recordingState: RecordingState
    let style: RecordingPanelStyle
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onToggleService: () -> Void
    
    @State private var animationScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    init(
        recordingState: RecordingState,
        style: RecordingPanelStyle = .default,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void,
        onToggleService: @escaping () -> Void
    ) {
        self.recordingState = recordingState
        self.style = style
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
        self.onToggleService = onToggleService
    }
    
    var body: some View {
        CWCard(
            title: "录音控制",
            headerIcon: "mic.fill",
            style: style.cardStyle
        ) {
            VStack(spacing: CWTheme.spacing.l) {
                // 录音状态指示器
                recordingIndicator
                
                // 服务状态信息
                serviceStatusInfo
                
                // 控制按钮组
                controlButtons
                
                // 录音统计信息
                if recordingState.isRecording || !recordingState.transcriptHistory.isEmpty {
                    recordingStats
                }
            }
        }
    }
    
    // MARK: - 录音状态指示器
    @ViewBuilder
    private var recordingIndicator: some View {
        VStack(spacing: CWTheme.spacing.m) {
            // 主录音指示器
            ZStack {
                // 外圈呼吸效果
                Circle()
                    .stroke(
                        recordingState.isRecording ? CWTheme.colors.recordingActive : CWTheme.colors.recordingInactive,
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(recordingState.isRecording ? animationScale : 1.0)
                    .opacity(recordingState.isRecording ? 0.6 : 1.0)
                    .animation(
                        recordingState.isRecording ? CWTheme.animations.breathingEffect : .none,
                        value: recordingState.isRecording
                    )
                
                // 内圈填充
                Circle()
                    .fill(
                        recordingState.isRecording ? CWTheme.colors.recordingActive : CWTheme.colors.recordingInactive
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(recordingState.isRecording ? 1.1 : 1.0)
                    .animation(CWTheme.animations.stateTransition, value: recordingState.isRecording)
                
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .scaleEffect(recordingState.isRecording ? 1.2 : 1.0)
                    .animation(CWTheme.animations.stateTransition, value: recordingState.isRecording)
            }
            
            // 状态文本
            VStack(spacing: CWTheme.spacing.xs) {
                Text(recordingStatusText)
                    .font(CWTheme.fonts.headline)
                    .foregroundColor(recordingStatusColor)
                    .fontWeight(.semibold)
                
                if recordingState.isRecording {
                    Text("连击3下 O 键停止录音")
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(CWTheme.colors.secondaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("连击3下 O 键开始录音")
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(CWTheme.colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            animationScale = 1.2
        }
    }
    
    // MARK: - 服务状态信息
    @ViewBuilder
    private var serviceStatusInfo: some View {
        VStack(spacing: CWTheme.spacing.s) {
            // ASR 服务状态
            HStack {
                Image(systemName: asrServiceIcon)
                    .foregroundColor(asrServiceColor)
                    .font(.system(size: 16))
                    .rotationEffect(.degrees(recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized ? rotationAngle : 0))
                    .onAppear {
                        if recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized {
                            withAnimation(CWTheme.animations.rotationEffect) {
                                rotationAngle = 360
                            }
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("语音识别服务")
                        .font(CWTheme.fonts.subheadline)
                        .foregroundColor(CWTheme.colors.primaryText)
                    
                    Text(asrServiceStatusText)
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(asrServiceColor)
                }
                
                Spacer()
                
                CWStatusLabel(status: asrServiceStatus)
            }
            
            // 音频采集状态
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(recordingState.isAudioCaptureServiceReady ? CWTheme.colors.success : CWTheme.colors.warning)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("音频采集服务")
                        .font(CWTheme.fonts.subheadline)
                        .foregroundColor(CWTheme.colors.primaryText)
                    
                    Text(recordingState.isAudioCaptureServiceReady ? "就绪" : "等待")
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(recordingState.isAudioCaptureServiceReady ? CWTheme.colors.success : CWTheme.colors.warning)
                }
                
                Spacer()
                
                CWStatusLabel(status: recordingState.isAudioCaptureServiceReady ? .ready : .warning)
            }
        }
        .padding(CWTheme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                .fill(CWTheme.colors.cardBackground.opacity(0.5))
        )
    }
    
    // MARK: - 控制按钮组
    @ViewBuilder
    private var controlButtons: some View {
        VStack(spacing: CWTheme.spacing.m) {
            // 主要控制按钮
            HStack(spacing: CWTheme.spacing.m) {
                CWButton(
                    recordingState.isRecording ? "停止录音" : "开始录音",
                    icon: recordingState.isRecording ? "stop.fill" : "mic.fill",
                    style: recordingState.isRecording ? .error : .primary,
                    size: .large,
                    isDisabled: !canStartRecording
                ) {
                    if recordingState.isRecording {
                        onStopRecording()
                    } else {
                        onStartRecording()
                    }
                }
                
                CWButton(
                    recordingState.isASRServiceRunning ? "停止服务" : "启动服务",
                    icon: recordingState.isASRServiceRunning ? "stop.circle" : "play.circle",
                    style: .secondary,
                    size: .large,
                    isLoading: recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized
                ) {
                    onToggleService()
                }
            }
            
            // 辅助按钮
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
                    "刷新状态",
                    icon: "arrow.clockwise",
                    style: .ghost,
                    size: .small
                ) {
                    recordingState.refreshPermissionStatus()
                }
            }
        }
    }
    
    // MARK: - 录音统计信息
    @ViewBuilder
    private var recordingStats: some View {
        HStack(spacing: CWTheme.spacing.m) {
            CWValueLabel(
                title: "录音次数",
                value: "\(recordingState.transcriptHistory.count)",
                unit: "次",
                style: .compact
            )
            
            CWValueLabel(
                title: "总时长",
                value: totalRecordingDuration,
                unit: "分钟",
                style: .compact
            )
            
            if !recordingState.transcriptHistory.isEmpty {
                CWValueLabel(
                    title: "最后录音",
                    value: lastRecordingTime,
                    style: .compact
                )
            }
        }
    }
    
    // MARK: - 计算属性
    private var recordingStatusText: String {
        if recordingState.isRecording {
            return "正在录音..."
        } else if !recordingState.isASRServiceInitialized {
            return "服务未就绪"
        } else {
            return "准备就绪"
        }
    }
    
    private var recordingStatusColor: Color {
        if recordingState.isRecording {
            return CWTheme.colors.recordingActive
        } else if !recordingState.isASRServiceInitialized {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.success
        }
    }
    
    private var asrServiceIcon: String {
        if recordingState.isASRServiceInitialized {
            return "checkmark.circle.fill"
        } else if recordingState.isASRServiceRunning {
            return "gear"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var asrServiceColor: Color {
        if recordingState.isASRServiceInitialized {
            return CWTheme.colors.success
        } else if recordingState.isASRServiceRunning {
            return CWTheme.colors.processing
        } else {
            return CWTheme.colors.error
        }
    }
    
    private var asrServiceStatus: CWStatusType {
        if recordingState.isASRServiceInitialized {
            return .ready
        } else if recordingState.isASRServiceRunning {
            return .running
        } else {
            return .error
        }
    }
    
    private var asrServiceStatusText: String {
        if recordingState.isASRServiceInitialized {
            return "就绪"
        } else if recordingState.isASRServiceRunning {
            return recordingState.initializationProgress
        } else {
            return "已停止"
        }
    }
    
    private var canStartRecording: Bool {
        return recordingState.isASRServiceInitialized && 
               recordingState.isAudioCaptureServiceReady &&
               recordingState.hasMicrophonePermission
    }
    
    private var totalRecordingDuration: String {
        // 简化计算，假设每次录音平均30秒
        let totalSeconds = recordingState.transcriptHistory.count * 30
        let minutes = totalSeconds / 60
        return String(format: "%.1f", Double(minutes) / 60.0)
    }
    
    private var lastRecordingTime: String {
        guard let lastEntry = recordingState.transcriptHistory.last else { return "--:--" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: lastEntry.timestamp)
    }
    
    // MARK: - 辅助方法
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

// MARK: - 录音面板样式枚举
enum RecordingPanelStyle {
    case `default`
    case compact
    case prominent
    
    var cardStyle: CWCardStyle {
        switch self {
        case .default: return .default
        case .compact: return .transparent
        case .prominent: return .highlighted
        }
    }
}

// MARK: - 预览
#Preview {
    RecordingPanel(
        recordingState: RecordingState.shared,
        style: .default,
        onStartRecording: { print("开始录音") },
        onStopRecording: { print("停止录音") },
        onToggleService: { print("切换服务") }
    )
    .padding()
    .background(CWTheme.colors.background)
    .frame(width: 400, height: 600)
}