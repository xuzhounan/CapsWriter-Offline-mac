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
                    Text("声道数")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("声道数", selection: $configManager.audio.channels) {
                        Text("单声道 (推荐)").tag(1)
                        Text("立体声").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("语音识别建议使用单声道，可减少处理复杂度")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 缓冲区大小
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("缓冲区大小")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.audio.bufferSize) frames")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
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
                        Text("延迟: \(bufferLatency) ms")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("4096")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("较小的缓冲区减少延迟但可能导致音频丢失，较大的缓冲区更稳定但延迟更高")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var bufferLatency: String {
        let latency = Double(configManager.audio.bufferSize) / configManager.audio.sampleRate * 1000
        return String(format: "%.1f", latency)
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
                        Text("0.0 dB")  // 临时显示，后续可扩展配置
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    // 临时禁用滑块，后续可绑定到配置
                    Slider(value: .constant(0.0), in: -20...20, step: 0.5)
                        .disabled(true)
                    
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