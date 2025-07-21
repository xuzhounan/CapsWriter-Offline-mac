import SwiftUI

// 组合设置视图 - 包含所有设置功能的临时集成解决方案
struct CombinedSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 通用设置
            GeneralSettingsContent()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("通用")
                }
                .tag(0)
            
            // 音频设置
            AudioSettingsContent()
                .tabItem {
                    Image(systemName: "speaker.wave.2")
                    Text("音频")
                }
                .tag(1)
            
            // 识别设置
            RecognitionSettingsContent()
                .tabItem {
                    Image(systemName: "brain")
                    Text("识别")
                }
                .tag(2)
            
            // 热词设置
            HotWordSettingsContent()
                .tabItem {
                    Image(systemName: "text.badge.plus")
                    Text("热词")
                }
                .tag(3)
            
            // 快捷键设置
            ShortcutSettingsContent()
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("快捷键")
                }
                .tag(4)
            
            // 高级设置
            AdvancedSettingsContent()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("高级")
                }
                .tag(5)
            
            // 关于信息
            AboutSettingsContent()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("关于")
                }
                .tag(6)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// 通用设置内容
struct GeneralSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("通用设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("启用自动启动", isOn: $configManager.appBehavior.enableAutoLaunch)
                Toggle("显示状态栏图标", isOn: $configManager.ui.showStatusBarIcon)
                Toggle("启用声音提示", isOn: $configManager.ui.enableSoundEffects)
                Toggle("显示录音指示器", isOn: $configManager.ui.showRecordingIndicator)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 音频设置内容
struct AudioSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("音频设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("采样率")
                    Picker("采样率", selection: $configManager.audio.sampleRate) {
                        Text("16 kHz").tag(16000)
                        Text("44.1 kHz").tag(44100)
                        Text("48 kHz").tag(48000)
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading) {
                    Text("声道数")
                    Picker("声道数", selection: $configManager.audio.channels) {
                        Text("单声道").tag(1)
                        Text("立体声").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle("启用降噪", isOn: $configManager.audio.enableNoiseReduction)
                Toggle("启用音频增强", isOn: $configManager.audio.enableAudioEnhancement)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 识别设置内容
struct RecognitionSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("识别设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("识别模型")
                    Picker("识别模型", selection: $configManager.recognition.modelName) {
                        Text("Paraformer 中文").tag("paraformer-zh")
                        Text("Paraformer 流式").tag("paraformer-zh-streaming")
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading) {
                    Text("语言设置")
                    Picker("语言", selection: $configManager.recognition.language) {
                        Text("中文").tag("zh")
                        Text("英文").tag("en")
                        Text("中英混合").tag("zh-en")
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle("启用标点符号", isOn: $configManager.recognition.enablePunctuation)
                Toggle("启用数字转换", isOn: $configManager.recognition.enableNumberConversion)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 热词设置内容
struct HotWordSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("热词设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("启用热词替换", isOn: $configManager.textProcessing.enableHotwordReplacement)
                Toggle("启用文件监控", isOn: $configManager.textProcessing.enableHotWordFileWatching)
                
                Text("热词处理配置")
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    Text("处理超时时间")
                    HStack {
                        Slider(value: $configManager.textProcessing.hotWordProcessingTimeout, in: 1...10, step: 0.5)
                        Text("\(configManager.textProcessing.hotWordProcessingTimeout, specifier: "%.1f")s")
                    }
                }
                
                Text("热词文件路径")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("中文热词文件:")
                        Text(configManager.textProcessing.hotWordChinesePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("英文热词文件:")
                        Text(configManager.textProcessing.hotWordEnglishPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("规则文件:")
                        Text(configManager.textProcessing.hotWordRulePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 快捷键设置内容
struct ShortcutSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("快捷键设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("录音快捷键")
                    Text("当前: 连击\(configManager.keyboard.requiredClicks)下 O 键 (键码: \(configManager.keyboard.primaryKeyCode))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("连击配置")
                    HStack {
                        Text("连击次数:")
                        Stepper(value: $configManager.keyboard.requiredClicks, in: 2...5) {
                            Text("\(configManager.keyboard.requiredClicks)")
                        }
                    }
                    
                    HStack {
                        Text("连击间隔:")
                        Slider(value: $configManager.keyboard.clickInterval, in: 0.2...2.0, step: 0.1)
                        Text("\(Int(configManager.keyboard.clickInterval * 1000))ms")
                    }
                    
                    HStack {
                        Text("防抖间隔:")
                        Slider(value: $configManager.keyboard.debounceInterval, in: 0.05...0.5, step: 0.05)
                        Text("\(Int(configManager.keyboard.debounceInterval * 1000))ms")
                    }
                }
                
                Toggle("启用键盘监听", isOn: $configManager.keyboard.enabled)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 高级设置内容
struct AdvancedSettingsContent: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("高级设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("日志配置")
                    Picker("日志级别", selection: $configManager.debug.logLevel) {
                        Text("调试").tag("debug")
                        Text("信息").tag("info")
                        Text("警告").tag("warning")
                        Text("错误").tag("error")
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("最大日志条数:")
                        Stepper(value: $configManager.debug.maxLogEntries, in: 100...5000, step: 100) {
                            Text("\(configManager.debug.maxLogEntries)")
                        }
                    }
                }
                
                Text("调试选项")
                    .font(.headline)
                
                Toggle("启用详细日志", isOn: $configManager.debug.enableVerboseLogging)
                Toggle("启用性能监控", isOn: $configManager.debug.enablePerformanceMetrics)
                
                Text("应用行为")
                    .font(.headline)
                
                Toggle("自动启动键盘监听", isOn: $configManager.appBehavior.autoStartKeyboardMonitor)
                Toggle("自动启动ASR服务", isOn: $configManager.appBehavior.autoStartASRService)
                Toggle("后台模式", isOn: $configManager.appBehavior.backgroundMode)
                
                VStack(alignment: .leading) {
                    Text("启动延迟")
                    HStack {
                        Text("应用启动:")
                        Slider(value: $configManager.appBehavior.startupDelay, in: 0...5, step: 0.1)
                        Text("\(configManager.appBehavior.startupDelay, specifier: "%.1f")s")
                    }
                    
                    HStack {
                        Text("识别启动:")
                        Slider(value: $configManager.appBehavior.recognitionStartDelay, in: 0...5, step: 0.1)
                        Text("\(configManager.appBehavior.recognitionStartDelay, specifier: "%.1f")s")
                    }
                    
                    HStack {
                        Text("权限检查:")
                        Slider(value: $configManager.appBehavior.permissionCheckDelay, in: 1...10, step: 0.5)
                        Text("\(configManager.appBehavior.permissionCheckDelay, specifier: "%.1f")s")
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 关于信息内容
struct AboutSettingsContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("关于 CapsWriter")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("CapsWriter-mac")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("版本 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("基于 Sherpa-ONNX 的离线语音转文字工具")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("技术栈:")
                        .font(.headline)
                    
                    Text("• SwiftUI + macOS")
                    Text("• Sherpa-ONNX 语音识别")
                    Text("• Paraformer 中文模型")
                    Text("• 本地离线处理")
                }
                .font(.caption)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                )
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    CombinedSettingsView()
}