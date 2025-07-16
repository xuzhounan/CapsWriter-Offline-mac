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

// MARK: - Speech Recognition Delegate Protocol

protocol SpeechRecognitionDelegate: AnyObject {
    func speechRecognitionDidReceivePartialResult(_ text: String)
    func speechRecognitionDidReceiveFinalResult(_ text: String)
    func speechRecognitionDidDetectEndpoint()
}

// MARK: - Pure ASR Service Class

class SherpaASRService: ObservableObject {
    // MARK: - Published Properties
    @Published var logs: [String] = []
    @Published var transcript: String = ""
    @Published var isServiceRunning: Bool = false
    @Published var isRecognizing: Bool = false
    
    // MARK: - Private Properties
    private var recognizer: OpaquePointer?
    private var stream: OpaquePointer?
    private let processingQueue = DispatchQueue(label: "com.capswriter.speech-recognition", qos: .userInitiated)
    private static var logCounter = 0
    
    // Mock mode flag - 设置为 false 来启用真实模型
    private let isMockMode = true
    
    // Audio configuration
    private let sampleRate: Double = 16000
    
    // Model configuration
    private let modelPath: String
    private let tokensPath: String
    private let encoderPath: String
    private let decoderPath: String
    
    // Delegate
    weak var delegate: SpeechRecognitionDelegate?
    
    // MARK: - Initialization
    init() {
        // Initialize model paths
        let bundle = Bundle.main
        self.modelPath = bundle.path(forResource: "paraformer-zh-streaming", ofType: nil, inDirectory: "models") ?? ""
        self.tokensPath = "\(modelPath)/tokens.txt"
        self.encoderPath = "\(modelPath)/encoder.onnx"
        self.decoderPath = "\(modelPath)/decoder.onnx"
        
        addLog("🧠 SherpaASRService 初始化（纯识别服务）")
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
        
        // 先不初始化 recognizer，避免崩溃
        // initializeRecognizer()
        
        isServiceRunning = true
        addLog("✅ 语音识别服务已准备就绪（延迟初始化模式）")
    }
    
    func stopService() {
        addLog("🛑 正在停止语音识别服务...")
        
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
        
        addLog("🧠 开始语音识别处理...")
        
        // 推迟初始化到真正需要时
        if recognizer == nil {
            initializeRecognizer()
        }
        
        isRecognizing = true
        
        if isMockMode {
            addLog("🔄 模拟模式：跳过Sherpa识别器重置")
        } else {
            // 只有真实模式才检查并调用Sherpa C函数
            guard let recognizer = self.recognizer else {
                addLog("❌ recognizer 未初始化")
                isRecognizing = false
                return
            }
            guard let stream = self.stream else {
                addLog("❌ stream 未初始化") 
                isRecognizing = false
                return
            }
            
            // 重置音频流准备新的识别会话
            SherpaOnnxOnlineStreamReset(recognizer, stream)
            addLog("🔄 音频流已重置，准备新的识别会话")
        }
    }
    
    func stopRecognition() {
        guard isRecognizing else {
            addLog("⚠️ 识别未在进行中")
            return
        }
        
        addLog("⏹️ 停止语音识别处理...")
        isRecognizing = false
        
        // Get final result from sherpa-onnx
        if let finalResult = getFinalResult() {
            transcript = finalResult
            addLog("📝 最终识别结果: \(finalResult)")
            delegate?.speechRecognitionDidReceiveFinalResult(finalResult)
        }
        
        addLog("✅ 语音识别处理已停止")
    }
    
    // MARK: - Audio Processing Interface
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 添加接收音频缓冲区的调试日志（每100帧输出一次）
        Self.logCounter += 1
        if Self.logCounter % 100 == 0 {
            addLog("📥 ASR服务已接收 \(Self.logCounter) 个音频缓冲区，当前缓冲区大小: \(buffer.frameLength)")
        }
        
        guard isRecognizing else { 
            if Self.logCounter % 100 == 0 {
                addLog("⚠️ ASR服务未在识别状态，跳过音频处理")
            }
            return 
        }
        
        // Process audio data in background queue
        processingQueue.async { [weak self] in
            self?.processAudioDataSafely(buffer)
        }
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
    
    private func initializeRecognizer() {
        addLog("🧠 初始化 Sherpa-ONNX 识别器...")
        
        // 检查模型文件是否存在
        addLog("📂 检查模型文件...")
        addLog("  - 模型路径: \(modelPath)")
        addLog("  - 编码器: \(encoderPath)")
        addLog("  - 解码器: \(decoderPath)")
        addLog("  - 词汇表: \(tokensPath)")
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            addLog("❌ 模型目录不存在: \(modelPath)")
            addLog("⚠️ 识别器初始化失败，无法处理音频")
            return
        }
        
        if isMockMode {
            // 模拟模式：不创建真实的Sherpa对象，保持nil状态
            addLog("🔧 模拟模式：不创建真实识别器")
            addLog("✅ 模拟识别器初始化完成（音频流测试模式）")
        } else {
            // 真实模式：创建Sherpa识别器（目前已注释）
            addLog("🔧 真实模式：创建Sherpa识别器...")
            addLog("⚠️ 真实识别器代码暂时注释，需要修复结构体访问问题")
        }
        
        // 以下代码暂时注释，等修复结构体访问问题后再启用
        /*
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
        */
    }
    
    private func cleanupRecognizer() {
        addLog("🧹 清理识别器资源...")
        
        if isMockMode {
            // 模拟模式：直接清空引用，不调用C函数
            recognizer = nil
            stream = nil
            addLog("✅ 模拟识别器资源已清理")
        } else {
            // 真实模式：调用Sherpa C函数清理
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
        }
        
        addLog("✅ 识别器资源清理完成")
    }
    
    private func processAudioDataSafely(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            addLog("❌ 无法获取音频数据")
            return
        }
        
        let frameLength = Int(buffer.frameLength)
        
        if isMockMode {
            // 模拟模式：记录音频处理但不调用Sherpa C函数
            Self.logCounter += 1
            if Self.logCounter % 50 == 0 {
                let timestamp = DateFormatter.timeFormatter.string(from: Date())
                addLog("🎵 [\(timestamp)] 模拟处理音频: 第\(Self.logCounter)帧，大小: \(frameLength)")
                
                // 模拟识别结果
                if Self.logCounter % 200 == 0 {
                    let mockResult = "模拟识别结果 \(Self.logCounter/200)"
                    DispatchQueue.main.async {
                        self.transcript = mockResult
                        self.addLog("📝 模拟识别结果: \(mockResult)")
                        self.delegate?.speechRecognitionDidReceivePartialResult(mockResult)
                    }
                }
            }
            return
        }
        
        // 真实模式：检查识别器是否初始化
        guard let recognizer = recognizer,
              let stream = stream else {
            // 只记录一次警告，避免日志过多
            if Self.logCounter % 1000 == 0 {
                addLog("⚠️ 识别器未初始化，跳过音频处理")
            }
            Self.logCounter += 1
            return
        }
        
        let samples = channelData[0]
        
        // Send audio data to sherpa-onnx
        SherpaOnnxOnlineStreamAcceptWaveform(stream, Int32(sampleRate), samples, Int32(frameLength))
        
        // Check if recognizer is ready to decode
        if SherpaOnnxIsOnlineStreamReady(recognizer, stream) == 1 {
            // Decode the audio
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
            
            // Get partial results - 使用安全的方式访问结果
            if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
                let resultText = getTextFromResult(result)
                
                if !resultText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = resultText
                        self.addLog("📝 部分识别结果: \(resultText)")
                        self.delegate?.speechRecognitionDidReceivePartialResult(resultText)
                    }
                }
                
                SherpaOnnxDestroyOnlineRecognizerResult(result)
            }
        }
        
        // Check for endpoint detection
        if SherpaOnnxOnlineStreamIsEndpoint(recognizer, stream) == 1 {
            addLog("🔚 检测到语音端点")
            
            // Get final result
            if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
                let finalText = getTextFromResult(result)
                
                if !finalText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = finalText
                        self.addLog("✅ 最终识别结果: \(finalText)")
                        self.delegate?.speechRecognitionDidReceiveFinalResult(finalText)
                    }
                }
                
                SherpaOnnxDestroyOnlineRecognizerResult(result)
            }
            
            // Notify delegate about endpoint
            DispatchQueue.main.async {
                self.delegate?.speechRecognitionDidDetectEndpoint()
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
    
    private func getTextFromResult(_ result: UnsafePointer<SherpaOnnxOnlineRecognizerResult>) -> String {
        // 安全地从 C 结构体中读取文本
        let text = result.pointee.text
        return text != nil ? String(cString: text!) : ""
    }
    
    private func getFinalResult() -> String? {
        if isMockMode {
            // 模拟模式：返回模拟结果
            return "模拟最终识别结果"
        }
        
        guard let recognizer = recognizer,
              let stream = stream else {
            return nil
        }
        
        if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
            let finalText = getTextFromResult(result)
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