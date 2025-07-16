import Foundation
import AVFoundation
import Combine

protocol AudioCaptureDelegate: AnyObject {
    func audioCaptureDidReceiveBuffer(_ buffer: AVAudioPCMBuffer)
    func audioCaptureDidStart()
    func audioCaptureDidStop()
    func audioCaptureDidFailWithError(_ error: Error)
}

class AudioCaptureService: ObservableObject {
    // MARK: - Published Properties
    @Published var isCapturing: Bool = false
    @Published var hasPermission: Bool = false
    @Published var logs: [String] = []
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private let audioQueue = DispatchQueue(label: "com.capswriter.audio-capture", qos: .userInitiated)
    
    // Audio configuration
    private let sampleRate: Double = 16000
    private let channels: Int = 1
    private let bufferSize: UInt32 = 1024
    
    // Audio processing counter
    private static var bufferCount = 0
    
    // Delegate
    weak var delegate: AudioCaptureDelegate?
    
    // MARK: - Initialization
    init() {
        addLog("🎤 AudioCaptureService 初始化")
        // 不在初始化时检查权限，避免触发 TCC 访问
        // 权限检查将在实际需要时进行
    }
    
    deinit {
        stopCapture()
        addLog("🛑 AudioCaptureService 销毁")
    }
    
    // MARK: - Public Methods
    
    func requestPermissionAndStartCapture() {
        addLog("🔍 请求麦克风权限并开始采集...")
        
        // 确保在主线程中执行
        DispatchQueue.main.async { [weak self] in
            self?.checkAndRequestPermission()
        }
    }
    
    private func checkAndRequestPermission() {
        addLog("🔍 检查当前麦克风权限状态...")
        
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        addLog("🎤 当前权限状态: \(audioPermissionStatusString(currentStatus))")
        
        switch currentStatus {
        case .authorized:
            addLog("✅ 权限已授权，延迟开始采集")
            self.hasPermission = true
            // 延迟一点确保音频设备完全准备好
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startCapture()
            }
            
        case .notDetermined:
            addLog("🔍 权限未确定，请求权限...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.addLog("🎤 权限请求完成: \(granted ? "已授权" : "被拒绝")")
                    if granted {
                        self?.hasPermission = true
                        // 延迟一点确保音频设备完全准备好
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.startCapture()
                        }
                    } else {
                        self?.hasPermission = false
                        self?.addLog("❌ 用户拒绝了麦克风权限")
                        self?.delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
                    }
                }
            }
            
        case .denied, .restricted:
            addLog("❌ 麦克风权限被拒绝或受限")
            self.hasPermission = false
            self.delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
            
        @unknown default:
            addLog("❓ 未知麦克风权限状态")
            self.hasPermission = false
            self.delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
        }
    }
    
    private func audioPermissionStatusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "未确定"
        @unknown default: return "未知状态"
        }
    }
    
    func startCapture() {
        addLog("🎤 开始音频采集...")
        
        guard hasPermission else {
            addLog("❌ 没有麦克风权限，无法开始采集")
            delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
            return
        }
        
        guard !isCapturing else {
            addLog("⚠️ 音频采集已在进行中")
            return
        }
        
        // 在音频队列中设置和启动音频引擎
        audioQueue.async { [weak self] in
            self?.setupAndStartAudioEngine()
        }
    }
    
    private func setupAndStartAudioEngine() {
        addLog("🎧 在音频队列中设置音频引擎...")
        
        do {
            try setupAudioEngine()
            
            guard let audioEngine = self.audioEngine else {
                DispatchQueue.main.async {
                    self.addLog("❌ 音频引擎创建失败")
                    self.delegate?.audioCaptureDidFailWithError(AudioCaptureError.engineSetupFailed)
                }
                return
            }
            
            addLog("🚀 尝试启动音频引擎...")
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isCapturing = true
                self.addLog("✅ 音频采集启动成功")
                self.delegate?.audioCaptureDidStart()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.addLog("❌ 音频采集启动失败: \(error.localizedDescription)")
                self.addLog("❌ 错误详情: \(error)")
                self.isCapturing = false
                self.delegate?.audioCaptureDidFailWithError(error)
            }
        }
    }
    
    func stopCapture() {
        guard isCapturing else {
            addLog("⚠️ 音频采集未在进行中")
            return
        }
        
        addLog("⏹️ 停止音频采集...")
        
        // 在音频队列中停止音频引擎
        audioQueue.async { [weak self] in
            self?.stopAudioEngine()
        }
    }
    
    private func stopAudioEngine() {
        if let audioEngine = audioEngine {
            audioEngine.stop()
            cleanupAudioEngine()
        }
        
        DispatchQueue.main.async {
            self.isCapturing = false
            self.addLog("✅ 音频采集已停止")
            self.delegate?.audioCaptureDidStop()
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        addLog("🔧 配置音频引擎...")
        
        // 清理之前的音频引擎（如果存在）
        cleanupAudioEngine()
        
        addLog("🏗️ 创建新的 AVAudioEngine...")
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        addLog("🎤 获取音频输入节点...")
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        addLog("🎵 原始输入格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)声道")
        
        // Configure desired format for speech recognition (16kHz, mono, PCM)
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            addLog("❌ 无法创建音频格式")
            throw AudioCaptureError.engineSetupFailed
        }
        
        addLog("🎵 目标格式: \(desiredFormat.sampleRate)Hz, \(desiredFormat.channelCount)声道")
        
        addLog("🧹 移除已存在的 tap...")
        inputNode.removeTap(onBus: 0)
        
        addLog("🔌 安装音频 tap...")
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: desiredFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        addLog("⚙️ 预备音频引擎...")
        audioEngine.prepare()
        addLog("✅ 音频引擎预备成功")
        
        addLog("✅ 音频引擎配置完成")
    }
    
    private func cleanupAudioEngine() {
        addLog("🧹 清理音频引擎...")
        
        if let audioEngine = audioEngine {
            // 安全地移除 tap
            audioEngine.inputNode.removeTap(onBus: 0)
            
            // 停止音频引擎
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            
            addLog("✅ 音频引擎已停止")
        }
        
        audioEngine = nil
        addLog("✅ 音频引擎清理完成")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isCapturing else { return }
        
        // 添加音频数据日志（每100帧输出一次避免刷屏）
        AudioCaptureService.bufferCount += 1
        if AudioCaptureService.bufferCount % 100 == 0 {
            addLog("🎵 已处理 \(AudioCaptureService.bufferCount) 个音频缓冲区，当前缓冲区大小: \(buffer.frameLength)")
        }
        
        // 直接在当前线程调用delegate，避免额外的队列切换
        // audioQueue已经是音频处理的专用队列，无需再次分发
        delegate?.audioCaptureDidReceiveBuffer(buffer)
    }
    
    // MARK: - Logging
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            // Keep only last 100 log entries
            if self.logs.count > 100 {
                self.logs.removeFirst(self.logs.count - 100)
            }
        }
        
        print(logMessage)
    }
}

// MARK: - Error Types

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case engineSetupFailed
    case captureStartFailed
    case audioSessionError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .engineSetupFailed:
            return "音频引擎设置失败"
        case .captureStartFailed:
            return "音频采集启动失败"
        case .audioSessionError:
            return "音频会话配置失败"
        }
    }
}