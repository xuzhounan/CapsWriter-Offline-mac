import SwiftUI

// MARK: - 专业录音指示器组件
struct RecordingIndicator: View {
    @ObservedObject var recordingState: RecordingState
    let style: RecordingIndicatorStyle
    let size: RecordingIndicatorSize
    let showVolumeLevel: Bool
    let showWaveform: Bool
    
    @State private var animationScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.8
    @State private var breathingScale: CGFloat = 1.0
    @State private var volumeLevel: Double = 0.0
    @State private var waveformData: [Double] = Array(repeating: 0.2, count: 20)
    @State private var animationTimer: Timer?
    
    init(
        recordingState: RecordingState,
        style: RecordingIndicatorStyle = .default,
        size: RecordingIndicatorSize = .medium,
        showVolumeLevel: Bool = true,
        showWaveform: Bool = true
    ) {
        self.recordingState = recordingState
        self.style = style
        self.size = size
        self.showVolumeLevel = showVolumeLevel
        self.showWaveform = showWaveform
    }
    
    var body: some View {
        VStack(spacing: CWTheme.spacing.m) {
            // 主指示器
            mainIndicator
            
            // 音量级别指示器
            if showVolumeLevel {
                volumeLevelIndicator
            }
            
            // 波形可视化
            if showWaveform && recordingState.isRecording {
                waveformVisualizer
            }
            
            // 状态文本
            statusText
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: recordingState.isRecording) { _ in
            updateAnimations()
        }
    }
    
    // MARK: - 主指示器
    @ViewBuilder
    private var mainIndicator: some View {
        ZStack {
            // 外层光环效果
            if recordingState.isRecording || recordingState.isASRServiceRunning {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                currentStateColor.opacity(0.3),
                                currentStateColor.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: style.glowWidth
                    )
                    .frame(width: size.outerCircleSize, height: size.outerCircleSize)
                    .scaleEffect(breathingScale)
                    .opacity(pulseOpacity)
            }
            
            // 中间环
            Circle()
                .stroke(
                    currentStateColor.opacity(0.4),
                    lineWidth: style.middleRingWidth
                )
                .frame(width: size.middleCircleSize, height: size.middleCircleSize)
                .rotationEffect(.degrees(rotationAngle))
            
            // 内圈主体
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            currentStateColor.opacity(0.9),
                            currentStateColor
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size.innerCircleSize / 2
                    )
                )
                .frame(width: size.innerCircleSize, height: size.innerCircleSize)
                .scaleEffect(animationScale)
                .overlay(
                    // 内圈图标
                    Image(systemName: currentStateIcon)
                        .font(.system(size: size.iconSize, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(recordingState.isRecording ? 1.1 : 1.0)
                        .animation(CWTheme.animations.stateTransition, value: recordingState.isRecording)
                )
            
            // 进度环（处理状态）
            if recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        Color.white.opacity(0.8),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size.innerCircleSize - 8, height: size.innerCircleSize - 8)
                    .rotationEffect(.degrees(rotationAngle))
            }
        }
    }
    
    // MARK: - 音量级别指示器
    @ViewBuilder
    private var volumeLevelIndicator: some View {
        VStack(spacing: CWTheme.spacing.xs) {
            HStack {
                Text("音量级别")
                    .font(CWTheme.fonts.caption)
                    .foregroundColor(CWTheme.colors.secondaryText)
                
                Spacer()
                
                Text("\(Int(volumeLevel * 100))%")
                    .font(CWTheme.fonts.monospacedDigits)
                    .foregroundColor(volumeLevelColor)
            }
            
            // 音量级别条
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        let threshold = Double(index) / 20.0
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                volumeLevel > threshold ? volumeLevelColor : Color.gray.opacity(0.3)
                            )
                            .frame(
                                width: (geometry.size.width - 38) / 20,
                                height: volumeLevel > threshold ? 8 : 4
                            )
                            .animation(.easeInOut(duration: 0.1), value: volumeLevel)
                    }
                }
            }
            .frame(height: 10)
        }
    }
    
    // MARK: - 波形可视化器
    @ViewBuilder
    private var waveformVisualizer: some View {
        VStack(spacing: CWTheme.spacing.xs) {
            Text("实时波形")
                .font(CWTheme.fonts.caption)
                .foregroundColor(CWTheme.colors.secondaryText)
            
            HStack(spacing: 2) {
                ForEach(0..<waveformData.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    CWTheme.colors.waveform.opacity(0.8),
                                    CWTheme.colors.waveform
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: 3,
                            height: CGFloat(waveformData[index]) * 40 + 4
                        )
                        .animation(
                            .easeInOut(duration: 0.1).delay(Double(index) * 0.01),
                            value: waveformData[index]
                        )
                }
            }
            .frame(height: 50)
        }
    }
    
    // MARK: - 状态文本
    @ViewBuilder
    private var statusText: some View {
        VStack(spacing: CWTheme.spacing.xs) {
            Text(currentStateText)
                .font(size.statusFont)
                .foregroundColor(currentStateColor)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            if let subtitle = currentSubtitle {
                Text(subtitle)
                    .font(CWTheme.fonts.caption)
                    .foregroundColor(CWTheme.colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - 计算属性
    private var currentStateColor: Color {
        switch currentRecordingState {
        case .idle: return CWTheme.colors.recordingInactive
        case .listening: return CWTheme.colors.info
        case .recording: return CWTheme.colors.recordingActive
        case .processing: return CWTheme.colors.processing
        case .completed: return CWTheme.colors.completed
        case .error: return CWTheme.colors.error
        }
    }
    
    private var currentStateIcon: String {
        switch currentRecordingState {
        case .idle: return "mic.slash"
        case .listening: return "ear"
        case .recording: return "mic.fill"
        case .processing: return "gear"
        case .completed: return "checkmark"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private var currentStateText: String {
        switch currentRecordingState {
        case .idle: return "空闲状态"
        case .listening: return "监听中..."
        case .recording: return "正在录音"
        case .processing: return "处理中..."
        case .completed: return "已完成"
        case .error: return "错误"
        }
    }
    
    private var currentSubtitle: String? {
        switch currentRecordingState {
        case .idle: return "连击3下 O 键开始录音"
        case .listening: return "等待语音输入"
        case .recording: return "连击3下 O 键停止录音"
        case .processing: return "正在识别语音内容"
        case .completed: return "识别完成"
        case .error: return "请检查服务状态"
        }
    }
    
    private var currentRecordingState: RecordingIndicatorState {
        if recordingState.isRecording {
            return .recording
        } else if recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized {
            return .processing
        } else if recordingState.isASRServiceInitialized {
            return .listening
        } else {
            return .idle
        }
    }
    
    private var volumeLevelColor: Color {
        if volumeLevel < 0.3 {
            return CWTheme.colors.success
        } else if volumeLevel < 0.7 {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.error
        }
    }
    
    // MARK: - 动画控制
    private func startAnimations() {
        // 启动动画定时器
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateWaveformData()
            updateVolumeLevel()
        }
        
        // 启动各种动画
        withAnimation(CWTheme.animations.breathingEffect) {
            breathingScale = 1.15
        }
        
        withAnimation(CWTheme.animations.recordingPulse) {
            pulseOpacity = 0.3
        }
        
        if recordingState.isASRServiceRunning && !recordingState.isASRServiceInitialized {
            withAnimation(CWTheme.animations.rotationEffect) {
                rotationAngle = 360
            }
        }
    }
    
    private func stopAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimations() {
        if recordingState.isRecording {
            withAnimation(CWTheme.animations.recordingPulse) {
                animationScale = 1.1
            }
        } else {
            withAnimation(CWTheme.animations.stateTransition) {
                animationScale = 1.0
            }
        }
    }
    
    private func updateWaveformData() {
        if recordingState.isRecording {
            waveformData = waveformData.map { _ in
                Double.random(in: 0.1...1.0)
            }
        }
    }
    
    private func updateVolumeLevel() {
        if recordingState.isRecording {
            volumeLevel = Double.random(in: 0.2...0.8)
        } else {
            volumeLevel = 0.0
        }
    }
}

// MARK: - 录音指示器状态枚举
enum RecordingIndicatorState {
    case idle           // 空闲状态 - 灰色静止
    case listening      // 监听状态 - 蓝色呼吸
    case recording      // 录音状态 - 红色脉冲
    case processing     // 处理状态 - 黄色旋转
    case completed      // 完成状态 - 绿色检查
    case error          // 错误状态 - 红色警告
}

// MARK: - 录音指示器样式枚举
enum RecordingIndicatorStyle {
    case `default`
    case minimal
    case professional
    case compact
    
    var glowWidth: CGFloat {
        switch self {
        case .default: return 4
        case .minimal: return 2
        case .professional: return 6
        case .compact: return 3
        }
    }
    
    var middleRingWidth: CGFloat {
        switch self {
        case .default: return 3
        case .minimal: return 2
        case .professional: return 4
        case .compact: return 2
        }
    }
}

// MARK: - 录音指示器尺寸枚举
enum RecordingIndicatorSize {
    case small
    case medium
    case large
    case xlarge
    
    var outerCircleSize: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 120
        case .large: return 160
        case .xlarge: return 200
        }
    }
    
    var middleCircleSize: CGFloat {
        return outerCircleSize * 0.75
    }
    
    var innerCircleSize: CGFloat {
        return outerCircleSize * 0.5
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        case .xlarge: return 40
        }
    }
    
    var statusFont: Font {
        switch self {
        case .small: return CWTheme.fonts.caption
        case .medium: return CWTheme.fonts.subheadline
        case .large: return CWTheme.fonts.headline
        case .xlarge: return CWTheme.fonts.title2
        }
    }
}

// MARK: - 简化录音指示器
struct SimpleRecordingIndicator: View {
    @ObservedObject var recordingState: RecordingState
    let size: CGFloat
    
    @State private var isAnimating = false
    
    init(recordingState: RecordingState, size: CGFloat = 40) {
        self.recordingState = recordingState
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(recordingState.isRecording ? CWTheme.colors.recordingActive : CWTheme.colors.recordingInactive)
                .frame(width: size, height: size)
                .scaleEffect(isAnimating && recordingState.isRecording ? 1.2 : 1.0)
                .animation(
                    recordingState.isRecording ? 
                    Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .none,
                    value: isAnimating
                )
            
            Image(systemName: recordingState.isRecording ? "mic.fill" : "mic.slash")
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 30) {
        RecordingIndicator(
            recordingState: RecordingState.shared,
            style: .professional,
            size: .large
        )
        
        HStack(spacing: 20) {
            SimpleRecordingIndicator(recordingState: RecordingState.shared, size: 50)
            SimpleRecordingIndicator(recordingState: RecordingState.shared, size: 40)
            SimpleRecordingIndicator(recordingState: RecordingState.shared, size: 30)
        }
    }
    .padding()
    .background(CWTheme.colors.background)
    .frame(width: 500, height: 700)
}