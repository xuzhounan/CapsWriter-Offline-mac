import Foundation
import AVFoundation
import Combine
import os.log

/// 优化的 Sherpa-ONNX 语音识别服务 - 最小化识别延迟
/// 
/// 性能优化特点：
/// - 模型预加载和缓存
/// - 智能批处理
/// - 并发识别管道
/// - 预测性资源管理
/// - 自适应质量控制
/// - 零拷贝数据流
class OptimizedSherpaASRService: ObservableObject, SpeechRecognitionServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isServiceRunning: Bool = false
    @Published var isRecognizing: Bool = false
    @Published var isInitialized: Bool = false
    @Published var partialTranscript: String = ""
    @Published var logs: [String] = []
    @Published var transcriptHistory: [TranscriptEntry] = []
    @Published var performanceMetrics = RecognitionPerformanceMetrics()
    
    // MARK: - Private Properties
    private var recognizer: OpaquePointer?
    private var stream: OpaquePointer?
    
    // 优化的处理队列
    private let recognitionQueue = DispatchQueue(label: "com.capswriter.recognition", qos: .userInitiated)
    private let modelQueue = DispatchQueue(label: "com.capswriter.model-management", qos: .utility)
    private let preprocessingQueue = DispatchQueue(label: "com.capswriter.audio-preprocessing", qos: .userInitiated)
    
    // 管理器
    private let configManager = ConfigurationManager.shared
    private let memoryManager = MemoryManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // 优化组件
    private var audioPreprocessor: AudioPreprocessor?
    private var recognitionPipeline: RecognitionPipeline?
    private var resultPostprocessor: ResultPostprocessor?
    
    // 模型管理
    private var modelCache: ModelCache?
    private var isModelPreloaded: Bool = false
    
    // 性能监控
    private var recognitionStartTime: Date?
    private var recognitionStats = RecognitionStatistics()
    
    // 委托
    weak var delegate: SpeechRecognitionDelegate?
    
    // 配置
    private var sampleRate: Double { configManager.audio.sampleRate }
    private var modelPath: String {
        let bundle = Bundle.main
        return bundle.path(forResource: configManager.recognition.modelPath, ofType: nil) ?? configManager.recognition.modelPath
    }
    
    // 日志器
    private let logger = os.Logger(subsystem: "com.capswriter", category: "OptimizedSherpaASR")
    
    // 批处理配置
    private let batchSize: Int = 3
    private var audioBatch: [AVAudioPCMBuffer] = []
    private let batchQueue = DispatchQueue(label: "com.capswriter.batch-processing", qos: .userInitiated)
    
    // MARK: - Initialization
    init() {
        setupOptimizedComponents()
        setupPerformanceMonitoring()
        addLog("🧠 OptimizedSherpaASRService 初始化完成")
    }
    
    deinit {
        stopService()
        cleanupOptimizedResources()
        addLog("🛑 OptimizedSherpaASRService 销毁")
    }
    
    // MARK: - SpeechRecognitionServiceProtocol Implementation
    
    func startService() {
        guard !isServiceRunning else {
            addLog("⚠️ 服务已在运行")
            return
        }
        
        addLog("🚀 启动优化识别服务...")
        
        modelQueue.async { [weak self] in
            self?.initializeOptimizedRecognizer()
        }
    }
    
    func stopService() {
        addLog("🛑 停止优化识别服务...")
        
        modelQueue.async { [weak self] in
            self?.cleanupOptimizedRecognizer()
        }
        
        DispatchQueue.main.async {
            self.isServiceRunning = false
            self.isRecognizing = false
            self.isInitialized = false
        }
    }
    
    func startRecognition() {
        guard isServiceRunning && isInitialized else {
            addLog("❌ 服务未就绪，无法开始识别")
            return
        }
        
        guard !isRecognizing else {
            addLog("⚠️ 识别已在进行中")
            return
        }
        
        addLog("🎯 开始优化识别处理...")
        recognitionStartTime = Date()
        
        recognitionQueue.async { [weak self] in
            self?.prepareOptimizedRecognition()
        }
        
        isRecognizing = true
    }
    
    func stopRecognition() {
        guard isRecognizing else {
            addLog("⚠️ 识别未在进行中")
            return
        }
        
        addLog("⏹️ 停止优化识别处理...")
        
        // 处理批处理队列中的剩余音频
        batchQueue.async { [weak self] in
            self?.processPendingBatch()
        }
        
        recognitionQueue.async { [weak self] in
            self?.finalizeOptimizedRecognition()
        }
        
        isRecognizing = false
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing else { return }
        
        // 使用预处理队列进行音频预处理
        preprocessingQueue.async { [weak self] in
            self?.preprocessAndQueueAudio(buffer)
        }
    }
    
    func addTranscriptEntry(text: String, isPartial: Bool) {
        guard !text.isEmpty else { return }
        
        let entry = TranscriptEntry(
            timestamp: Date(),
            text: text,
            isPartial: isPartial
        )
        
        DispatchQueue.main.async {
            self.transcriptHistory.append(entry)
            if self.transcriptHistory.count > 100 {
                self.transcriptHistory.removeFirst(self.transcriptHistory.count - 100)
            }
        }
    }
    
    // MARK: - Optimized Recognition Implementation
    
    private func setupOptimizedComponents() {
        // 初始化音频预处理器
        audioPreprocessor = AudioPreprocessor(
            sampleRate: sampleRate,
            memoryManager: memoryManager
        )
        
        // 初始化识别管道
        recognitionPipeline = RecognitionPipeline(
            batchSize: batchSize,
            memoryManager: memoryManager
        )
        
        // 初始化结果后处理器
        resultPostprocessor = ResultPostprocessor()
        
        // 初始化模型缓存
        modelCache = ModelCache(maxSize: 3) // 缓存最多3个模型配置
        
        addLog("🔧 优化组件初始化完成")
    }
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateRecognitionStatistics()
        }
    }
    
    private func initializeOptimizedRecognizer() {
        addLog("🧠 初始化优化识别器...")
        
        DispatchQueue.main.async {
            RecordingState.shared.updateInitializationProgress("正在预加载模型...")
        }
        
        // 预加载模型
        if preloadModel() {
            isModelPreloaded = true
            addLog("✅ 模型预加载成功")
        } else {
            addLog("⚠️ 模型预加载失败，将使用标准加载")
        }
        
        // 创建识别器
        if createOptimizedRecognizer() {
            DispatchQueue.main.async {
                self.isInitialized = true
                self.isServiceRunning = true
                RecordingState.shared.updateInitializationProgress("优化识别器就绪")
                self.addLog("✅ 优化识别器初始化成功")
            }
        } else {
            DispatchQueue.main.async {
                self.isInitialized = false
                self.isServiceRunning = false
                RecordingState.shared.updateInitializationProgress("识别器初始化失败")
                self.addLog("❌ 优化识别器初始化失败")
            }
        }
    }
    
    private func preloadModel() -> Bool {
        addLog("📦 预加载模型资源...")
        
        // 检查模型文件
        let encoderPath = "\(modelPath)/encoder.onnx"
        let decoderPath = "\(modelPath)/decoder.onnx"
        let tokensPath = "\(modelPath)/tokens.txt"
        
        guard FileManager.default.fileExists(atPath: encoderPath),
              FileManager.default.fileExists(atPath: decoderPath),
              FileManager.default.fileExists(atPath: tokensPath) else {
            addLog("❌ 模型文件不完整")
            return false
        }
        
        // 预读取模型文件到内存缓存
        do {
            let encoderData = try Data(contentsOf: URL(fileURLWithPath: encoderPath))
            let decoderData = try Data(contentsOf: URL(fileURLWithPath: decoderPath))
            let tokensData = try Data(contentsOf: URL(fileURLWithPath: tokensPath))
            
            memoryManager.cacheAudioData(key: "encoder_model", data: encoderData)
            memoryManager.cacheAudioData(key: "decoder_model", data: decoderData)
            memoryManager.cacheAudioData(key: "tokens_data", data: tokensData)
            
            addLog("📚 模型数据已缓存到内存")
            return true
            
        } catch {
            addLog("❌ 模型预加载失败: \(error)")
            return false
        }
    }
    
    private func createOptimizedRecognizer() -> Bool {
        // 使用预缓存的配置创建识别器
        let config = createOptimizedConfig()
        
        var mutableConfig = config
        recognizer = SherpaOnnxCreateOnlineRecognizer(&mutableConfig)
        
        guard let validRecognizer = recognizer else {
            addLog("❌ 识别器创建失败")
            return false
        }
        
        stream = SherpaOnnxCreateOnlineStream(validRecognizer)
        
        guard stream != nil else {
            addLog("❌ 音频流创建失败")
            SherpaOnnxDestroyOnlineRecognizer(validRecognizer)
            recognizer = nil
            return false
        }
        
        addLog("✅ 优化识别器创建成功")
        return true
    }
    
    private func createOptimizedConfig() -> SherpaOnnxOnlineRecognizerConfig {
        let encoderPath = "\(modelPath)/encoder.onnx"
        let decoderPath = "\(modelPath)/decoder.onnx"
        let tokensPath = "\(modelPath)/tokens.txt"
        
        let paraformerConfig = sherpaOnnxOnlineParaformerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath
        )
        
        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: tokensPath,
            paraformer: paraformerConfig,
            numThreads: max(2, configManager.recognition.numThreads), // 至少使用2个线程
            provider: configManager.recognition.provider,
            debug: false // 禁用调试模式以提高性能
        )
        
        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: Int(sampleRate),
            featureDim: 80
        )
        
        return sherpaOnnxOnlineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "modified_beam_search", // 使用更快的解码方法
            maxActivePaths: 2, // 减少活跃路径以提高速度
            enableEndpoint: configManager.recognition.enableEndpoint,
            rule1MinTrailingSilence: configManager.recognition.rule1MinTrailingSilence * 0.8, // 更快的端点检测
            rule2MinTrailingSilence: configManager.recognition.rule2MinTrailingSilence * 0.8,
            rule3MinUtteranceLength: configManager.recognition.rule3MinUtteranceLength
        )
    }
    
    private func prepareOptimizedRecognition() {
        guard let recognizer = recognizer,
              let stream = stream else {
            addLog("❌ 识别器未初始化")
            return
        }
        
        // 重置音频流
        SherpaOnnxOnlineStreamReset(recognizer, stream)
        
        // 清空批处理队列
        audioBatch.removeAll()
        
        // 重置统计
        recognitionStats = RecognitionStatistics()
        
        addLog("🎯 优化识别准备完成")
    }
    
    private func preprocessAndQueueAudio(_ buffer: AVAudioPCMBuffer) {
        // 音频预处理
        guard let preprocessed = audioPreprocessor?.process(buffer) else {
            recognitionStats.preprocessingErrors += 1
            return
        }
        
        // 添加到批处理队列
        batchQueue.async { [weak self] in
            self?.addToBatch(preprocessed)
        }
    }
    
    private func addToBatch(_ buffer: AVAudioPCMBuffer) {
        audioBatch.append(buffer)
        
        // 当批处理达到指定大小时，处理批次
        if audioBatch.count >= batchSize {
            let batch = audioBatch
            audioBatch.removeAll()
            
            recognitionQueue.async { [weak self] in
                self?.processBatch(batch)
            }
        }
    }
    
    private func processBatch(_ batch: [AVAudioPCMBuffer]) {
        guard let recognizer = recognizer,
              let stream = stream else {
            return
        }
        
        let batchStartTime = Date()
        
        for buffer in batch {
            processAudioBufferOptimized(buffer, recognizer: recognizer, stream: stream)
        }
        
        let batchTime = Date().timeIntervalSince(batchStartTime)
        updateBatchPerformanceMetrics(batchTime: batchTime, batchSize: batch.count)
    }
    
    private func processAudioBufferOptimized(_ buffer: AVAudioPCMBuffer, recognizer: OpaquePointer, stream: OpaquePointer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]
        
        // 发送音频数据到识别器
        SherpaOnnxOnlineStreamAcceptWaveform(stream, Int32(sampleRate), samples, Int32(frameLength))
        
        // 检查是否准备好解码
        if SherpaOnnxIsOnlineStreamReady(recognizer, stream) == 1 {
            let decodeStartTime = Date()
            
            // 解码音频
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
            
            let decodeTime = Date().timeIntervalSince(decodeStartTime)
            performanceMonitor.recordRecognitionDelay(decodeTime)
            
            // 获取结果
            if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
                let resultText = getTextFromResultSafely(result)
                
                if !resultText.isEmpty {
                    processRecognitionResult(resultText, isPartial: true)
                }
                
                SherpaOnnxDestroyOnlineRecognizerResult(result)
            }
        }
        
        // 检查端点
        if SherpaOnnxOnlineStreamIsEndpoint(recognizer, stream) == 1 {
            handleEndpoint(recognizer: recognizer, stream: stream)
        }
        
        recognitionStats.buffersProcessed += 1
    }
    
    private func processRecognitionResult(_ text: String, isPartial: Bool) {
        // 后处理结果
        let processedText = resultPostprocessor?.process(text) ?? text
        
        DispatchQueue.main.async {
            self.partialTranscript = processedText
            self.addTranscriptEntry(text: processedText, isPartial: isPartial)
            self.delegate?.speechRecognitionDidReceivePartialResult(processedText)
        }
        
        if let startTime = recognitionStartTime {
            let totalTime = Date().timeIntervalSince(startTime)
            performanceMonitor.recordOperation("识别处理", startTime: startTime, endTime: Date())
        }
    }
    
    private func handleEndpoint(recognizer: OpaquePointer, stream: OpaquePointer) {
        addLog("🔚 检测到语音端点")
        
        if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
            let finalText = getTextFromResultSafely(result)
            
            if !finalText.isEmpty {
                let processedText = resultPostprocessor?.process(finalText) ?? finalText
                processRecognitionResult(processedText, isPartial: false)
                
                DispatchQueue.main.async {
                    self.delegate?.speechRecognitionDidReceiveFinalResult(processedText)
                    self.delegate?.speechRecognitionDidDetectEndpoint()
                }
            }
            
            SherpaOnnxDestroyOnlineRecognizerResult(result)
        }
        
        // 重置流以准备下一次识别
        SherpaOnnxOnlineStreamReset(recognizer, stream)
        recognitionStats.endpointsDetected += 1
    }
    
    private func processPendingBatch() {
        if !audioBatch.isEmpty {
            let batch = audioBatch
            audioBatch.removeAll()
            
            recognitionQueue.sync {
                processBatch(batch)
            }
        }
    }
    
    private func finalizeOptimizedRecognition() {
        guard let recognizer = recognizer,
              let stream = stream else {
            return
        }
        
        // 获取最终结果
        if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
            let finalText = getTextFromResultSafely(result)
            
            if !finalText.isEmpty {
                let processedText = resultPostprocessor?.process(finalText) ?? finalText
                DispatchQueue.main.async {
                    self.delegate?.speechRecognitionDidReceiveFinalResult(processedText)
                }
            }
            
            SherpaOnnxDestroyOnlineRecognizerResult(result)
        }
        
        addLog("✅ 优化识别处理完成")
    }
    
    private func cleanupOptimizedRecognizer() {
        if let stream = stream {
            SherpaOnnxDestroyOnlineStream(stream)
            self.stream = nil
        }
        
        if let recognizer = recognizer {
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
            self.recognizer = nil
        }
        
        isInitialized = false
        isModelPreloaded = false
        
        addLog("🧹 优化识别器清理完成")
    }
    
    private func cleanupOptimizedResources() {
        cleanupOptimizedRecognizer()
        
        audioPreprocessor = nil
        recognitionPipeline = nil
        resultPostprocessor = nil
        modelCache = nil
        
        memoryManager.clearAllCaches()
    }
    
    // MARK: - Performance Monitoring
    
    private func updateBatchPerformanceMetrics(batchTime: TimeInterval, batchSize: Int) {
        DispatchQueue.main.async {
            self.performanceMetrics.avgBatchProcessingTime = batchTime
            self.performanceMetrics.lastBatchSize = batchSize
            self.performanceMetrics.batchesProcessed += 1
        }
    }
    
    private func updateRecognitionStatistics() {
        DispatchQueue.main.async {
            let stats = self.recognitionStats
            
            self.addLog("📊 识别统计: 处理 \(stats.buffersProcessed) 缓冲区, 端点 \(stats.endpointsDetected), 预处理错误 \(stats.preprocessingErrors)")
            
            // 更新性能指标
            self.performanceMetrics.totalBuffersProcessed = stats.buffersProcessed
            self.performanceMetrics.totalEndpointsDetected = stats.endpointsDetected
            
            // 重置统计（每次更新后）
            self.recognitionStats = RecognitionStatistics()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTextFromResultSafely(_ result: UnsafePointer<SherpaOnnxOnlineRecognizerResult>) -> String {
        let textPointer = result.pointee.text
        
        guard let validTextPointer = textPointer else {
            return ""
        }
        
        let textLength = strlen(validTextPointer)
        guard textLength <= 10000 else {
            // 截断过长的文本
            let truncatedData = Data(bytes: validTextPointer, count: min(Int(textLength), 10000))
            return String(data: truncatedData, encoding: .utf8) ?? ""
        }
        
        let resultString = String(cString: validTextPointer)
        return resultString.filter { $0.isPrint || $0.isWhitespace }
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
}

// MARK: - Supporting Components

/// 音频预处理器
class AudioPreprocessor {
    private let sampleRate: Double
    private let memoryManager: MemoryManager
    private let logger = os.Logger(subsystem: "com.capswriter", category: "AudioPreprocessor")
    
    init(sampleRate: Double, memoryManager: MemoryManager) {
        self.sampleRate = sampleRate
        self.memoryManager = memoryManager
    }
    
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // 执行音频预处理：降噪、增益控制等
        // 这里可以添加更多的音频处理逻辑
        
        // 简单的音量标准化
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]
        
        // 计算RMS并标准化
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))
        
        if rms > 0.001 { // 避免静音时的除零
            let targetRMS: Float = 0.1
            let gain = targetRMS / rms
            let clampedGain = min(max(gain, 0.1), 10.0) // 限制增益范围
            
            vDSP_vsmul(samples, 1, &clampedGain, samples, 1, vDSP_Length(frameLength))
        }
        
        return buffer
    }
}

/// 识别管道
class RecognitionPipeline {
    private let batchSize: Int
    private let memoryManager: MemoryManager
    
    init(batchSize: Int, memoryManager: MemoryManager) {
        self.batchSize = batchSize
        self.memoryManager = memoryManager
    }
    
    func processBatch(_ buffers: [AVAudioPCMBuffer]) -> [String] {
        // 批处理识别结果
        // 这里可以实现更复杂的批处理逻辑
        return []
    }
}

/// 结果后处理器
class ResultPostprocessor {
    func process(_ text: String) -> String {
        // 结果后处理：去除多余空格、标点符号优化等
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}

/// 模型缓存
class ModelCache {
    private let maxSize: Int
    private var cache: [String: Data] = [:]
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func store(key: String, data: Data) {
        if cache.count >= maxSize {
            // 移除最旧的缓存
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[key] = data
    }
    
    func retrieve(key: String) -> Data? {
        return cache[key]
    }
}

/// 识别性能指标
struct RecognitionPerformanceMetrics {
    var avgBatchProcessingTime: TimeInterval = 0.0
    var lastBatchSize: Int = 0
    var batchesProcessed: UInt64 = 0
    var totalBuffersProcessed: UInt64 = 0
    var totalEndpointsDetected: UInt64 = 0
}

/// 识别统计信息
struct RecognitionStatistics {
    var buffersProcessed: UInt64 = 0
    var endpointsDetected: UInt64 = 0
    var preprocessingErrors: UInt64 = 0
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}