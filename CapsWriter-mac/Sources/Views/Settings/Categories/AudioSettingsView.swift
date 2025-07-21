import SwiftUI
import AVFoundation

// MARK: - Audio Settings View

/// 音频设置界面
struct AudioSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var audioDevices: [AudioDevice] = []
    @State private var selectedInputDevice: String = ""
    @State private var isTestingAudio = false
    @State private var audioLevelMeter: Double = 0.0
    @State private var testTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 音频设备设置
                AudioDeviceSection(
                    configManager: configManager,
                    audioDevices: audioDevices,
                    selectedInputDevice: $selectedInputDevice
                )
                
                // 音频格式设置
                AudioFormatSection(configManager: configManager)
                
                // 录音增强设置
                AudioEnhancementSection(configManager: configManager)
                
                // 音频测试
                AudioTestSection(
                    isTestingAudio: $isTestingAudio,
                    audioLevelMeter: $audioLevelMeter,
                    testTimer: $testTimer
                )
            }
            .padding()
        }
        .onAppear {
            loadAudioDevices()
        }
        .onDisappear {
            stopAudioTest()
        }
    }
    
    private func loadAudioDevices() {
        audioDevices = AudioDeviceHelper.getAvailableInputDevices()
        selectedInputDevice = audioDevices.first?.id ?? ""
    }
    
    private func stopAudioTest() {
        testTimer?.invalidate()
        testTimer = nil
        isTestingAudio = false
    }
}

// MARK: - Audio Device Section

struct AudioDeviceSection: View {
    @ObservedObject var configManager: ConfigurationManager
    let audioDevices: [AudioDevice]
    @Binding var selectedInputDevice: String
    
    var body: some View {
        SettingsSection(
            title: "音频设备",
            description: "选择录音设备和配置音频参数"
        ) {
            VStack(spacing: 16) {
                // 输入设备选择
                if audioDevices.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("未检测到音频输入设备")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("输入设备")
                            .font(.system(size: 14, weight: .medium))
                        
                        Picker("输入设备", selection: $selectedInputDevice) {
                            ForEach(audioDevices, id: \.id) { device in
                                HStack {
                                    Text(device.name)
                                    if device.isDefault {
                                        Text("(默认)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(device.id)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        if let selectedDevice = audioDevices.first(where: { $0.id == selectedInputDevice }) {
                            Text("支持 \(selectedDevice.channels) 声道，最高 \(Int(selectedDevice.sampleRate)) Hz")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // 设备权限状态
                AudioPermissionStatus()
            }
        }
    }
}

// MARK: - Audio Format Section

struct AudioFormatSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "音频格式",
            description: "配置录音的音频格式和质量参数"
        ) {
            VStack(spacing: 16) {
                // 采样率设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("采样率")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(Int(configManager.audio.sampleRate)) Hz")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("采样率", selection: $configManager.audio.sampleRate) {
                        Text("8000 Hz").tag(8000.0)
                        Text("16000 Hz").tag(16000.0)
                        Text("22050 Hz").tag(22050.0)
                        Text("44100 Hz").tag(44100.0)
                        Text("48000 Hz").tag(48000.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("16000 Hz 是语音识别的推荐设置，更高采样率会增加计算负担")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 声道数设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("声道数")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.audio.channels) 声道")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        // 单声道按钮
                        Button(action: {
                            configManager.audio.channels = 1
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 16))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("单声道")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("推荐")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if configManager.audio.channels == 1 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(configManager.audio.channels == 1 ? 
                                          Color.accentColor.opacity(0.1) : 
                                          Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(configManager.audio.channels == 1 ? 
                                           Color.accentColor : 
                                           Color(NSColor.separatorColor), 
                                           lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 立体声按钮
                        Button(action: {
                            configManager.audio.channels = 2
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .font(.system(size: 16))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("立体声")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("双声道")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if configManager.audio.channels == 2 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(configManager.audio.channels == 2 ? 
                                          Color.accentColor.opacity(0.1) : 
                                          Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(configManager.audio.channels == 2 ? 
                                           Color.accentColor : 
                                           Color(NSColor.separatorColor), 
                                           lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 根据选择显示不同的说明
                    HStack {
                        Image(systemName: configManager.audio.channels == 1 ? "lightbulb" : "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(configManager.audio.channels == 1 ? .green : .blue)
                        
                        Text(configManager.audio.channels == 1 ? 
                             "单声道是语音识别的推荐设置，减少处理复杂度并提高识别准确率" : 
                             "立体声会增加计算负担，但可以保留更多音频信息")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 缓冲区大小
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("缓冲区大小")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(configManager.audio.bufferSize) frames")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("延迟: \(bufferLatency) ms")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 预设值按钮组
                    VStack(spacing: 8) {
                        Text("快速设置")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach([UInt32(256), UInt32(512), UInt32(1024), UInt32(2048)], id: \.self) { size in
                                Button(action: {
                                    configManager.audio.bufferSize = size
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(size)")
                                            .font(.system(size: 12, weight: .medium))
                                        
                                        Text(bufferSizeDescription(size))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(latencyForBuffer(size)) ms")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 65, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(configManager.audio.bufferSize == size ? 
                                                  Color.accentColor.opacity(0.2) : 
                                                  Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(configManager.audio.bufferSize == size ? 
                                                   Color.accentColor : 
                                                   Color(NSColor.separatorColor), 
                                                   lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 详细滑块调节
                    VStack(spacing: 8) {
                        Text("精确调节")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(configManager.audio.bufferSize) },
                                set: { configManager.audio.bufferSize = UInt32($0) }
                            ),
                            in: 256...4096,
                            step: 256
                        )
                        
                        HStack {
                            Text("256")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1024 (推荐)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("4096")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 动态说明
                    HStack {
                        Image(systemName: bufferSizeIcon(configManager.audio.bufferSize))
                            .font(.system(size: 12))
                            .foregroundColor(bufferSizeColor(configManager.audio.bufferSize))
                        
                        Text(bufferSizeAdvice(configManager.audio.bufferSize))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var bufferLatency: String {
        let latency = Double(configManager.audio.bufferSize) / configManager.audio.sampleRate * 1000
        return String(format: "%.1f", latency)
    }
    
    // 缓冲区大小辅助函数
    private func bufferSizeDescription(_ size: UInt32) -> String {
        switch size {
        case 256: return "低延迟"
        case 512: return "快速"
        case 1024: return "推荐"
        case 2048: return "稳定"
        default: return "自定义"
        }
    }
    
    private func latencyForBuffer(_ size: UInt32) -> String {
        let latency = Double(size) / configManager.audio.sampleRate * 1000
        return String(format: "%.1f", latency)
    }
    
    private func bufferSizeIcon(_ size: UInt32) -> String {
        switch size {
        case 0...512: return "bolt.circle"
        case 513...1024: return "checkmark.circle"
        case 1025...2048: return "shield.lefthalf.filled"
        default: return "slowmo"
        }
    }
    
    private func bufferSizeColor(_ size: UInt32) -> Color {
        switch size {
        case 0...512: return .yellow
        case 513...1024: return .green
        case 1025...2048: return .blue
        default: return .orange
        }
    }
    
    private func bufferSizeAdvice(_ size: UInt32) -> String {
        switch size {
        case 0...512:
            return "低延迟设置，适合实时录制，但可能出现音频丢失"
        case 513...1024:
            return "推荐设置，在延迟和稳定性间取得良好平衡"
        case 1025...2048:
            return "高稳定性设置，延迟较高但不易丢失音频"
        default:
            return "超高缓冲，延迟很高但最稳定，适合后台录制"
        }
    }
}

// MARK: - Audio Enhancement Section

struct AudioEnhancementSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "录音增强",
            description: "配置音频处理和增强功能"
        ) {
            VStack(spacing: 16) {
                // 音频增益
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("输入增益")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.audio.inputGain, specifier: "%.1f") dB")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: $configManager.audio.inputGain,
                        in: -20...20,
                        step: 0.5
                    )
                    
                    HStack {
                        Text("-20 dB")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0 dB (原始)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+20 dB")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("调整麦克风输入音量，0 dB 为原始音量（功能开发中）")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 音频处理选项
                SettingsToggle(
                    title: "噪声抑制",
                    description: "自动减少背景噪声，提高语音识别准确率",
                    isOn: $configManager.audio.enableNoiseReduction
                )
                
                SettingsToggle(
                    title: "音频增强",
                    description: "启用音频信号增强处理，优化录音质量",
                    isOn: $configManager.audio.enableAudioEnhancement
                )
                
                // 注意：这些高级音频功能暂时使用临时状态，
                // 后续可扩展 AudioConfiguration 来支持这些配置
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        
                        Text("高级音频功能")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Text("开发中")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text("自动增益控制、回声消除、语音活动检测等高级功能正在开发中，将在后续版本中提供。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Audio Test Section

struct AudioTestSection: View {
    @Binding var isTestingAudio: Bool
    @Binding var audioLevelMeter: Double
    @Binding var testTimer: Timer?
    
    var body: some View {
        SettingsSection(
            title: "音频测试",
            description: "测试麦克风录音和音频处理功能"
        ) {
            VStack(spacing: 16) {
                // 音频电平指示器
                VStack(alignment: .leading, spacing: 8) {
                    Text("音频电平")
                        .font(.system(size: 14, weight: .medium))
                    
                    AudioLevelMeter(level: audioLevelMeter)
                    
                    HStack {
                        Text("静音")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("正常")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("过载")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 测试按钮
                HStack(spacing: 12) {
                    Button(isTestingAudio ? "停止测试" : "开始录音测试") {
                        if isTestingAudio {
                            stopAudioTest()
                        } else {
                            startAudioTest()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("播放测试音") {
                        playTestTone()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingAudio)
                    
                    Button("检测设备") {
                        detectAudioDevices()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                
                if isTestingAudio {
                    HStack {
                        Image(systemName: "mic")
                            .foregroundColor(.red)
                        Text("正在录音测试...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func startAudioTest() {
        print("🎤 开始音频测试")
        isTestingAudio = true
        
        // 启动定时器模拟音频电平
        testTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            audioLevelMeter = Double.random(in: 0...1)
        }
    }
    
    private func stopAudioTest() {
        print("🛑 停止音频测试")
        isTestingAudio = false
        testTimer?.invalidate()
        testTimer = nil
        audioLevelMeter = 0.0
    }
    
    private func playTestTone() {
        print("🔊 播放测试音")
        // 实现播放测试音频功能
    }
    
    private func detectAudioDevices() {
        print("🔍 检测音频设备")
        // 实现重新检测音频设备功能
    }
}

// MARK: - Audio Permission Status

struct AudioPermissionStatus: View {
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    var body: some View {
        HStack {
            Image(systemName: permissionIcon)
                .foregroundColor(permissionColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("麦克风权限")
                    .font(.system(size: 13, weight: .medium))
                
                Text(permissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if permissionStatus != .granted {
                Button("申请权限") {
                    requestMicrophonePermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            checkMicrophonePermission()
        }
    }
    
    private var permissionIcon: String {
        switch permissionStatus {
        case .granted: return "checkmark.circle"
        case .denied: return "xmark.circle"
        case .undetermined: return "questionmark.circle"
        @unknown default: return "exclamationmark.circle"
        }
    }
    
    private var permissionColor: Color {
        switch permissionStatus {
        case .granted: return .green
        case .denied: return .red
        case .undetermined: return .orange
        @unknown default: return .gray
        }
    }
    
    private var permissionDescription: String {
        switch permissionStatus {
        case .granted: return "已授权，可以使用麦克风"
        case .denied: return "已拒绝，请在系统设置中启用"
        case .undetermined: return "尚未申请，需要获取权限"
        @unknown default: return "权限状态未知"
        }
    }
    
    private func checkMicrophonePermission() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                permissionStatus = granted ? .granted : .denied
            }
        }
    }
}

// MARK: - Audio Level Meter

struct AudioLevelMeter: View {
    let level: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                // 电平指示器
                Rectangle()
                    .fill(levelColor)
                    .frame(width: geometry.size.width * level, height: 8)
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.1), value: level)
                
                // 刻度线
                HStack(spacing: 0) {
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 1, height: 8)
                            .opacity(0.5)
                        
                        if index < 4 {
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(height: 8)
    }
    
    private var levelColor: Color {
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Audio Device Helper

struct AudioDeviceHelper {
    static func getAvailableInputDevices() -> [AudioDevice] {
        // 模拟音频设备列表，实际实现需要调用 Core Audio API
        return [
            AudioDevice(id: "builtin", name: "内置麦克风", isDefault: true),
            AudioDevice(id: "usb", name: "USB 麦克风", channels: 2, sampleRate: 48000),
            AudioDevice(id: "bluetooth", name: "蓝牙耳机", sampleRate: 16000)
        ]
    }
}

// MARK: - Preview

#Preview {
    AudioSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 700, height: 900)
}