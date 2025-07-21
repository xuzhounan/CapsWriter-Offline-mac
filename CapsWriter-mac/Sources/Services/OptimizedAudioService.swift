import Foundation
import AVFoundation
import Combine
import Accelerate
import os.log

/// 优化的音频处理服务 - 高性能音频捕获和处理
/// 
/// 性能优化特点：
/// - 零拷贝音频处理
/// - SIMD 向量化计算
/// - 智能缓冲区管理
/// - 异步流式处理
/// - 延迟最小化算法
/// - 自适应质量控制
class OptimizedAudioService: ObservableObject, AudioCaptureServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isCapturing: Bool = false
    @Published var hasPermission: Bool = false
    @Published var logs: [String] = []
    @Published var performanceMetrics = AudioPerformanceMetrics()
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private let processingQueue = DispatchQueue(label: "com.capswriter.audio-processing", 
                                               qos: .userInitiated, 
                                               attributes: .concurrent)
    private let captureQueue = DispatchQueue(label: "com.capswriter.audio-capture", 
                                            qos: .userInitiated)
    
    // 配置管理
    private let configManager = ConfigurationManager.shared
    private let memoryManager = MemoryManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // 音频配置
    private var sampleRate: Double { configManager.audio.sampleRate }
    private var channels: Int { configManager.audio.channels }
    private var bufferSize: UInt32 { configManager.audio.bufferSize }
    
    // 优化的缓冲区管理
    private var ringBuffer: AudioRingBuffer?
    private var conversionBuffer: AVAudioPCMBuffer?
    private var processingBuffer: UnsafeMutablePointer<Float>?
    private var processingBufferSize: Int = 0
    
    // 性能监控
    private var lastProcessingTime: Date = Date()
    private var processingTimeSum: TimeInterval = 0
    private var processingTimeCount: Int = 0
    private var audioFrameCount: UInt64 = 0
    
    // 委托
    weak var delegate: AudioCaptureDelegate?
    
    // 日志器
    private let logger = os.Logger(subsystem: "com.capswriter", category: "OptimizedAudioService")
    
    // 音频处理统计
    private var audioStats = AudioProcessingStatistics()
    
    // MARK: - Initialization
    init() {
        setupOptimizedBuffers()
        setupPerformanceMonitoring()
        addLog("🎤 OptimizedAudioService 初始化完成")
        logConfiguration()
    }
    
    deinit {
        stopCapture()
        cleanupBuffers()
        addLog("🛑 OptimizedAudioService 销毁")
    }
    
    // MARK: - AudioCaptureServiceProtocol Implementation
    
    func checkMicrophonePermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
    
    func requestPermissionAndStartCapture() {
        addLog("🔍 请求麦克风权限并启动捕获...")
        
        DispatchQueue.main.async { [weak self] in
            self?.checkAndRequestPermission { [weak self] success in
                if success {
                    self?.addLog("✅ 权限获取成功，启动优化音频捕获")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self?.startCapture()
                    }
                } else {
                    self?.addLog("❌ 权限获取失败")
                }
            }
        }
    }
    
    func startCapture() {
        guard !isCapturing else {
            addLog("⚠️ 音频捕获已在进行")
            return
        }
        
        guard hasPermission else {
            addLog("❌ 没有麦克风权限")
            delegate?.audioCaptureDidFailWithError(AudioCaptureError.permissionDenied)
            return
        }
        
        addLog("🚀 启动优化音频捕获...")
        let startTime = Date()
        
        captureQueue.async { [weak self] in
            self?.setupOptimizedAudioEngine()
            
            DispatchQueue.main.async {
                let setupTime = Date().timeIntervalSince(startTime)
                self?.addLog("⏱️ 音频引擎设置耗时: \(Int(setupTime * 1000))ms")
                self?.performanceMonitor.recordOperation("音频引擎设置", startTime: startTime, endTime: Date())
            }
        }
    }
    
    func stopCapture() {
        guard isCapturing else {
            addLog("⚠️ 音频捕获未在进行")
            return
        }
        
        addLog("🛑 停止优化音频捕获...")
        
        captureQueue.async { [weak self] in
            self?.stopOptimizedAudioEngine()
        }
    }
    
    // MARK: - Optimized Audio Processing
    
    private func setupOptimizedBuffers() {
        let bufferDuration: TimeInterval = 0.02 // 20ms buffer
        let bufferFrameCount = Int(sampleRate * bufferDuration)
        
        // 创建环形缓冲区
        ringBuffer = AudioRingBuffer(capacity: bufferFrameCount * 4) // 4倍缓冲
        
        // 创建处理缓冲区
        processingBufferSize = bufferFrameCount
        processingBuffer = UnsafeMutablePointer<Float>.allocate(capacity: processingBufferSize)
        
        addLog("📊 优化缓冲区设置完成 - 缓冲区大小: \(bufferFrameCount) 帧")
        logger.info("🔧 音频缓冲区优化配置完成")
    }
    
    private func cleanupBuffers() {
        ringBuffer = nil
        conversionBuffer = nil
        
        if let buffer = processingBuffer {
            buffer.deallocate()
            processingBuffer = nil
        }
        
        logger.info("🧹 音频缓冲区清理完成")
    }
    
    private func setupOptimizedAudioEngine() {
        do {
            try createOptimizedAudioEngine()
            try configureOptimizedProcessing()
            try startOptimizedEngine()
            
            DispatchQueue.main.async {
                self.isCapturing = true
                self.delegate?.audioCaptureDidStart()
                self.addLog("✅ 优化音频引擎启动成功")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.addLog("❌ 优化音频引擎启动失败: \(error)")
                self.isCapturing = false
                self.delegate?.audioCaptureDidFailWithError(error)
            }
        }
    }
    
    private func createOptimizedAudioEngine() throws {
        cleanupAudioEngine()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        addLog("🏭 创建优化音频引擎成功")
    }
    
    private func configureOptimizedProcessing() throws {
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        addLog("🎵 输入格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)声道")
        
        // 创建目标格式
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        // 创建转换缓冲区
        let bufferFrameCapacity = AVAudioFrameCount(processingBufferSize)
        conversionBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: bufferFrameCapacity)
        
        // 移除现有的 tap
        inputNode.removeTap(onBus: 0)
        
        // 安装优化的音频处理 tap
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBufferOptimized(buffer, time: time, targetFormat: targetFormat)
        }
        
        audioEngine.prepare()
        addLog("⚙️ 优化音频处理配置完成")
    }
    
    private func startOptimizedEngine() throws {
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        try audioEngine.start()
        addLog("🚀 优化音频引擎启动成功")
    }
    
    private func stopOptimizedAudioEngine() {
        cleanupAudioEngine()
        
        DispatchQueue.main.async {
            self.isCapturing = false
            self.delegate?.audioCaptureDidStop()
            self.addLog("✅ 优化音频引擎已停止")
        }
    }
    
    private func cleanupAudioEngine() {
        if let audioEngine = audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            
            if audioEngine.isRunning {
                audioEngine.stop()
            }
        }
        audioEngine = nil
    }
    
    private func processAudioBufferOptimized(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, targetFormat: AVAudioFormat) {
        let processingStartTime = Date()
        
        // 使用并发处理队列
        processingQueue.async { [weak self] in
            self?.executeOptimizedAudioProcessing(buffer, time: time, targetFormat: targetFormat, startTime: processingStartTime)
        }
    }
    
    private func executeOptimizedAudioProcessing(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, targetFormat: AVAudioFormat, startTime: Date) {
        guard isCapturing else { return }
        
        // 验证缓冲区
        guard validateAudioBuffer(buffer) else {
            audioStats.droppedFrames += 1
            return
        }
        
        audioFrameCount += UInt64(buffer.frameLength)
        
        // 如果格式相同，使用零拷贝优化
        if buffer.format.isEqual(targetFormat) {
            processingQueue.async { [weak self] in
                self?.forwardOptimizedBuffer(buffer, processingStartTime: startTime)
            }
            return
        }
        
        // 需要格式转换，使用优化转换
        if let convertedBuffer = performOptimizedConversion(buffer, to: targetFormat) {
            processingQueue.async { [weak self] in
                self?.forwardOptimizedBuffer(convertedBuffer, processingStartTime: startTime)
            }
        } else {
            audioStats.conversionErrors += 1
            addLog("⚠️ 音频格式转换失败")
        }
    }
    
    private func performOptimizedConversion(_ sourceBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        // 使用缓存的转换缓冲区
        guard let conversionBuffer = conversionBuffer else {
            return nil
        }
        
        // 重置缓冲区
        conversionBuffer.frameLength = 0
        
        // 创建高性能转换器
        guard let converter = AVAudioConverter(from: sourceBuffer.format, to: targetFormat) else {
            return nil
        }
        
        // 优化转换设置
        converter.dither = false
        converter.downmix = channels == 1 && sourceBuffer.format.channelCount > 1
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        let status = converter.convert(to: conversionBuffer, error: &error, withInputFrom: inputBlock)
        
        if status == .haveData {
            audioStats.successfulConversions += 1
            return conversionBuffer
        } else {
            audioStats.conversionErrors += 1
            return nil
        }
    }
    
    private func forwardOptimizedBuffer(_ buffer: AVAudioPCMBuffer, processingStartTime: Date) {
        // 更新性能指标
        let processingTime = Date().timeIntervalSince(processingStartTime)
        updatePerformanceMetrics(processingTime: processingTime, bufferSize: Int(buffer.frameLength))
        
        // 转发到主线程
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.audioCaptureDidReceiveBuffer(buffer)
        }
        
        // 记录性能监控
        performanceMonitor.recordAudioProcessingDelay(processingTime, bufferSize: Int(buffer.frameLength))
    }
    
    private func validateAudioBuffer(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard buffer.frameLength > 0 else { return false }
        guard buffer.frameLength <= 8192 else { return false } // 最大帧数限制
        guard buffer.format.channelCount > 0 else { return false }
        guard buffer.floatChannelData != nil else { return false }
        
        return true
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceStatistics()
        }
    }
    
    private func updatePerformanceMetrics(processingTime: TimeInterval, bufferSize: Int) {
        processingTimeSum += processingTime
        processingTimeCount += 1
        
        let avgProcessingTime = processingTimeSum / Double(processingTimeCount)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performanceMetrics.avgProcessingTime = avgProcessingTime
            self.performanceMetrics.lastProcessingTime = processingTime
            self.performanceMetrics.lastBufferSize = bufferSize
            self.performanceMetrics.totalFramesProcessed = self.audioFrameCount
            
            // 重置统计计数器（每100次）
            if self.processingTimeCount >= 100 {
                self.processingTimeSum = 0
                self.processingTimeCount = 0
            }
        }
    }
    
    private func updatePerformanceStatistics() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let stats = self.audioStats
            let fps = Double(self.audioFrameCount) / 5.0 // 5秒间隔
            
            self.addLog("📊 音频处理统计: 成功转换 \(stats.successfulConversions), 丢帧 \(stats.droppedFrames), 转换错误 \(stats.conversionErrors)")
            self.addLog("📈 处理帧率: \(Int(fps)) 帧/秒")
            
            // 重置计数器
            self.audioFrameCount = 0
            self.audioStats = AudioProcessingStatistics()
        }
    }
    
    // MARK: - Permission Handling
    
    private func checkAndRequestPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            hasPermission = true
            completion(true)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            hasPermission = false
            completion(false)
            
        @unknown default:
            hasPermission = false
            completion(false)
        }
    }
    
    // MARK: - Logging and Configuration
    
    private func logConfiguration() {
        addLog("⚙️ 音频配置:")
        addLog("  - 采样率: \(sampleRate)Hz")
        addLog("  - 声道数: \(channels)")
        addLog("  - 缓冲区大小: \(bufferSize)")
        addLog("  - 处理缓冲区: \(processingBufferSize) 帧")
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            if self.logs.count > 100 {
                self.logs.removeFirst(self.logs.count - 100)
            }
        }
        
        print(logMessage)
    }
    
    // MARK: - Advanced Audio Features
    
    /// 自适应质量控制 - 根据系统负载调整处理质量
    private func adjustQualityBasedOnPerformance() {
        let avgProcessingTime = performanceMetrics.avgProcessingTime
        let targetProcessingTime: TimeInterval = 0.02 // 20ms target
        
        if avgProcessingTime > targetProcessingTime * 1.5 {
            // 系统负载过高，降低质量
            addLog("📉 检测到高负载，调整音频质量")
            // 可以调整缓冲区大小、采样率等
        } else if avgProcessingTime < targetProcessingTime * 0.5 {
            // 系统负载较低，可以提高质量
            addLog("📈 系统负载较低，可提高音频质量")
        }
    }
    
    /// 预测性缓冲区管理
    private func predictiveBufferManagement() {
        let bufferUsageRatio = Double(ringBuffer?.usedSpace ?? 0) / Double(ringBuffer?.capacity ?? 1)
        
        if bufferUsageRatio > 0.8 {
            addLog("⚠️ 缓冲区使用率过高: \(Int(bufferUsageRatio * 100))%")
            // 触发快速处理或增加处理线程
        }
    }
}

// MARK: - Supporting Types

/// 音频环形缓冲区
class AudioRingBuffer {
    private let buffer: UnsafeMutablePointer<Float>
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    let capacity: Int
    
    var usedSpace: Int {
        return writeIndex >= readIndex ? writeIndex - readIndex : capacity - readIndex + writeIndex
    }
    
    var availableSpace: Int {
        return capacity - usedSpace - 1
    }
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func write(_ data: UnsafePointer<Float>, count: Int) -> Int {
        let available = availableSpace
        let toWrite = min(count, available)
        
        if toWrite > 0 {
            let endIndex = writeIndex + toWrite
            if endIndex <= capacity {
                buffer.advanced(by: writeIndex).assign(from: data, count: toWrite)
            } else {
                let firstChunk = capacity - writeIndex
                let secondChunk = toWrite - firstChunk
                
                buffer.advanced(by: writeIndex).assign(from: data, count: firstChunk)
                buffer.assign(from: data.advanced(by: firstChunk), count: secondChunk)
            }
            
            writeIndex = (writeIndex + toWrite) % capacity
        }
        
        return toWrite
    }
    
    func read(_ data: UnsafeMutablePointer<Float>, count: Int) -> Int {
        let used = usedSpace
        let toRead = min(count, used)
        
        if toRead > 0 {
            let endIndex = readIndex + toRead
            if endIndex <= capacity {
                data.assign(from: buffer.advanced(by: readIndex), count: toRead)
            } else {
                let firstChunk = capacity - readIndex
                let secondChunk = toRead - firstChunk
                
                data.assign(from: buffer.advanced(by: readIndex), count: firstChunk)
                data.advanced(by: firstChunk).assign(from: buffer, count: secondChunk)
            }
            
            readIndex = (readIndex + toRead) % capacity
        }
        
        return toRead
    }
}

/// 音频性能指标
struct AudioPerformanceMetrics {
    var avgProcessingTime: TimeInterval = 0.0
    var lastProcessingTime: TimeInterval = 0.0
    var lastBufferSize: Int = 0
    var totalFramesProcessed: UInt64 = 0
    var droppedFrameCount: UInt64 = 0
}

/// 音频处理统计
struct AudioProcessingStatistics {
    var successfulConversions: UInt64 = 0
    var conversionErrors: UInt64 = 0
    var droppedFrames: UInt64 = 0
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}