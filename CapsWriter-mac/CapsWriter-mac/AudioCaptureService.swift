import Foundation
import AVFoundation
import Combine

protocol AudioCaptureDelegate: AnyObject {
    func audioCaptureDidReceiveBuffer(_ buffer: AVAudioPCMBuffer)
    func audioCaptureDidStart()
    func audioCaptureDidStop()
    func audioCaptureDidFailWithError(_ error: Error)
}

/// 音频采集服务协议
protocol AudioCaptureServiceProtocol: AnyObject {
    // MARK: - Properties
    var isCapturing: Bool { get }
    var hasPermission: Bool { get }
    var delegate: AudioCaptureDelegate? { get set }
    
    // MARK: - Methods
    func checkMicrophonePermission() -> Bool
    func requestPermissionAndStartCapture()
    func startCapture()
    func stopCapture()
}

class AudioCaptureService: ObservableObject, AudioCaptureServiceProtocol {
    // MARK: - Published Properties
    @Published var isCapturing: Bool = false
    @Published var hasPermission: Bool = false
    @Published var logs: [String] = []
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private let audioQueue = DispatchQueue(label: "com.capswriter.audio-capture", qos: .userInitiated)
    
    // Configuration manager
    private let configManager = ConfigurationManager.shared
    
    // Audio configuration (now from config manager)
    private var sampleRate: Double {
        return configManager.audio.sampleRate
    }
    
    private var channels: Int {
        return configManager.audio.channels
    }
    
    private var bufferSize: UInt32 {
        return configManager.audio.bufferSize
    }
    
    // Audio processing counter
    private static var bufferCount = 0
    
    // Delegate
    weak var delegate: AudioCaptureDelegate?
    
    // MARK: - Initialization
    init() {
        addLog("🎤 AudioCaptureService 初始化")
        addLog("⚙️ 音频配置: \(sampleRate)Hz, \(channels)声道, 缓冲区 \(bufferSize)")
        // 不在初始化时检查权限，避免触发 TCC 访问
        // 权限检查将在实际需要时进行
    }
    
    deinit {
        stopCapture()
        addLog("🛑 AudioCaptureService 销毁")
    }
    
    // MARK: - Public Methods
    
    /// 检查麦克风权限
    func checkMicrophonePermission() -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        return status == .granted
    }
    
    /// 仅请求权限，不启动采集
    func requestPermissionOnly(completion: @escaping (Bool) -> Void) {
        addLog("🔍 仅请求麦克风权限（不启动采集）...")
        
        // 确保在主线程中执行
        DispatchQueue.main.async { [weak self] in
            self?.checkAndRequestPermission(completion: completion)
        }
    }
    
    func requestPermissionAndStartCapture() {
        addLog("🔍 请求麦克风权限...")
        
        // 确保在主线程中执行
        DispatchQueue.main.async { [weak self] in
            self?.checkAndRequestPermission { [weak self] success in
                if success {
                    self?.addLog("✅ 权限获取成功，现在开始采集")
                    // 延迟一点确保音频设备完全准备好
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.startCapture()
                    }
                } else {
                    self?.addLog("❌ 权限获取失败，无法开始采集")
                }
            }
        }
    }
    
    private func checkAndRequestPermission(completion: @escaping (Bool) -> Void) {
        addLog("🔍 检查当前麦克风权限状态...")
        
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        addLog("🎤 当前权限状态: \(audioPermissionStatusString(currentStatus))")
        
        switch currentStatus {
        case .authorized:
            addLog("✅ 权限已授权")
            self.hasPermission = true
            completion(true)
            
        case .notDetermined:
            addLog("🔍 权限未确定，请求权限...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.addLog("🎤 权限请求完成: \(granted ? "已授权" : "被拒绝")")
                    if granted {
                        self?.hasPermission = true
                        completion(true)
                    } else {
                        self?.hasPermission = false
                        self?.addLog("❌ 用户拒绝了麦克风权限")
                        completion(false)
                    }
                }
            }
            
        case .denied, .restricted:
            addLog("❌ 麦克风权限被拒绝或受限")
            self.hasPermission = false
            completion(false)
            
        @unknown default:
            addLog("❓ 未知麦克风权限状态")
            self.hasPermission = false
            completion(false)
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
        // 使用硬件的原始格式安装tap，避免格式不匹配错误
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            // 在这里进行格式转换并处理
            self?.processAudioBuffer(buffer, targetFormat: desiredFormat)
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
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard isCapturing else { return }
        
        // 添加音频数据日志（每100帧输出一次避免刷屏）
        AudioCaptureService.bufferCount += 1
        if AudioCaptureService.bufferCount % 100 == 0 {
            addLog("🎵 已处理 \(AudioCaptureService.bufferCount) 个音频缓冲区，当前缓冲区大小: \(buffer.frameLength)")
        }
        
        // 如果输入格式与目标格式相同，直接使用
        if buffer.format.sampleRate == targetFormat.sampleRate && 
           buffer.format.channelCount == targetFormat.channelCount {
            delegate?.audioCaptureDidReceiveBuffer(buffer)
            return
        }
        
        // 需要进行格式转换
        guard let convertedBuffer = convertAudioBuffer(buffer, to: targetFormat) else {
            // 转换失败时记录日志但不中断处理
            if AudioCaptureService.bufferCount % 1000 == 0 {
                addLog("⚠️ 音频格式转换失败，跳过此缓冲区")
            }
            return
        }
        
        // 使用转换后的缓冲区
        delegate?.audioCaptureDidReceiveBuffer(convertedBuffer)
    }
    
    /// 音频格式转换方法
    /// 将输入音频缓冲区从源格式转换为目标格式
    /// - Parameters:
    ///   - sourceBuffer: 源音频缓冲区
    ///   - targetFormat: 目标音频格式
    /// - Returns: 转换后的音频缓冲区，失败时返回nil
    private func convertAudioBuffer(_ sourceBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sourceFormat = sourceBuffer.format
        
        // 创建音频转换器
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            addLog("❌ 无法创建音频转换器")
            return nil
        }
        
        // 计算目标缓冲区的帧数
        let capacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * targetFormat.sampleRate / sourceFormat.sampleRate)
        
        // 创建目标缓冲区
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            addLog("❌ 无法创建目标音频缓冲区")
            return nil
        }
        
        // 配置转换器属性（如果需要）
        if sourceFormat.channelCount != targetFormat.channelCount {
            // 单声道/立体声转换
            converter.channelMap = sourceFormat.channelCount > targetFormat.channelCount ? [0] : [0, 0]
        }
        
        // 执行音频转换
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        let status = converter.convert(to: targetBuffer, error: &error, withInputFrom: inputBlock)
        
        // 检查转换结果
        switch status {
        case .haveData:
            // 转换成功，记录详细信息（降低日志频率）
            if AudioCaptureService.bufferCount % 2000 == 0 {
                addLog("✅ 音频格式转换成功: \(sourceFormat.sampleRate)Hz→\(targetFormat.sampleRate)Hz, \(sourceFormat.channelCount)→\(targetFormat.channelCount)声道")
            }
            return targetBuffer
            
        case .error:
            if let error = error {
                addLog("❌ 音频转换失败: \(error.localizedDescription)")
            } else {
                addLog("❌ 音频转换失败: 未知错误")
            }
            return nil
            
        case .inputRanDry:
            addLog("⚠️ 音频转换输入数据不足")
            return nil
            
        @unknown default:
            addLog("⚠️ 音频转换返回未知状态")
            return nil
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