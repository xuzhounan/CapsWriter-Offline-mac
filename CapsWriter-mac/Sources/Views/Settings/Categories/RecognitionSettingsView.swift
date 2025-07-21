import SwiftUI

// MARK: - Recognition Settings View

/// 语音识别设置界面
struct RecognitionSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 模型设置
                ModelConfigurationSection(configManager: configManager)
                
                // 识别引擎设置
                RecognitionEngineSection(configManager: configManager)
                
                // 端点检测设置
                EndpointDetectionSection(configManager: configManager)
                
                // 语言和文本处理设置
                LanguageAndTextSection(configManager: configManager)
                
                // 性能设置
                PerformanceSection(configManager: configManager)
            }
            .padding()
        }
    }
}

// MARK: - Model Configuration Section

struct ModelConfigurationSection: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var modelValidationStatus: ModelValidationStatus = .unknown
    
    var body: some View {
        SettingsSection(
            title: "模型配置",
            description: "配置语音识别使用的 AI 模型和相关参数"
        ) {
            VStack(spacing: 16) {
                // 模型路径
                VStack(alignment: .leading, spacing: 8) {
                    Text("模型路径")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        TextField("模型目录路径", text: $configManager.recognition.modelPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11, family: .monospaced))
                        
                        Button("选择") {
                            selectModelPath()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("Sherpa-ONNX 模型文件所在的目录路径")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 模型类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("模型类型")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("模型类型", selection: $configManager.recognition.modelType) {
                        Text("Paraformer").tag("paraformer")
                        Text("Whisper").tag("whisper")
                        Text("Conformer").tag("conformer")
                        Text("Zipformer").tag("zipformer")
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("当前支持的模型类型，推荐使用 Paraformer 中文模型")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 建模单元
                VStack(alignment: .leading, spacing: 8) {
                    Text("建模单元")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("建模单元", selection: $configManager.recognition.modelingUnit) {
                        Text("字符 (char)").tag("char")
                        Text("词 (word)").tag("word")
                        Text("字节对 (bpe)").tag("bpe")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("模型的基本建模单元，中文模型通常使用字符单元")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 模型验证
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模型状态")
                            .font(.system(size: 14, weight: .medium))
                        
                        HStack {
                            Image(systemName: modelValidationStatus.icon)
                                .foregroundColor(modelValidationStatus.color)
                            
                            Text(modelValidationStatus.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("验证模型") {
                        validateModel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            validateModel()
        }
    }
    
    private func selectModelPath() {
        // 实现模型路径选择
        print("📁 选择模型路径")
    }
    
    private func validateModel() {
        // 验证模型文件
        if configManager.validateModelFiles() {
            modelValidationStatus = .valid
        } else {
            modelValidationStatus = .invalid
        }
    }
}

// MARK: - Recognition Engine Section

struct RecognitionEngineSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "识别引擎设置",
            description: "配置语音识别引擎的性能和行为参数"
        ) {
            VStack(spacing: 16) {
                // 线程数设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("线程数")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.recognition.numThreads)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(configManager.recognition.numThreads) },
                            set: { configManager.recognition.numThreads = Int($0) }
                        ),
                        in: 1...8,
                        step: 1
                    )
                    
                    HStack {
                        Text("1 (节能)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("推荐: \(recommendedThreadCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("8 (高性能)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("使用的 CPU 线程数，建议设置为 CPU 核心数的一半")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 运算提供者
                VStack(alignment: .leading, spacing: 8) {
                    Text("运算提供者")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("运算提供者", selection: $configManager.recognition.provider) {
                        Text("CPU").tag("cpu")
                        Text("CoreML").tag("coreml")
                        Text("GPU (Metal)").tag("gpu")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("选择用于模型推理的硬件加速器")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 解码方法
                VStack(alignment: .leading, spacing: 8) {
                    Text("解码方法")
                        .font(.system(size: 14, weight: .medium))
                    
                    Picker("解码方法", selection: $configManager.recognition.decodingMethod) {
                        Text("贪心搜索").tag("greedy_search")
                        Text("波束搜索").tag("beam_search")
                        Text("修正贪心").tag("modified_greedy_search")
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("语音识别的解码算法，贪心搜索速度快，波束搜索准确率高")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if configManager.recognition.decodingMethod == "beam_search" {
                    // 最大激活路径数（仅波束搜索）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最大激活路径数")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.recognition.maxActivePaths)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(configManager.recognition.maxActivePaths) },
                                set: { configManager.recognition.maxActivePaths = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        
                        Text("波束搜索时保持的最大路径数，增加可提高准确率但降低速度")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var recommendedThreadCount: Int {
        max(1, ProcessInfo.processInfo.processorCount / 2)
    }
}

// MARK: - Endpoint Detection Section

struct EndpointDetectionSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "端点检测",
            description: "配置语音开始和结束的自动检测参数"
        ) {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "启用端点检测",
                    description: "自动检测语音的开始和结束，提高识别效率",
                    isOn: $configManager.recognition.enableEndpoint
                )
                
                if configManager.recognition.enableEndpoint {
                    Divider()
                    
                    // 规则1：最小尾随静音
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("规则1 - 最小尾随静音")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.recognition.rule1MinTrailingSilence, specifier: "%.1f")秒")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $configManager.recognition.rule1MinTrailingSilence,
                            in: 0.5...5.0,
                            step: 0.1
                        )
                        
                        Text("检测到语音后，静音持续此时间才认为语音结束")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // 规则2：最小尾随静音（严格）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("规则2 - 严格尾随静音")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.recognition.rule2MinTrailingSilence, specifier: "%.1f")秒")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $configManager.recognition.rule2MinTrailingSilence,
                            in: 0.5...3.0,
                            step: 0.1
                        )
                        
                        Text("更严格的静音检测，用于快速结束检测")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // 规则3：最小语音长度
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("规则3 - 最小语音长度")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(configManager.recognition.rule3MinUtteranceLength, specifier: "%.1f")秒")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $configManager.recognition.rule3MinUtteranceLength,
                            in: 5.0...30.0,
                            step: 1.0
                        )
                        
                        Text("语音段的最小长度，防止过早结束长句子")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Language and Text Section

struct LanguageAndTextSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "语言和文本处理",
            description: "配置识别语言和文本后处理选项"
        ) {
            VStack(spacing: 16) {
                // 识别语言设置
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("识别语言")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(languageDisplayName(configManager.recognition.language))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // 语言选项卡片
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // 中文简体
                            LanguageCard(
                                language: "zh",
                                title: "中文简体",
                                subtitle: "普通话识别",
                                icon: "🇨🇳",
                                isSelected: configManager.recognition.language == "zh"
                            ) {
                                configManager.recognition.language = "zh"
                            }
                            
                            // 中文繁体
                            LanguageCard(
                                language: "zh-tw",
                                title: "中文繁體",
                                subtitle: "繁體中文識別",
                                icon: "🇭🇰",
                                isSelected: configManager.recognition.language == "zh-tw"
                            ) {
                                configManager.recognition.language = "zh-tw"
                            }
                        }
                        
                        HStack(spacing: 12) {
                            // 英文
                            LanguageCard(
                                language: "en",
                                title: "English",
                                subtitle: "English recognition",
                                icon: "🇺🇸",
                                isSelected: configManager.recognition.language == "en"
                            ) {
                                configManager.recognition.language = "en"
                            }
                            
                            // 中英混合
                            LanguageCard(
                                language: "zh-en",
                                title: "中英混合",
                                subtitle: "Mixed language",
                                icon: "🌐",
                                isSelected: configManager.recognition.language == "zh-en"
                            ) {
                                configManager.recognition.language = "zh-en"
                            }
                        }
                    }
                    
                    // 动态说明
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text(languageDescription(configManager.recognition.language))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 标点符号处理
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggle(
                        title: "启用标点符号",
                        description: "自动为识别结果添加标点符号",
                        isOn: $configManager.recognition.enablePunctuation
                    )
                    
                    if configManager.recognition.enablePunctuation {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("标点符号处理将使用 CT-Transformer 模型")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("可在「热词」设置中进一步配置标点符号选项")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                    }
                }
                
                Divider()
                
                // 数字转换
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggle(
                        title: "启用数字转换",
                        description: "将语音中的数字转换为阿拉伯数字形式",
                        isOn: $configManager.recognition.enableNumberConversion
                    )
                    
                    if configManager.recognition.enableNumberConversion {
                        HStack {
                            Image(systemName: "textformat.123")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text("例如：「三十二」→「32」，「二千零二十四」→「2024」")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                    }
                }
                
                Divider()
                
                // 模型名称显示
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前模型")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(configManager.recognition.modelName)
                                .font(.system(size: 13, family: .monospaced))
                                .foregroundColor(.primary)
                            
                            Text("模型类型: \(configManager.recognition.modelType)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("更换模型") {
                            changeModel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("当前使用的语音识别模型，不同模型适合不同语言")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func changeModel() {
        // 实现模型切换功能
        print("🔄 切换模型")
    }
    
    // 语言辅助函数
    private func languageDisplayName(_ language: String) -> String {
        switch language {
        case "zh": return "中文简体"
        case "zh-tw": return "中文繁体"
        case "en": return "English"
        case "zh-en": return "中英混合"
        default: return "未知语言"
        }
    }
    
    private func languageDescription(_ language: String) -> String {
        switch language {
        case "zh": return "适用于普通话识别，准确率最高"
        case "zh-tw": return "适用于繁体中文和台湾话识别"
        case "en": return "适用于英文语音识别"
        case "zh-en": return "适用于中英文混合语音，自动切换识别"
        default: return "请选择合适的识别语言"
        }
    }
}

// MARK: - Language Card Component

struct LanguageCard: View {
    let language: String
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 24))
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.clear)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? 
                          Color.accentColor.opacity(0.15) : 
                          Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? 
                           Color.accentColor : 
                           Color(NSColor.separatorColor), 
                           lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Performance Section

struct PerformanceSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "性能设置",
            description: "调整识别性能和资源使用相关参数"
        ) {
            VStack(spacing: 16) {
                // 热词得分
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("热词得分权重")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.recognition.hotwordsScore, specifier: "%.1f")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $configManager.recognition.hotwordsScore,
                        in: 0.5...3.0,
                        step: 0.1
                    )
                    
                    Text("热词在识别中的权重，值越大热词越容易被识别出来")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 调试模式
                SettingsToggle(
                    title: "启用调试模式",
                    description: "输出详细的识别过程信息，用于问题诊断（影响性能）",
                    isOn: $configManager.recognition.debug
                )
                
                if configManager.recognition.debug {
                    WarningCard(
                        title: "调试模式已启用",
                        description: "调试模式会输出大量日志信息，可能影响识别性能。建议仅在需要诊断问题时使用。"
                    )
                }
                
                Divider()
                
                // 性能信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("性能信息")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(spacing: 8) {
                        PerformanceInfoRow(
                            title: "CPU 核心数",
                            value: "\(ProcessInfo.processInfo.processorCount)"
                        )
                        
                        PerformanceInfoRow(
                            title: "可用内存",
                            value: formatMemorySize(ProcessInfo.processInfo.physicalMemory)
                        )
                        
                        PerformanceInfoRow(
                            title: "推荐线程数",
                            value: "\(recommendedThreadCount)"
                        )
                    }
                }
            }
        }
    }
    
    private var recommendedThreadCount: Int {
        max(1, ProcessInfo.processInfo.processorCount / 2)
    }
    
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Performance Info Row

struct PerformanceInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Model Validation Status

enum ModelValidationStatus {
    case unknown
    case valid
    case invalid
    case validating
    
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .valid: return "checkmark.circle"
        case .invalid: return "xmark.circle"
        case .validating: return "clock.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .valid: return .green
        case .invalid: return .red
        case .validating: return .blue
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "模型状态未知"
        case .valid: return "模型文件完整有效"
        case .invalid: return "模型文件缺失或损坏"
        case .validating: return "正在验证模型..."
        }
    }
}

// MARK: - Preview

#Preview {
    RecognitionSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 900)
}