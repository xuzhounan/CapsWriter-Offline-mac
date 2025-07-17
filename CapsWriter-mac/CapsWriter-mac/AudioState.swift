import SwiftUI
import Combine
import AVFoundation

/// 音频相关状态管理
/// 负责管理录音控制、音频采集服务状态和音频设备状态
class AudioState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前是否正在录音
    @Published var isRecording: Bool = false
    
    /// 录音开始时间
    @Published var recordingStartTime: Date?
    
    /// 音频采集服务是否准备就绪
    @Published var isAudioCaptureServiceReady: Bool = false
    
    /// 是否有麦克风权限
    @Published var hasMicrophonePermission: Bool = false
    
    /// 音频采集状态描述
    @Published var audioCaptureStatus: String = "未初始化"
    
    /// 音频缓冲区统计
    @Published var audioBufferCount: Int = 0
    
    /// 音频设备信息
    @Published var audioDeviceInfo: AudioDeviceInfo = AudioDeviceInfo()
    
    // MARK: - Private Properties
    
    private let stateQueue = DispatchQueue(label: "com.capswriter.audio-state", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = AudioState()
    
    private init() {
        setupAudioDeviceMonitoring()
        updateMicrophonePermission()
    }
    
    // MARK: - Recording Control
    
    /// 开始录音
    func startRecording() {
        print("🎵 AudioState: 开始录音")
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStartTime = Date()
            self.updateAudioCaptureStatus("录音中")
        }
        
        // 发送录音开始通知
        NotificationCenter.default.post(
            name: .audioRecordingDidStart,
            object: self
        )
    }
    
    /// 停止录音
    func stopRecording() {
        print("🛑 AudioState: 停止录音")
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStartTime = nil
            self.updateAudioCaptureStatus("待机")
        }
        
        // 发送录音停止通知
        NotificationCenter.default.post(
            name: .audioRecordingDidStop,
            object: self
        )
    }
    
    /// 获取录音持续时间
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 格式化的录音时长显示
    var formattedRecordingDuration: String {
        let duration = recordingDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Audio Service Status
    
    /// 更新音频采集服务状态
    func updateAudioCaptureServiceStatus(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.isAudioCaptureServiceReady = isReady
            self.updateAudioCaptureStatus(isReady ? "就绪" : "未就绪")
        }
    }
    
    /// 更新音频采集状态描述
    func updateAudioCaptureStatus(_ status: String) {
        DispatchQueue.main.async {
            self.audioCaptureStatus = status
        }
    }
    
    /// 更新音频缓冲区统计
    func updateAudioBufferCount(_ count: Int) {
        DispatchQueue.main.async {
            self.audioBufferCount = count
        }
    }
    
    /// 重置音频缓冲区统计
    func resetAudioBufferCount() {
        DispatchQueue.main.async {
            self.audioBufferCount = 0
        }
    }
    
    // MARK: - Permission Management
    
    /// 更新麦克风权限状态
    func updateMicrophonePermission(_ hasPermission: Bool = false) {
        let permission = hasPermission || (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
        
        DispatchQueue.main.async {
            self.hasMicrophonePermission = permission
        }
        
        // 发送权限状态变更通知
        NotificationCenter.default.post(
            name: .microphonePermissionDidChange,
            object: self,
            userInfo: ["hasPermission": permission]
        )
    }
    
    /// 请求麦克风权限
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.updateMicrophonePermission(granted)
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// 刷新权限状态
    func refreshPermissionStatus() {
        updateMicrophonePermission()
    }
    
    // MARK: - Audio Device Management
    
    /// 设置音频设备监控
    private func setupAudioDeviceMonitoring() {
        // 监听音频设备变化
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAudioDeviceInfo()
        }
        
        // 初始化设备信息
        updateAudioDeviceInfo()
    }
    
    /// 更新音频设备信息
    private func updateAudioDeviceInfo() {
        DispatchQueue.main.async {
            self.audioDeviceInfo = AudioDeviceInfo.current()
        }
    }
    
    // MARK: - State Validation
    
    /// 验证音频系统是否准备就绪
    var isAudioSystemReady: Bool {
        return hasMicrophonePermission && isAudioCaptureServiceReady
    }
    
    /// 获取音频系统状态描述
    var audioSystemStatusDescription: String {
        if !hasMicrophonePermission {
            return "缺少麦克风权限"
        } else if !isAudioCaptureServiceReady {
            return "音频采集服务未就绪"
        } else if isRecording {
            return "录音中 (\(formattedRecordingDuration))"
        } else {
            return "音频系统就绪"
        }
    }
}

// MARK: - Audio Device Info

/// 音频设备信息
struct AudioDeviceInfo {
    let inputDeviceName: String
    let sampleRate: Double
    let channelCount: Int
    let bufferDuration: TimeInterval
    
    init(
        inputDeviceName: String = "未知设备",
        sampleRate: Double = 0,
        channelCount: Int = 0,
        bufferDuration: TimeInterval = 0
    ) {
        self.inputDeviceName = inputDeviceName
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bufferDuration = bufferDuration
    }
    
    /// 获取当前音频设备信息
    static func current() -> AudioDeviceInfo {
        let audioSession = AVAudioSession.sharedInstance()
        
        return AudioDeviceInfo(
            inputDeviceName: audioSession.currentRoute.inputs.first?.portName ?? "未知设备",
            sampleRate: audioSession.sampleRate,
            channelCount: Int(audioSession.inputNumberOfChannels),
            bufferDuration: audioSession.ioBufferDuration
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioRecordingDidStart = Notification.Name("audioRecordingDidStart")
    static let audioRecordingDidStop = Notification.Name("audioRecordingDidStop")
    static let microphonePermissionDidChange = Notification.Name("microphonePermissionDidChange")
}

// MARK: - Extensions

extension AudioState {
    
    /// 调试信息
    var debugDescription: String {
        return """
        AudioState Debug Info:
        - Recording: \(isRecording)
        - Duration: \(formattedRecordingDuration)
        - Microphone Permission: \(hasMicrophonePermission)
        - Service Ready: \(isAudioCaptureServiceReady)
        - Status: \(audioCaptureStatus)
        - Buffer Count: \(audioBufferCount)
        - Device: \(audioDeviceInfo.inputDeviceName)
        - Sample Rate: \(audioDeviceInfo.sampleRate)Hz
        """
    }
    
    /// 重置所有状态
    func resetAllStates() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStartTime = nil
            self.isAudioCaptureServiceReady = false
            self.audioCaptureStatus = "未初始化"
            self.audioBufferCount = 0
        }
        
        print("🔄 AudioState: 所有状态已重置")
    }
}