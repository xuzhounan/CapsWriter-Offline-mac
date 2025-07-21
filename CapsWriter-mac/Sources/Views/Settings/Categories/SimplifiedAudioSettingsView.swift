import SwiftUI

// MARK: - Simplified Audio Settings View

/// 简化的音频设置界面
struct SimplifiedAudioSettingsView: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 音频质量设置（简化版）
                AudioQualitySection(configManager: configManager)
                
                // 音频增益设置
                AudioGainSection(configManager: configManager)
                
                // 录音增强设置
                AudioEnhancementSection(configManager: configManager)
            }
            .padding()
        }
    }
}

// MARK: - Audio Quality Section

struct AudioQualitySection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "音频质量",
            description: "选择适合您需求的音频处理方式"
        ) {
            VStack(spacing: 16) {
                // 音频质量预设
                VStack(alignment: .leading, spacing: 12) {
                    Text("质量模式")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(spacing: 12) {
                        // 低延迟模式
                        QualityOptionButton(
                            title: "低延迟模式",
                            description: "最快响应，适合实时转录",
                            icon: "bolt.fill",
                            iconColor: .orange,
                            isSelected: configManager.audio.audioQuality == "low_latency"
                        ) {
                            configManager.audio.audioQuality = "low_latency"
                            configManager.audio.applyQualityPreset()
                        }
                        
                        // 平衡模式
                        QualityOptionButton(
                            title: "平衡模式",
                            description: "延迟与稳定性的最佳平衡（推荐）",
                            icon: "scale.3d",
                            iconColor: .green,
                            isSelected: configManager.audio.audioQuality == "balanced"
                        ) {
                            configManager.audio.audioQuality = "balanced"
                            configManager.audio.applyQualityPreset()
                        }
                        
                        // 稳定模式
                        QualityOptionButton(
                            title: "稳定模式",
                            description: "最高稳定性，适合长时间录音",
                            icon: "checkmark.shield.fill",
                            iconColor: .blue,
                            isSelected: configManager.audio.audioQuality == "stable"
                        ) {
                            configManager.audio.audioQuality = "stable"
                            configManager.audio.applyQualityPreset()
                        }
                    }
                }
                
                Divider()
                
                // 当前技术参数显示（可收起的高级信息）
                DisclosureGroup("技术参数") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("采样率:")
                            Spacer()
                            Text("\(Int(configManager.audio.sampleRate)) Hz")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("缓冲区大小:")
                            Spacer()
                            Text("\(configManager.audio.bufferSize) frames")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("预期延迟:")
                            Spacer()
                            Text(bufferLatency + " ms")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("声道数:")
                            Spacer()
                            Text("\(configManager.audio.channels) 声道")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 12))
                    .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var bufferLatency: String {
        let latencyMs = Double(configManager.audio.bufferSize) / configManager.audio.sampleRate * 1000
        return String(format: "%.1f", latencyMs)
    }
}

// MARK: - Audio Gain Section

struct AudioGainSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "音量调节",
            description: "调整麦克风录音音量"
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("输入音量")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(configManager.audio.inputGain, specifier: "%.1f") dB")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: $configManager.audio.inputGain,
                        in: -20...20,
                        step: 0.5
                    )
                    
                    HStack {
                        Text("较低")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("调整麦克风输入音量大小")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("较高")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 快速调节按钮
                HStack(spacing: 12) {
                    Button("重置") {
                        configManager.audio.inputGain = 0.0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("提高音量") {
                        configManager.audio.inputGain = min(20.0, configManager.audio.inputGain + 3.0)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("降低音量") {
                        configManager.audio.inputGain = max(-20.0, configManager.audio.inputGain - 3.0)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Audio Enhancement Section

struct AudioEnhancementSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        SettingsSection(
            title: "音频增强",
            description: "提高录音质量的附加功能"
        ) {
            VStack(spacing: 16) {
                // 噪声抑制
                SettingsToggle(
                    title: "噪声抑制",
                    description: "自动减少背景噪音，提高语音清晰度",
                    isOn: $configManager.audio.enableNoiseReduction
                )
                
                // 音频增强
                SettingsToggle(
                    title: "音频增强",
                    description: "智能优化音频质量，提升识别准确率",
                    isOn: $configManager.audio.enableAudioEnhancement
                )
                
                if configManager.audio.enableNoiseReduction || configManager.audio.enableAudioEnhancement {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("音频增强功能可能会略微增加延迟")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Quality Option Button

struct QualityOptionButton: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? 
                          Color.accentColor.opacity(0.1) : 
                          Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? 
                           Color.accentColor : 
                           Color(NSColor.separatorColor).opacity(0.5), 
                           lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

// MARK: - Preview

#Preview {
    SimplifiedAudioSettingsView(configManager: ConfigurationManager.shared)
        .frame(width: 600, height: 800)
}