import Foundation
import AVFoundation
import Combine

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
        
        // Initialize sherpa-onnx configuration
        var config = SherpaOnnxOnlineRecognizerConfig()
        
        // Configure paraformer model
        config.model_config.paraformer.encoder = strdup(encoderPath)
        config.model_config.paraformer.decoder = strdup(decoderPath)
        config.model_config.paraformer.tokens = strdup(tokensPath)
        config.model_config.paraformer.num_threads = 2
        config.model_config.paraformer.provider = strdup("cpu")
        config.model_config.paraformer.debug = 0
        config.model_config.paraformer.model_type = strdup("paraformer")
        
        // Configure feature extraction
        config.feat_config.scale = 1.0
        
        // Configure decoding
        config.decoding_method = strdup("greedy_search")
        config.max_active_paths = 4
        config.enable_endpoint = 1
        config.rule1_min_trailing_silence = 2.4
        config.rule2_min_trailing_silence = 1.2
        config.rule3_min_utterance_length = 20.0
        
        addLog("⚙️ 创建识别器实例...")
        recognizer = CreateOnlineRecognizer(&config)
        
        if recognizer != nil {
            addLog("✅ 识别器创建成功")
            
            // Create stream
            addLog("🌊 创建音频流...")
            stream = CreateOnlineStream(recognizer)
            
            if stream != nil {
                addLog("✅ 音频流创建成功")
            } else {
                addLog("❌ 音频流创建失败")
            }
        } else {
            addLog("❌ 识别器创建失败")
        }
        
        // Cleanup allocated strings
        free(UnsafeMutableRawPointer(mutating: config.model_config.paraformer.encoder))
        free(UnsafeMutableRawPointer(mutating: config.model_config.paraformer.decoder))
        free(UnsafeMutableRawPointer(mutating: config.model_config.paraformer.tokens))
        free(UnsafeMutableRawPointer(mutating: config.model_config.paraformer.provider))
        free(UnsafeMutableRawPointer(mutating: config.model_config.paraformer.model_type))
        free(UnsafeMutableRawPointer(mutating: config.decoding_method))
    }
    
    private func cleanupRecognizer() {
        addLog("🧹 清理识别器资源...")
        
        if let stream = stream {
            DestroyOnlineStream(stream)
            self.stream = nil
            addLog("✅ 音频流已销毁")
        }
        
        if let recognizer = recognizer {
            DestroyOnlineRecognizer(recognizer)
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
        AcceptWaveform(stream, Int32(sampleRate), samples, Int32(frameLength))
        
        // Check if recognizer is ready to decode
        if IsReady(recognizer, stream) == 1 {
            // Decode the audio
            Decode(recognizer, stream)
            
            // Get partial results
            let result = GetResult(recognizer, stream)
            if let result = result {
                let resultText = String(cString: GetResultText(result))
                
                if !resultText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = resultText
                        self.addLog("📝 部分识别结果: \(resultText)")
                    }
                }
                
                DestroyOnlineRecognizerResult(result)
            }
        }
        
        // Check for endpoint detection
        if IsEndpoint(recognizer, stream) == 1 {
            addLog("🔚 检测到语音端点")
            
            // Get final result
            let result = GetResult(recognizer, stream)
            if let result = result {
                let finalText = String(cString: GetResultText(result))
                
                if !finalText.isEmpty {
                    DispatchQueue.main.async {
                        self.transcript = finalText
                        self.addLog("✅ 最终识别结果: \(finalText)")
                    }
                }
                
                DestroyOnlineRecognizerResult(result)
            }
            
            // Reset the stream for next utterance
            Reset(recognizer, stream)
        }
        
        // Log audio processing (less frequently)
        if frameLength > 0 {
            static var logCounter = 0
            logCounter += 1
            if logCounter % 100 == 0 { // Log every 100 buffers
                let timestamp = DateFormatter.timeFormatter.string(from: Date())
                DispatchQueue.main.async {
                    self.addLog("🎵 [\(timestamp)] 已处理 \(logCounter) 个音频缓冲区")
                }
            }
        }
    }
    
    private func getFinalResult() -> String? {
        guard let recognizer = recognizer,
              let stream = stream else {
            return nil
        }
        
        let result = GetResult(recognizer, stream)
        if let result = result {
            let finalText = String(cString: GetResultText(result))
            DestroyOnlineRecognizerResult(result)
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