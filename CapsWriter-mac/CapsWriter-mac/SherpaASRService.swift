import Foundation
import AVFoundation
import Combine

// MARK: - Sherpa-ONNX C API Helper Functions

/// Convert a String from swift to a `const char*` so that we can pass it to
/// the C language.
func toCPointer(_ s: String) -> UnsafePointer<Int8>! {
  let cs = (s as NSString).utf8String
  return UnsafePointer<Int8>(cs)
}

/// Return an instance of SherpaOnnxOnlineParaformerModelConfig.
func sherpaOnnxOnlineParaformerModelConfig(
  encoder: String = "",
  decoder: String = ""
) -> SherpaOnnxOnlineParaformerModelConfig {
  return SherpaOnnxOnlineParaformerModelConfig(
    encoder: toCPointer(encoder),
    decoder: toCPointer(decoder)
  )
}

/// Return an instance of SherpaOnnxOnlineTransducerModelConfig.
func sherpaOnnxOnlineTransducerModelConfig(
  encoder: String = "",
  decoder: String = "",
  joiner: String = ""
) -> SherpaOnnxOnlineTransducerModelConfig {
  return SherpaOnnxOnlineTransducerModelConfig(
    encoder: toCPointer(encoder),
    decoder: toCPointer(decoder),
    joiner: toCPointer(joiner)
  )
}

/// Return an instance of SherpaOnnxOnlineZipformer2CtcModelConfig.
func sherpaOnnxOnlineZipformer2CtcModelConfig(
  model: String = ""
) -> SherpaOnnxOnlineZipformer2CtcModelConfig {
  return SherpaOnnxOnlineZipformer2CtcModelConfig(
    model: toCPointer(model)
  )
}

/// Return an instance of SherpaOnnxOnlineModelConfig.
func sherpaOnnxOnlineModelConfig(
  tokens: String = "",
  transducer: SherpaOnnxOnlineTransducerModelConfig = sherpaOnnxOnlineTransducerModelConfig(),
  paraformer: SherpaOnnxOnlineParaformerModelConfig = sherpaOnnxOnlineParaformerModelConfig(),
  zipformer2Ctc: SherpaOnnxOnlineZipformer2CtcModelConfig = sherpaOnnxOnlineZipformer2CtcModelConfig(),
  numThreads: Int = 1,
  provider: String = "cpu",
  debug: Bool = false,
  modelType: String = "",
  modelingUnit: String = "",
  bpeVocab: String = ""
) -> SherpaOnnxOnlineModelConfig {
  return SherpaOnnxOnlineModelConfig(
    transducer: transducer,
    paraformer: paraformer,
    zipformer2_ctc: zipformer2Ctc,
    tokens: toCPointer(tokens),
    num_threads: Int32(numThreads),
    provider: toCPointer(provider),
    debug: debug ? 1 : 0,
    model_type: toCPointer(modelType),
    modeling_unit: toCPointer(modelingUnit),
    bpe_vocab: toCPointer(bpeVocab),
    tokens_buf: nil,
    tokens_buf_size: 0
  )
}

/// Return an instance of SherpaOnnxFeatureConfig.
func sherpaOnnxFeatureConfig(
  sampleRate: Int = 16000,
  featureDim: Int = 80
) -> SherpaOnnxFeatureConfig {
  return SherpaOnnxFeatureConfig(
    sample_rate: Int32(sampleRate),
    feature_dim: Int32(featureDim)
  )
}

/// Return an instance of SherpaOnnxOnlineRecognizerConfig.
func sherpaOnnxOnlineRecognizerConfig(
  featConfig: SherpaOnnxFeatureConfig = sherpaOnnxFeatureConfig(),
  modelConfig: SherpaOnnxOnlineModelConfig = sherpaOnnxOnlineModelConfig(),
  decodingMethod: String = "greedy_search",
  maxActivePaths: Int = 4,
  enableEndpoint: Bool = false,
  rule1MinTrailingSilence: Float = 2.4,
  rule2MinTrailingSilence: Float = 1.2,
  rule3MinUtteranceLength: Float = 20.0,
  hotwordsFile: String = "",
  hotwordsScore: Float = 1.5
) -> SherpaOnnxOnlineRecognizerConfig {
  return SherpaOnnxOnlineRecognizerConfig(
    feat_config: featConfig,
    model_config: modelConfig,
    decoding_method: toCPointer(decodingMethod),
    max_active_paths: Int32(maxActivePaths),
    enable_endpoint: enableEndpoint ? 1 : 0,
    rule1_min_trailing_silence: rule1MinTrailingSilence,
    rule2_min_trailing_silence: rule2MinTrailingSilence,
    rule3_min_utterance_length: rule3MinUtteranceLength,
    hotwords_file: toCPointer(hotwordsFile),
    hotwords_score: hotwordsScore,
    ctc_fst_decoder_config: SherpaOnnxOnlineCtcFstDecoderConfig(),
    rule_fsts: nil,
    rule_fars: nil,
    blank_penalty: 0.0,
    hotwords_buf: nil,
    hotwords_buf_size: 0,
    hr: SherpaOnnxHomophoneReplacerConfig()
  )
}

// MARK: - ASR Service Class

class SherpaASRService: ObservableObject {
    // MARK: - Published Properties
    @Published var logs: [String] = []
    @Published var transcript: String = ""
    @Published var isServiceRunning: Bool = false
    @Published var isRecognizing: Bool = false
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var recognizer: OpaquePointer?
    private var stream: OpaquePointer?
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
        
        // 只初始化 sherpa-onnx 识别器，不启动音频引擎
        // 音频引擎会在用户开始录音时启动
        initializeRecognizer()
        
        isServiceRunning = true
        addLog("✅ 语音识别服务启动成功（音频引擎将在需要时启动）")
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
        
        // 现在才初始化和启动音频引擎
        if audioEngine == nil {
            setupAudioEngine()
        }
        
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
        
        // Use helper functions to create configuration
        let paraformerConfig = sherpaOnnxOnlineParaformerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath
        )
        
        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: tokensPath,
            paraformer: paraformerConfig,
            numThreads: 2,
            provider: "cpu",
            debug: false,
            modelType: "paraformer",
            modelingUnit: "char"
        )
        
        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: Int(sampleRate),
            featureDim: 80
        )
        
        var config = sherpaOnnxOnlineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search",
            maxActivePaths: 4,
            enableEndpoint: true,
            rule1MinTrailingSilence: 2.4,
            rule2MinTrailingSilence: 1.2,
            rule3MinUtteranceLength: 20.0
        )
        
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