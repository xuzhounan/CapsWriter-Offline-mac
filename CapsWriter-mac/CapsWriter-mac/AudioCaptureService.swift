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
        
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.addLog("🎤 权限请求回调: granted=\(granted)")
                if granted {
                    self?.hasPermission = true
                    self?.addLog("✅ 麦克风权限已获取，开始启动音频采集...")
                    self?.startCapture()
                } else {
                    self?.hasPermission = false
                    self?.addLog("❌ 麦克风权限被拒绝")
                    self?.delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
                }
            }
        }
    }
    
    func startCapture() {
        guard hasPermission else {
            addLog("❌ 没有麦克风权限，无法开始采集")
            delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
            return
        }
        
        guard !isCapturing else {
            addLog("⚠️ 音频采集已在进行中")
            return
        }
        
        addLog("🎤 开始音频采集...")
        
        // 在音频队列中设置和启动音频引擎
        audioQueue.async { [weak self] in
            guard let self = self else { 
                print("⚠️ AudioCaptureService 实例已被释放")
                return 
            }
            
            self.addLog("🎧 在音频队列中开始设置音频引擎...")
            self.setupAudioEngine()
            
            guard let audioEngine = self.audioEngine else {
                DispatchQueue.main.async {
                    self.addLog("❌ 音频引擎创建失败")
                    self.delegate?.audioCaptureDidFailWithError(AudioCaptureError.engineSetupFailed)
                }
                return
            }
            
            do {
                self.addLog("🚀 尝试启动音频引擎...")
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
    }
    
    func stopCapture() {
        guard isCapturing else {
            addLog("⚠️ 音频采集未在进行中")
            return
        }
        
        addLog("⏹️ 停止音频采集...")
        
        // 在音频队列中停止音频引擎
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.audioEngine?.stop()
            self.cleanupAudioEngine()
            
            DispatchQueue.main.async {
                self.isCapturing = false
                self.addLog("✅ 音频采集已停止")
                self.delegate?.audioCaptureDidStop()
            }
        }
    }
    
    // MARK: - Permission Management
    
    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hasPermission = (status == .authorized)
        
        let statusText = switch status {
        case .authorized: "✅ 已授权"
        case .denied: "❌ 已拒绝"
        case .restricted: "❌ 受限制"
        case .notDetermined: "🔍 未确定"
        @unknown default: "❓ 未知状态"
        }
        
        addLog("🎤 麦克风权限状态: \(statusText)")
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            addLog("✅ 麦克风权限已授权")
            DispatchQueue.main.async {
                completion(true)
            }
        case .notDetermined:
            addLog("🔍 请求麦克风权限...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                let message = granted ? "✅ 用户授予了麦克风权限" : "❌ 用户拒绝了麦克风权限"
                self?.addLog(message)
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            addLog("❌ 麦克风权限被拒绝或受限")
            DispatchQueue.main.async {
                completion(false)
            }
        @unknown default:
            addLog("❓ 未知麦克风权限状态")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        addLog("🔧 配置音频引擎...")
        
        // 清理之前的音频引擎（如果存在）
        cleanupAudioEngine()
        
        addLog("🏗️ 创建新的 AVAudioEngine...")
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            addLog("❌ 无法创建音频引擎")
            return
        }
        
        addLog("⚙️ 预备音频引擎...")
        audioEngine.prepare()
        
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
            return
        }
        
        addLog("🎵 输入格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)声道")
        addLog("🎵 目标格式: \(desiredFormat.sampleRate)Hz, \(desiredFormat.channelCount)声道")
        
        addLog("🧹 移除已存在的 tap...")
        inputNode.removeTap(onBus: 0)
        
        addLog("🔌 安装音频 tap...")
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: desiredFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
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
        
        // Forward audio buffer to delegate in background queue
        audioQueue.async { [weak self] in
            self?.delegate?.audioCaptureDidReceiveBuffer(buffer)
        }
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
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .engineSetupFailed:
            return "音频引擎设置失败"
        case .captureStartFailed:
            return "音频采集启动失败"
        }
    }
}