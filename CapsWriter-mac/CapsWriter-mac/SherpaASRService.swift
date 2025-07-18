import Foundation
import AVFoundation
import Combine

// MARK: - Transcript Data Models

struct TranscriptEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let isPartial: Bool
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Sherpa-ONNX C API Helper Functions

/// 🔒 安全修复：Convert a String from swift to a `const char*` so that we can pass it to
/// the C language. 增强空指针检查和输入验证
func toCPointer(_ s: String) -> UnsafePointer<Int8>? {
  // 🔒 输入验证：检查字符串有效性
  guard !s.isEmpty else {
    print("⚠️ toCPointer: 空字符串输入")
    return nil
  }
  
  // 🔒 长度限制：防止过长字符串导致内存问题
  let maxLength = 10000
  guard s.count <= maxLength else {
    print("⚠️ toCPointer: 字符串过长 (\(s.count) 字符)")
    return nil
  }
  
  // 🔒 安全转换：确保UTF-8转换成功
  guard let cs = (s as NSString).utf8String else {
    print("⚠️ toCPointer: UTF-8转换失败")
    return nil
  }
  
  return UnsafePointer<Int8>(cs)
}

/// 🔒 安全修复：Return an instance of SherpaOnnxOnlineParaformerModelConfig.
/// 增强参数验证和空指针处理
func sherpaOnnxOnlineParaformerModelConfig(
  encoder: String = "",
  decoder: String = ""
) -> SherpaOnnxOnlineParaformerModelConfig {
  // 🔒 参数验证：对于空参数使用默认值
  let safeEncoder = encoder.isEmpty ? "" : encoder
  let safeDecoder = decoder.isEmpty ? "" : decoder
  
  // 🔒 安全转换：使用安全的指针转换
  let encoderPtr = toCPointer(safeEncoder) ?? toCPointer("")
  let decoderPtr = toCPointer(safeDecoder) ?? toCPointer("")
  
  return SherpaOnnxOnlineParaformerModelConfig(
    encoder: encoderPtr,
    decoder: decoderPtr
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
    func speechRecognitionDidFailWithError(_ error: Error)
}

/// 语音识别服务协议
protocol SpeechRecognitionServiceProtocol: AnyObject {
    // MARK: - Properties
    var isServiceRunning: Bool { get }
    var isInitialized: Bool { get }
    var partialTranscript: String { get set }
    var delegate: SpeechRecognitionDelegate? { get set }
    
    // MARK: - Methods
    func startService()
    func stopService()
    func startRecognition()
    func stopRecognition()
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func addTranscriptEntry(text: String, isPartial: Bool)
}

// MARK: - Pure ASR Service Class

class SherpaASRService: ObservableObject, SpeechRecognitionServiceProtocol {
    // MARK: - Published Properties
    @Published var logs: [String] = []
    @Published var transcript: String = ""
    @Published var isServiceRunning: Bool = false
    @Published var isRecognizing: Bool = false
    @Published var isInitialized: Bool = false
    @Published var transcriptHistory: [TranscriptEntry] = []
    @Published var partialTranscript: String = ""
    
    // MARK: - Private Properties
    private var recognizer: OpaquePointer?
    private var stream: OpaquePointer?
    private let processingQueue = DispatchQueue(label: "com.capswriter.speech-recognition", qos: .userInitiated)
    private let cleanupQueue = DispatchQueue(label: "com.capswriter.sherpa-cleanup", qos: .utility)
    private static var logCounter = 0
    
    // Mock mode flag - 设置为 false 来启用真实模型
    private let isMockMode = false
    
    // Configuration manager
    private let configManager = ConfigurationManager.shared
    
    // Audio configuration (now from config manager)
    private var sampleRate: Double {
        return configManager.audio.sampleRate
    }
    
    // Model configuration (now from config manager)
    private var modelPath: String {
        let bundle = Bundle.main
        return bundle.path(forResource: configManager.recognition.modelPath, ofType: nil) ?? configManager.recognition.modelPath
    }
    
    private var tokensPath: String {
        return "\(modelPath)/tokens.txt"
    }
    
    private var encoderPath: String {
        return "\(modelPath)/encoder.onnx"
    }
    
    private var decoderPath: String {
        return "\(modelPath)/decoder.onnx"
    }
    
    // Delegate
    weak var delegate: SpeechRecognitionDelegate?
    
    // MARK: - Initialization
    init() {
        addLog("🧠 SherpaASRService 初始化（纯识别服务）")
        addLog("📁 模型路径: \(modelPath)")
        addLog("⚙️ 配置信息:")
        addLog("  - 采样率: \(sampleRate)Hz")
        addLog("  - 识别线程: \(configManager.recognition.numThreads)")
        addLog("  - 解码方法: \(configManager.recognition.decodingMethod)")
    }
    
    deinit {
        print("🛑 SherpaASRService deinit 开始")
        // 使用专用队列进行清理，避免主线程阻塞
        cleanupQueue.sync {
            self.cleanupRecognizer()
        }
        print("🛑 SherpaASRService deinit 完成")
    }
    
    // MARK: - Public Methods
    
    func startService() {
        addLog("🔄 正在启动语音识别服务...")
        
        guard !isServiceRunning else {
            addLog("⚠️ 服务已在运行中")
            return
        }
        
        // 异步初始化识别器，避免阻塞调用线程
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            RecordingState.shared.updateInitializationProgress("正在初始化识别器...")
            self.initializeRecognizer()
            
            DispatchQueue.main.async {
                // 只有初始化成功后才标记服务为运行状态
                if self.isInitialized {
                    self.isServiceRunning = true
                    RecordingState.shared.updateInitializationProgress("识别器已就绪")
                    self.addLog("✅ 语音识别服务已启动")
                } else {
                    self.isServiceRunning = false
                    RecordingState.shared.updateInitializationProgress("识别器初始化失败")
                    self.addLog("❌ 语音识别服务启动失败")
                }
            }
        }
    }
    
    func stopService() {
        addLog("🛑 正在停止语音识别服务...")
        
        // 使用专用队列进行清理，避免阻塞调用线程
        cleanupQueue.async { [weak self] in
            self?.cleanupRecognizer()
        }
        
        isServiceRunning = false
        isRecognizing = false
        isInitialized = false
        addLog("✅ 语音识别服务已停止")
    }
    
    func startRecognition() {
        guard isServiceRunning else {
            addLog("❌ 服务未启动，无法开始识别")
            return
        }
        
        guard isInitialized else {
            addLog("⏳ 识别器正在初始化中，请稍后再试...")
            // 延迟重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startRecognition()
            }
            return
        }
        
        guard !isRecognizing else {
            addLog("⚠️ 识别已在进行中")
            return
        }
        
        addLog("🧠 开始语音识别处理...")
        
        // 确保识别器已初始化
        guard recognizer != nil && stream != nil else {
            addLog("❌ 识别器未初始化，无法开始识别")
            return
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
    
    // MARK: - Transcript Management
    
    func addTranscriptEntry(text: String, isPartial: Bool) {
        guard !text.isEmpty else { return }
        
        let entry = TranscriptEntry(
            timestamp: Date(),
            text: text,
            isPartial: isPartial
        )
        
        // 在主线程更新UI
        DispatchQueue.main.async {
            self.transcriptHistory.append(entry)
            
            // 保持历史记录不超过100条
            if self.transcriptHistory.count > 100 {
                self.transcriptHistory.removeFirst(self.transcriptHistory.count - 100)
            }
        }
        
        addLog("📝 添加转录条目: \(text)")
    }
    
    func clearTranscriptHistory() {
        DispatchQueue.main.async {
            self.transcriptHistory.removeAll()
            self.partialTranscript = ""
        }
        addLog("🗑️ 转录历史已清空")
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
        RecordingState.shared.updateInitializationProgress("正在检查模型文件...")
        
        // 重置初始化状态
        isInitialized = false
        
        // 检查模型文件是否存在
        addLog("📂 检查模型文件...")
        addLog("  - 模型路径: \(modelPath)")
        addLog("  - 编码器: \(encoderPath)")
        addLog("  - 解码器: \(decoderPath)")
        addLog("  - 词汇表: \(tokensPath)")
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            addLog("❌ 模型目录不存在: \(modelPath)")
            addLog("⚠️ 识别器初始化失败，无法处理音频")
            RecordingState.shared.updateInitializationProgress("模型文件缺失")
            return
        }
        
        if isMockMode {
            // 模拟模式：不创建真实的Sherpa对象，保持nil状态
            addLog("🔧 模拟模式：不创建真实识别器")
            addLog("✅ 模拟识别器初始化完成（音频流测试模式）")
            isInitialized = true
        } else {
            // 真实模式：创建Sherpa识别器
            addLog("🔧 真实模式：创建Sherpa识别器...")
            RecordingState.shared.updateInitializationProgress("正在验证模型文件...")
            
            // 检查模型文件是否存在
            addLog("📂 检查模型文件...")
            addLog("  - 编码器: \(encoderPath)")
            addLog("  - 解码器: \(decoderPath)")
            addLog("  - 词汇表: \(tokensPath)")
            
            guard FileManager.default.fileExists(atPath: encoderPath),
                  FileManager.default.fileExists(atPath: decoderPath),
                  FileManager.default.fileExists(atPath: tokensPath) else {
                addLog("❌ 模型文件不完整")
                RecordingState.shared.updateInitializationProgress("模型文件不完整")
                return
            }
            
            // Use helper functions to create configuration
            let paraformerConfig = sherpaOnnxOnlineParaformerModelConfig(
                encoder: encoderPath,
                decoder: decoderPath
            )
            
            let modelConfig = sherpaOnnxOnlineModelConfig(
                tokens: tokensPath,
                paraformer: paraformerConfig,
                numThreads: configManager.recognition.numThreads,
                provider: configManager.recognition.provider,
                debug: configManager.recognition.debug,
                modelType: configManager.recognition.modelType,
                modelingUnit: configManager.recognition.modelingUnit
            )
            
            let featConfig = sherpaOnnxFeatureConfig(
                sampleRate: Int(sampleRate),
                featureDim: 80
            )
            
            var config = sherpaOnnxOnlineRecognizerConfig(
                featConfig: featConfig,
                modelConfig: modelConfig,
                decodingMethod: configManager.recognition.decodingMethod,
                maxActivePaths: configManager.recognition.maxActivePaths,
                enableEndpoint: configManager.recognition.enableEndpoint,
                rule1MinTrailingSilence: configManager.recognition.rule1MinTrailingSilence,
                rule2MinTrailingSilence: configManager.recognition.rule2MinTrailingSilence,
                rule3MinUtteranceLength: configManager.recognition.rule3MinUtteranceLength
            )
            
            addLog("⚙️ 创建识别器实例...")
            RecordingState.shared.updateInitializationProgress("正在创建识别器...")
            // 🔒 安全修复：安全创建识别器，增强错误处理
            recognizer = SherpaOnnxCreateOnlineRecognizer(&config)
            
            // 🔒 空指针检查：确保识别器创建成功
            guard let validRecognizer = recognizer else {
                addLog("❌ 识别器创建失败：返回空指针")
                RecordingState.shared.updateInitializationProgress("识别器创建失败")
                isInitialized = false
                return
            }
            
            addLog("✅ 识别器创建成功")
            
            // 🔒 安全创建音频流
            addLog("🌊 创建音频流...")
            RecordingState.shared.updateInitializationProgress("正在创建音频流...")
            
            stream = SherpaOnnxCreateOnlineStream(validRecognizer)
            
            // 🔒 空指针检查：确保音频流创建成功
            guard stream != nil else {
                addLog("❌ 音频流创建失败：返回空指针")
                RecordingState.shared.updateInitializationProgress("音频流创建失败")
                
                // 🔒 资源清理：清理已创建的识别器
                SherpaOnnxDestroyOnlineRecognizer(validRecognizer)
                recognizer = nil
                isInitialized = false
                return
            }
            
            addLog("✅ 音频流创建成功")
            RecordingState.shared.updateInitializationProgress("初始化完成")
            isInitialized = true
        }
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
                        // 添加到转录历史
                        self.addTranscriptEntry(text: mockResult, isPartial: false)
                        self.delegate?.speechRecognitionDidReceivePartialResult(mockResult)
                    }
                }
            }
            return
        }
        
        // 🔒 安全修复：检查识别器是否初始化
        guard let recognizer = recognizer,
              let stream = stream else {
            // 只记录一次警告，避免日志过多
            if Self.logCounter % 1000 == 0 {
                addLog("⚠️ 识别器未初始化，跳过音频处理")
            }
            Self.logCounter += 1
            return
        }
        
        // 🔒 安全验证：检查音频数据有效性
        guard frameLength > 0 else {
            addLog("⚠️ 音频帧长度无效: \(frameLength)")
            return
        }
        
        let maxFrameLength = 1024 * 1024  // 1M samples 限制
        guard frameLength <= maxFrameLength else {
            addLog("⚠️ 音频帧长度过大: \(frameLength)")
            return
        }
        
        // 🔒 安全获取音频样本
        let samples = channelData[0]
        
        // 🔒 安全调用：Send audio data to sherpa-onnx
        // samples 是非可选的指针，直接使用
        SherpaOnnxOnlineStreamAcceptWaveform(stream, Int32(sampleRate), samples, Int32(frameLength))
        
        // 🔒 安全检查：检查识别器是否准备好解码
        let isReady = SherpaOnnxIsOnlineStreamReady(recognizer, stream)
        if isReady == 1 {
            // 🔒 安全解码：Decode the audio
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
            
            // 🔒 安全获取结果：检查结果指针有效性
            if let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) {
                // 🔒 安全文本提取：使用安全方法提取文本
                let resultText = getTextFromResultSafely(result)
                
                if !resultText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = resultText
                        self.addLog("📝 部分识别结果: \(resultText)")
                        self.delegate?.speechRecognitionDidReceivePartialResult(resultText)
                    }
                }
                
                // 🔒 资源清理：确保结果被正确释放
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
    
    // 🔒 安全修复：安全地从 C 结构体中读取文本
    private func getTextFromResult(_ result: UnsafePointer<SherpaOnnxOnlineRecognizerResult>) -> String {
        return getTextFromResultSafely(result)
    }
    
    // 🔒 安全方法：增强版本的文本提取
    private func getTextFromResultSafely(_ result: UnsafePointer<SherpaOnnxOnlineRecognizerResult>) -> String {
        // 🔒 空指针检查：确保result指针有效
        // result 是非可选的指针参数，不需要检查是否为 nil
        
        // 🔒 结构体访问：安全访问结构体成员
        let textPointer = result.pointee.text
        
        // 🔒 文本指针检查：确保text指针有效
        guard let validTextPointer = textPointer else {
            print("⚠️ getTextFromResultSafely: text指针无效")
            return ""
        }
        
        // 🔒 长度检查：防止过长的文本导致内存问题
        let maxTextLength = 10000
        let textLength = strlen(validTextPointer)
        
        guard textLength <= maxTextLength else {
            print("⚠️ getTextFromResultSafely: 文本过长 (\(textLength) 字符)")
            // 返回截断的文本
            let truncatedData = Data(bytes: validTextPointer, count: min(Int(textLength), maxTextLength))
            return String(data: truncatedData, encoding: .utf8) ?? ""
        }
        
        // 🔒 安全转换：使用安全的字符串创建方法
        let resultString = String(cString: validTextPointer)
        
        // 🔒 内容验证：检查文本内容合理性
        guard !resultString.isEmpty else {
            return ""
        }
        
        // 🔒 字符验证：移除潜在的控制字符
        let cleanedString = resultString.filter { $0.isASCII || $0.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces).contains) }
        
        return cleanedString
    }
    
    private func getFinalResult() -> String? {
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