import Foundation
import Combine
import AVFoundation

// 注释：Swift中不需要单独import自定义文件，只要在同一个target中即可访问

// MARK: - Configuration Data Models

/// 音频配置
struct AudioConfiguration: Codable {
    var sampleRate: Double = 16000
    var channels: Int = 1
    var bufferSize: UInt32 = 1024
    var enableNoiseReduction: Bool = false
    var enableAudioEnhancement: Bool = false
    
    func isValid() -> Bool {
        return sampleRate > 0 && channels > 0 && bufferSize > 0
    }
}

/// 语音识别配置
struct RecognitionConfiguration: Codable {
    var modelPath: String = "models/paraformer-zh-streaming"
    var numThreads: Int = 2
    var provider: String = "cpu"
    var modelType: String = "paraformer"
    var modelingUnit: String = "char"
    var decodingMethod: String = "greedy_search"
    var maxActivePaths: Int = 4
    var enableEndpoint: Bool = true
    var rule1MinTrailingSilence: Float = 2.4
    var rule2MinTrailingSilence: Float = 1.2
    var rule3MinUtteranceLength: Float = 20.0
    var hotwordsScore: Float = 1.5
    var debug: Bool = false
    var modelName: String = "paraformer-zh-streaming"
    var language: String = "zh"
    var enablePunctuation: Bool = true
    var enableNumberConversion: Bool = true
    
    func isValid() -> Bool {
        return numThreads > 0 && 
               maxActivePaths > 0 && 
               rule1MinTrailingSilence > 0 && 
               rule2MinTrailingSilence > 0 && 
               rule3MinUtteranceLength > 0
    }
}

/// 键盘快捷键配置
struct KeyboardConfiguration: Codable {
    var primaryKeyCode: UInt16 = 31  // O 键
    var requiredClicks: Int = 3
    var clickInterval: Double = 0.8  // 800ms
    var debounceInterval: Double = 0.1  // 100ms
    var enabled: Bool = true
    
    func isValid() -> Bool {
        return requiredClicks > 0 && 
               clickInterval > 0 && 
               debounceInterval > 0
    }
}

/// 文本处理配置
struct TextProcessingConfiguration: Codable {
    var enableHotwordReplacement: Bool = true
    var enablePunctuation: Bool = true
    var autoCapitalization: Bool = false
    var trimWhitespace: Bool = true
    var minTextLength: Int = 1
    var maxTextLength: Int = 1000
    
    // 热词文件路径配置
    var hotWordChinesePath: String = "hot-zh.txt"
    var hotWordEnglishPath: String = "hot-en.txt"  
    var hotWordRulePath: String = "hot-rule.txt"
    var enableHotWordFileWatching: Bool = true
    var hotWordProcessingTimeout: Double = 5.0  // 热词处理超时时间（秒）
    
    // 标点符号处理配置
    var punctuationIntensity: String = "medium"  // light, medium, heavy
    var enableSmartPunctuation: Bool = true      // 智能标点符号处理
    var punctuationProcessingTimeout: Double = 2.0  // 标点处理超时时间（秒）
    var autoAddPeriod: Bool = true               // 自动添加句号
    var autoAddComma: Bool = true                // 自动添加逗号
    var autoAddQuestionMark: Bool = true         // 自动添加问号
    var autoAddExclamationMark: Bool = true      // 自动添加感叹号
    var skipExistingPunctuation: Bool = true     // 跳过已有标点的文本
    
    func isValid() -> Bool {
        let validIntensities = ["light", "medium", "heavy"]
        return minTextLength >= 0 && 
               maxTextLength > minTextLength &&
               hotWordProcessingTimeout > 0 &&
               punctuationProcessingTimeout > 0 &&
               validIntensities.contains(punctuationIntensity)
    }
}

/// UI 偏好配置
struct UIConfiguration: Codable {
    var showStatusBarIcon: Bool = true
    var showMainWindow: Bool = false
    var enableLogging: Bool = true
    var logLevel: Int = 1  // 0: 无日志, 1: 基本, 2: 详细, 3: 调试
    var maxLogEntries: Int = 100
    var darkMode: Bool = false
    var enableSoundEffects: Bool = true
    var showRecordingIndicator: Bool = true
    
    func isValid() -> Bool {
        return logLevel >= 0 && 
               logLevel <= 3 && 
               maxLogEntries > 0
    }
}

/// 应用行为配置
struct AppBehaviorConfiguration: Codable {
    var autoStartKeyboardMonitor: Bool = false
    var autoStartASRService: Bool = true
    var backgroundMode: Bool = false
    var startupDelay: Double = 0.5
    var recognitionStartDelay: Double = 1.0
    var permissionCheckDelay: Double = 2.0
    var enableAutoLaunch: Bool = false
    
    func isValid() -> Bool {
        return startupDelay >= 0 && 
               recognitionStartDelay >= 0 && 
               permissionCheckDelay >= 0
    }
}

/// 调试配置
struct DebugConfiguration: Codable {
    var enableVerboseLogging: Bool = false
    var enablePerformanceMetrics: Bool = false
    var logLevel: String = "info"
    var maxLogEntries: Int = 1000
    
    func isValid() -> Bool {
        return maxLogEntries > 0 && !logLevel.isEmpty
    }
}

// MARK: - Configuration Manager Protocol

/// 配置管理服务协议
protocol ConfigurationManagerProtocol: AnyObject, ObservableObject {
    // MARK: - Properties
    var audio: AudioConfiguration { get }
    var keyboard: KeyboardConfiguration { get }
    var appBehavior: AppBehaviorConfiguration { get }
    var textProcessing: TextProcessingConfiguration { get }
    var ui: UIConfiguration { get }
    var debug: DebugConfiguration { get }
    
    // MARK: - Methods
    func save()
    func reset()
    func resetToDefaults()
    func exportConfiguration() -> Data?
    func importConfiguration(from data: Data) -> Bool
}

// MARK: - Configuration Manager

/// 统一配置管理器
/// 负责管理应用的所有配置项，支持持久化存储、运行时更新和验证
class ConfigurationManager: ObservableObject, ConfigurationManagerProtocol {
    
    // MARK: - Singleton
    static let shared = ConfigurationManager()
    
    // MARK: - Published Configuration Properties
    @Published var audio: AudioConfiguration
    @Published var recognition: RecognitionConfiguration
    @Published var keyboard: KeyboardConfiguration
    @Published var textProcessing: TextProcessingConfiguration
    @Published var ui: UIConfiguration
    @Published var appBehavior: AppBehaviorConfiguration
    @Published var debug: DebugConfiguration
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let configurationQueue = DispatchQueue(label: "com.capswriter.configuration", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private enum Keys {
        static let audio = "audio_configuration"
        static let recognition = "recognition_configuration"
        static let keyboard = "keyboard_configuration"
        static let textProcessing = "text_processing_configuration"
        static let ui = "ui_configuration"
        static let appBehavior = "app_behavior_configuration"
        static let debug = "debug_configuration"
        static let lastSaveTime = "configuration_last_save_time"
    }
    
    // MARK: - Initialization
    
    private init() {
        // 加载保存的配置或使用默认值
        self.audio = ConfigurationManager.loadConfiguration(
            key: Keys.audio, 
            defaultValue: AudioConfiguration()
        )
        self.recognition = ConfigurationManager.loadConfiguration(
            key: Keys.recognition, 
            defaultValue: RecognitionConfiguration()
        )
        self.keyboard = ConfigurationManager.loadConfiguration(
            key: Keys.keyboard, 
            defaultValue: KeyboardConfiguration()
        )
        self.textProcessing = ConfigurationManager.loadConfiguration(
            key: Keys.textProcessing, 
            defaultValue: TextProcessingConfiguration()
        )
        self.ui = ConfigurationManager.loadConfiguration(
            key: Keys.ui, 
            defaultValue: UIConfiguration()
        )
        self.appBehavior = ConfigurationManager.loadConfiguration(
            key: Keys.appBehavior, 
            defaultValue: AppBehaviorConfiguration()
        )
        self.debug = ConfigurationManager.loadConfiguration(
            key: Keys.debug, 
            defaultValue: DebugConfiguration()
        )
        
        // 设置自动保存监听器
        setupAutoSave()
        
        // 使用 print 而不是 LogInfo，因为 LoggingService 可能还没有初始化
        print("🔧 ConfigurationManager 初始化完成")
        print("📊 配置状态: 音频(\(audio.sampleRate)Hz, \(audio.channels)声道), 识别(\(recognition.modelType), \(recognition.numThreads)线程), 键盘(键码\(keyboard.primaryKeyCode), \(keyboard.requiredClicks)次)")
        print("📝 文本处理: 热词替换(\(textProcessing.enableHotwordReplacement)), UI设置: 状态栏(\(ui.showStatusBarIcon)), 日志级别(\(ui.logLevel))")
    }
    
    // MARK: - Auto Save Setup
    
    private func setupAutoSave() {
        // 监听配置变化并自动保存
        Publishers.CombineLatest4(
            $audio.dropFirst(),
            $recognition.dropFirst(),
            $keyboard.dropFirst(),
            Publishers.CombineLatest3(
                $textProcessing.dropFirst(),
                $ui.dropFirst(),
                $appBehavior.dropFirst()
            )
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)  // 防抖，避免频繁保存
        .sink { [weak self] _ in
            self?.saveAllConfigurations()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Load Configuration
    
    private static func loadConfiguration<T: Codable>(key: String, defaultValue: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            print("📂 配置项 \(key) 不存在，使用默认值")
            return defaultValue
        }
        
        do {
            let configuration = try JSONDecoder().decode(T.self, from: data)
            print("✅ 成功加载配置项: \(key)")
            return configuration
        } catch {
            print("❌ 配置项 \(key) 解析失败: \(error)")
            print("🔄 使用默认值替代")
            return defaultValue
        }
    }
    
    // MARK: - Save Configuration
    
    private func saveConfiguration<T: Codable>(_ configuration: T, key: String) {
        configurationQueue.async {
            do {
                let data = try JSONEncoder().encode(configuration)
                DispatchQueue.main.async {
                    self.userDefaults.set(data, forKey: key)
                    print("💾 配置项 \(key) 已保存")
                }
            } catch {
                print("❌ 配置项 \(key) 保存失败: \(error)")
            }
        }
    }
    
    private func saveAllConfigurations() {
        print("💾 保存所有配置...")
        
        // 验证配置有效性
        guard validateAllConfigurations() else {
            print("❌ 配置验证失败，跳过保存")
            return
        }
        
        configurationQueue.async {
            // 并行保存所有配置
            let group = DispatchGroup()
            
            group.enter()
            self.saveConfiguration(self.audio, key: Keys.audio)
            group.leave()
            
            group.enter()
            self.saveConfiguration(self.recognition, key: Keys.recognition)
            group.leave()
            
            group.enter()
            self.saveConfiguration(self.keyboard, key: Keys.keyboard)
            group.leave()
            
            group.enter()
            self.saveConfiguration(self.textProcessing, key: Keys.textProcessing)
            group.leave()
            
            group.enter()
            self.saveConfiguration(self.ui, key: Keys.ui)
            group.leave()
            
            group.enter()
            self.saveConfiguration(self.appBehavior, key: Keys.appBehavior)
            group.leave()
            
            group.notify(queue: DispatchQueue.main) {
                // 记录保存时间
                self.userDefaults.set(Date(), forKey: Keys.lastSaveTime)
                // 移除同步调用，改为异步操作
                DispatchQueue.global(qos: .background).async {
                    // UserDefaults 的内部机制会自动处理持久化
                    // 无需强制 synchronize，避免主线程阻塞
                }
                print("✅ 所有配置保存完成")
                
                // 发送配置更新通知
                NotificationCenter.default.post(
                    name: .configurationDidUpdate, 
                    object: self
                )
            }
        }
    }
    
    // MARK: - Validation
    
    private func validateAllConfigurations() -> Bool {
        let validations = [
            ("音频配置", audio.isValid()),
            ("识别配置", recognition.isValid()),
            ("键盘配置", keyboard.isValid()),
            ("文本配置", textProcessing.isValid()),
            ("UI配置", ui.isValid()),
            ("应用配置", appBehavior.isValid())
        ]
        
        let allValid = validations.allSatisfy { $0.1 }
        
        if !allValid {
            print("❌ 配置验证失败:")
            validations.filter { !$0.1 }.forEach { name, _ in
                print("  - \(name) 无效")
            }
        }
        
        return allValid
    }
    
    // MARK: - Reset to Defaults
    
    func resetToDefaults() {
        print("🔄 重置所有配置为默认值...")
        
        DispatchQueue.main.async {
            self.audio = AudioConfiguration()
            self.recognition = RecognitionConfiguration()
            self.keyboard = KeyboardConfiguration()
            self.textProcessing = TextProcessingConfiguration()
            self.ui = UIConfiguration()
            self.appBehavior = AppBehaviorConfiguration()
        }
        
        // 清除持久化存储
        configurationQueue.async {
            [Keys.audio, Keys.recognition, Keys.keyboard, 
             Keys.textProcessing, Keys.ui, Keys.appBehavior, Keys.lastSaveTime].forEach { key in
                self.userDefaults.removeObject(forKey: key)
            }
            // 移除同步调用，UserDefaults 会自动处理持久化
            
            DispatchQueue.main.async {
                print("✅ 配置重置完成")
                NotificationCenter.default.post(
                    name: .configurationDidReset, 
                    object: self
                )
            }
        }
    }
    
    // MARK: - Import/Export
    
    func exportConfiguration() -> Data? {
        let exportData = ConfigurationExport(
            audio: audio,
            recognition: recognition,
            keyboard: keyboard,
            textProcessing: textProcessing,
            ui: ui,
            appBehavior: appBehavior,
            exportDate: Date(),
            version: "1.0"
        )
        
        do {
            let data = try JSONEncoder().encode(exportData)
            print("📤 配置导出成功，大小: \(data.count) bytes")
            return data
        } catch {
            print("❌ 配置导出失败: \(error)")
            return nil
        }
    }
    
    func importConfiguration(from data: Data) -> Bool {
        do {
            let importData = try JSONDecoder().decode(ConfigurationExport.self, from: data)
            
            print("📥 导入配置 (版本: \(importData.version), 日期: \(importData.exportDate))")
            
            // 验证导入的配置
            let tempConfigs = [
                importData.audio.isValid(),
                importData.recognition.isValid(),
                importData.keyboard.isValid(),
                importData.textProcessing.isValid(),
                importData.ui.isValid(),
                importData.appBehavior.isValid()
            ]
            
            guard tempConfigs.allSatisfy({ $0 }) else {
                print("❌ 导入的配置验证失败")
                return false
            }
            
            // 应用配置
            DispatchQueue.main.async {
                self.audio = importData.audio
                self.recognition = importData.recognition
                self.keyboard = importData.keyboard
                self.textProcessing = importData.textProcessing
                self.ui = importData.ui
                self.appBehavior = importData.appBehavior
            }
            
            print("✅ 配置导入成功")
            return true
            
        } catch {
            print("❌ 配置导入失败: \(error)")
            return false
        }
    }
    
    // MARK: - Convenience Methods
    
    /// 获取当前模型的完整路径
    func getModelPaths() -> (encoder: String, decoder: String, tokens: String) {
        let bundle = Bundle.main
        let modelPath = bundle.path(forResource: recognition.modelPath, ofType: nil) ?? recognition.modelPath
        
        return (
            encoder: "\(modelPath)/encoder.onnx",
            decoder: "\(modelPath)/decoder.onnx", 
            tokens: "\(modelPath)/tokens.txt"
        )
    }
    
    /// 检查模型文件是否存在
    func validateModelFiles() -> Bool {
        let paths = getModelPaths()
        let fileManager = FileManager.default
        
        let exists = [
            fileManager.fileExists(atPath: paths.encoder),
            fileManager.fileExists(atPath: paths.decoder),
            fileManager.fileExists(atPath: paths.tokens)
        ]
        
        return exists.allSatisfy { $0 }
    }
    
    /// 获取最后保存时间
    func getLastSaveTime() -> Date? {
        return userDefaults.object(forKey: Keys.lastSaveTime) as? Date
    }
    
    /// 强制同步保存
    func forceSave() {
        saveAllConfigurations()
    }
    
    // MARK: - ConfigurationManagerProtocol Implementation
    
    /// 保存配置（协议要求）
    func save() {
        forceSave()
    }
    
    /// 重置配置（协议要求）
    func reset() {
        resetToDefaults()
    }
}

// MARK: - Export/Import Data Model

private struct ConfigurationExport: Codable {
    let audio: AudioConfiguration
    let recognition: RecognitionConfiguration
    let keyboard: KeyboardConfiguration
    let textProcessing: TextProcessingConfiguration
    let ui: UIConfiguration
    let appBehavior: AppBehaviorConfiguration
    let exportDate: Date
    let version: String
}

// MARK: - Notification Names

extension Notification.Name {
    static let configurationDidUpdate = Notification.Name("configurationDidUpdate")
    static let configurationDidReset = Notification.Name("configurationDidReset")
}