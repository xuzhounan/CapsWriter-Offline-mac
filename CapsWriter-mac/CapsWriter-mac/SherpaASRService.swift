import Foundation
import AVFoundation
import Combine

// 直接使用 C API 中的类型定义，不需要手动定义结构体

class SherpaASRService: ObservableObject {
    // MARK: - Published Properties
    @Published var logs: [String] = []
    @Published var transcript: String = ""
    @Published var isServiceRunning: Bool = false
    @Published var isRecognizing: Bool = false
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var recognizer: SherpaOnnxOnlineRecognizer?
    private var stream: SherpaOnnxOnlineStream?
    private let audioQueue = DispatchQueue(label: "com.capswriter.audio", qos: .userInitiated)
    private static var logCounter = 0
    
    // Audio configuration
    private let sampleRate: Double = 16000
    private let channels: Int = 1
    
    // Model configuration
    private let modelPath: String
    private let tokensPath: String
    private let encoderPath: String
    private let decoderPath: String
    
    // MARK: - Initialization
    init() {
        // Initialize model paths (will be configured based on actual model structure)
        let bundle = Bundle.main
        self.modelPath = bundle.path(forResource: "paraformer-zh-streaming", ofType: nil, inDirectory: "models") ?? ""
        self.tokensPath = "\(modelPath)/tokens.txt"
        self.encoderPath = "\(modelPath)/encoder.onnx"
        self.decoderPath = "\(modelPath)/decoder.onnx"
        
        addLog("🚀 SherpaASRService 初始化")
        addLog("📁 模型路径: \(modelPath)")
    }
    
    deinit {
        stopService()
        addLog("🛑 SherpaASRService 销毁")
    }
    
    // MARK: - Public Methods
    
    func startService() {
        addLog("🔄 正在启动语音识别服务...")
        
        guard !isServiceRunning else {
            addLog("⚠️ 服务已在运行中")
            return
        }
        
        // Initialize audio engine
        setupAudioEngine()
        
        // Initialize sherpa-onnx recognizer
        initializeRecognizer()
        
        isServiceRunning = true
        addLog("✅ 语音识别服务启动成功")
    }
    
    func stopService() {
        addLog("🛑 正在停止语音识别服务...")
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine = nil
        
        // Cleanup sherpa-onnx resources
        cleanupRecognizer()
        
        isServiceRunning = false
        isRecognizing = false
        addLog("✅ 语音识别服务已停止")
    }
    
    func startRecognition() {
        guard isServiceRunning else {
            addLog("❌ 服务未启动，无法开始识别")
            return
        }
        
        guard !isRecognizing else {
            addLog("⚠️ 识别已在进行中")
            return
        }
        
        addLog("🎤 开始语音识别...")
        isRecognizing = true
        
        do {
            try audioEngine?.start()
            addLog("✅ 音频引擎启动成功")
        } catch {
            addLog("❌ 音频引擎启动失败: \(error.localizedDescription)")
            isRecognizing = false
        }
    }
    
    func stopRecognition() {
        guard isRecognizing else {
            addLog("⚠️ 识别未在进行中")
            return
        }
        
        addLog("⏹️ 停止语音识别...")
        audioEngine?.stop()
        isRecognizing = false
        
        // Get final result from sherpa-onnx
        if let finalResult = getFinalResult() {
            transcript = finalResult
            addLog("📝 最终识别结果: \(finalResult)")
        }
        
        addLog("✅ 语音识别已停止")
    }
    
    // MARK: - Private Methods
    
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
    
    private func setupAudioEngine() {
        addLog("🔧 配置音频引擎...")
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            addLog("❌ 无法创建音频引擎")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Configure desired format for sherpa-onnx (16kHz, mono, PCM)
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
        
        // Install audio tap to process audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: desiredFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        addLog("✅ 音频引擎配置完成")
    }
    
    private func initializeRecognizer() {
        addLog("🧠 初始化 Sherpa-ONNX 识别器...")
        
        // Check if model files exist
        guard FileManager.default.fileExists(atPath: modelPath) else {
            addLog("❌ 模型目录不存在: \(modelPath)")
            return
        }
        
        addLog("📂 检查模型文件...")
        addLog("  - 编码器: \(encoderPath)")
        addLog("  - 解码器: \(decoderPath)")
        addLog("  - 词汇表: \(tokensPath)")
        
        // Initialize sherpa-onnx configuration using C API structures
        var paraformerConfig = SherpaOnnxOnlineParaformerModelConfig()
        paraformerConfig.encoder = UnsafePointer(strdup(encoderPath))
        paraformerConfig.decoder = UnsafePointer(strdup(decoderPath))
        
        var transducerConfig = SherpaOnnxOnlineTransducerModelConfig()
        transducerConfig.encoder = nil
        transducerConfig.decoder = nil
        transducerConfig.joiner = nil
        
        var zipformerConfig = SherpaOnnxOnlineZipformer2CtcModelConfig()
        zipformerConfig.model = nil
        
        var modelConfig = SherpaOnnxOnlineModelConfig()
        modelConfig.paraformer = paraformerConfig
        modelConfig.transducer = transducerConfig
        modelConfig.zipformer2_ctc = zipformerConfig
        modelConfig.tokens = UnsafePointer(strdup(tokensPath))
        modelConfig.num_threads = 2
        modelConfig.provider = UnsafePointer(strdup("cpu"))
        modelConfig.debug = 0
        modelConfig.model_type = UnsafePointer(strdup("paraformer"))
        modelConfig.modeling_unit = UnsafePointer(strdup("char"))
        modelConfig.bpe_vocab = nil
        modelConfig.tokens_buf = nil
        modelConfig.tokens_buf_size = 0
        
        var featConfig = SherpaOnnxFeatureConfig()
        featConfig.sample_rate = 16000
        featConfig.feature_dim = 80
        
        var ctcConfig = SherpaOnnxOnlineCtcFstDecoderConfig()
        ctcConfig.graph = nil
        ctcConfig.max_active = 3000
        
        var config = SherpaOnnxOnlineRecognizerConfig()
        config.feat_config = featConfig
        config.model_config = modelConfig
        config.decoding_method = UnsafePointer(strdup("greedy_search"))
        config.max_active_paths = 4
        config.enable_endpoint = 1
        config.rule1_min_trailing_silence = 2.4
        config.rule2_min_trailing_silence = 1.2
        config.rule3_min_utterance_length = 20.0
        config.hotwords_file = nil
        config.hotwords_score = 1.5
        config.ctc_fst_decoder_config = ctcConfig
        config.rule_fsts = nil
        config.rule_fars = nil
        
        addLog("⚙️ 创建识别器实例...")
        recognizer = SherpaOnnxCreateOnlineRecognizer(&config)
        
        if recognizer != nil {
            addLog("✅ 识别器创建成功")
            
            // Create stream
            addLog("🌊 创建音频流...")
            stream = SherpaOnnxCreateOnlineStream(recognizer)
            
            if stream != nil {
                addLog("✅ 音频流创建成功")
            } else {
                addLog("❌ 音频流创建失败")
            }
        } else {
            addLog("❌ 识别器创建失败")
        }
        
        // Cleanup allocated strings
        if let encoder = paraformerConfig.encoder {
            free(UnsafeMutableRawPointer(mutating: encoder))
        }
        if let decoder = paraformerConfig.decoder {
            free(UnsafeMutableRawPointer(mutating: decoder))
        }
        if let tokens = modelConfig.tokens {
            free(UnsafeMutableRawPointer(mutating: tokens))
        }
        if let provider = modelConfig.provider {
            free(UnsafeMutableRawPointer(mutating: provider))
        }
        if let modelType = modelConfig.model_type {
            free(UnsafeMutableRawPointer(mutating: modelType))
        }
        if let modelingUnit = modelConfig.modeling_unit {
            free(UnsafeMutableRawPointer(mutating: modelingUnit))
        }
        if let decodingMethod = config.decoding_method {
            free(UnsafeMutableRawPointer(mutating: decodingMethod))
        }
    }
    
    private func cleanupRecognizer() {
        addLog("🧹 清理识别器资源...")
        
        if let stream = stream {
            SherpaOnnxDestroyOnlineStream(stream)
            self.stream = nil
            addLog("✅ 音频流已销毁")
        }
        
        if let recognizer = recognizer {
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
            self.recognizer = nil
            addLog("✅ 识别器已销毁")
        }
        
        addLog("✅ 识别器资源清理完成")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing else { return }
        
        // Process audio data in background queue
        audioQueue.async { [weak self] in
            self?.processAudioData(buffer)
        }
    }
    
    private func processAudioData(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData,
              let recognizer = recognizer,
              let stream = stream else {
            addLog("❌ 无法获取音频数据或识别器未初始化")
            return
        }
        
        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]
        
        // Send audio data to sherpa-onnx
        SherpaOnnxOnlineStreamAcceptWaveform(stream, Int32(sampleRate), samples, Int32(frameLength))
        
        // Check if recognizer is ready to decode
        if SherpaOnnxIsOnlineStreamReady(recognizer, stream) == 1 {
            // Decode the audio
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
            
            // Get partial results
            let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream)
            if let result = result {
                let textPtr = result.pointee.text
                let resultText = textPtr != nil ? String(cString: textPtr!) : ""
                
                if !resultText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = resultText
                        self.addLog("📝 部分识别结果: \(resultText)")
                    }
                }
                
                SherpaOnnxDestroyOnlineRecognizerResult(result)
            }
        }
        
        // Check for endpoint detection
        if SherpaOnnxOnlineStreamIsEndpoint(recognizer, stream) == 1 {
            addLog("🔚 检测到语音端点")
            
            // Get final result
            let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream)
            if let result = result {
                let textPtr = result.pointee.text
                let finalText = textPtr != nil ? String(cString: textPtr!) : ""
                
                if !finalText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = finalText
                        self.addLog("✅ 最终识别结果: \(finalText)")
                    }
                }
                
                SherpaOnnxDestroyOnlineRecognizerResult(result)
            }
            
            // Reset the stream for next utterance
            SherpaOnnxOnlineStreamReset(recognizer, stream)
        }
        
        // Log audio processing (less frequently)
        if frameLength > 0 {
            Self.logCounter += 1
            if Self.logCounter % 100 == 0 { // Log every 100 buffers
                let timestamp = DateFormatter.timeFormatter.string(from: Date())
                DispatchQueue.main.async {
                    self.addLog("🎵 [\(timestamp)] 已处理 \(Self.logCounter) 个音频缓冲区")
                }
            }
        }
    }
    
    private func getFinalResult() -> String? {
        guard let recognizer = recognizer,
              let stream = stream else {
            return nil
        }
        
        let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream)
        if let result = result {
            let textPtr = result.pointee.text
            let finalText = textPtr != nil ? String(cString: textPtr!) : ""
            SherpaOnnxDestroyOnlineRecognizerResult(result)
            return finalText.isEmpty ? nil : finalText
        }
        
        return nil
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}