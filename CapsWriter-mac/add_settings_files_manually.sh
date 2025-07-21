#!/bin/bash

# 手动添加设置文件到 Xcode 项目的脚本
# 由于无法直接修改 project.pbxproj，我们创建一个简化的解决方案

echo "🔧 CapsWriter-mac 设置文件集成脚本"
echo "================================================"

# 定义需要添加的设置文件
SETTINGS_FILES=(
    "CapsWriter-mac/Sources/Views/Settings/SettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/SettingsTypes.swift"
    "CapsWriter-mac/Sources/Views/Settings/Components/SettingsComponents.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/GeneralSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/AudioSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/RecognitionSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/HotWordSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/ShortcutSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/AdvancedSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Categories/AboutSettingsView.swift"
    "CapsWriter-mac/Sources/Views/Settings/Editors/HotWordEditor.swift"
)

# 检查文件是否存在
echo "📋 检查设置文件..."
missing_files=0
for file in "${SETTINGS_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (不存在)"
        ((missing_files++))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo "❌ 发现 $missing_files 个缺失文件，请检查文件路径"
    exit 1
fi

echo "✅ 所有设置文件存在"

# 创建组合设置文件 - 临时解决方案
echo "🔄 创建组合设置文件..."

cat > "CapsWriter-mac/CapsWriter-mac/CombinedSettingsView.swift" << 'EOF'
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
                Toggle("启用热词替换", isOn: $configManager.hotwords.enableHotWords)
                Toggle("启用中文热词", isOn: $configManager.hotwords.enableChineseHotWords)
                Toggle("启用英文热词", isOn: $configManager.hotwords.enableEnglishHotWords)
                Toggle("启用规则替换", isOn: $configManager.hotwords.enableRuleBasedReplacement)
                
                Text("热词文件监控")
                    .font(.headline)
                
                Toggle("自动重载热词文件", isOn: $configManager.hotwords.enableFileMonitoring)
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
                    Text("当前: 连击3下 O 键")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("连击检测")
                    HStack {
                        Text("间隔时间:")
                        Slider(value: $configManager.keyboard.tripleClickInterval, in: 200...2000, step: 100)
                        Text("\(Int(configManager.keyboard.tripleClickInterval))ms")
                    }
                }
                
                Toggle("启用键盘监听", isOn: $configManager.keyboard.enableKeyboardMonitoring)
                Toggle("启用连击检测", isOn: $configManager.keyboard.enableTripleClickDetection)
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
                    Text("日志级别")
                    Picker("日志级别", selection: $configManager.advanced.logLevel) {
                        Text("调试").tag("debug")
                        Text("信息").tag("info")
                        Text("警告").tag("warning")
                        Text("错误").tag("error")
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("启用调试模式", isOn: $configManager.advanced.enableDebugMode)
                Toggle("启用性能监控", isOn: $configManager.advanced.enablePerformanceMonitoring)
                Toggle("启用内存监控", isOn: $configManager.advanced.enableMemoryMonitoring)
                
                VStack(alignment: .leading) {
                    Text("权限检查延迟")
                    HStack {
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
EOF

echo "✅ 创建了 CombinedSettingsView.swift"

# 创建集成说明
cat > "settings_integration_manual.md" << 'EOF'
# 设置界面集成手册

## 当前状态
- ✅ 创建了 `CombinedSettingsView.swift` 作为临时集成解决方案
- ✅ 包含所有7个设置分类的基本功能
- ✅ 集成了 ConfigurationManager 进行配置管理
- ⚠️ 完整设置界面文件位于 `Sources/Views/Settings/` 目录

## 使用方法

### 1. 替换临时设置视图
在 StatusBarController.swift 中:
```swift
// 替换现有的内联视图
settingsWindow.contentView = NSHostingView(rootView: CombinedSettingsView())
```

在 ContentView.swift 中:
```swift
// 替换现有的内联视图
CombinedSettingsView()
    .tabItem {
        Image(systemName: "gearshape")
        Text("设置")
    }
    .tag(4)
```

### 2. 完整集成步骤
1. 在 Xcode 中手动添加 `Sources/Views/Settings/` 目录下的所有文件
2. 替换 `CombinedSettingsView` 为完整的 `SettingsView`
3. 验证所有设置功能正常工作

### 3. 文件清单
需要添加到 Xcode 项目的文件:
- SettingsView.swift (主设置界面)
- SettingsTypes.swift (类型定义)
- Components/SettingsComponents.swift (UI组件库)
- Categories/*.swift (7个设置分类)
- Editors/HotWordEditor.swift (热词编辑器)

## 功能验证
- [ ] 通用设置 - 应用行为配置
- [ ] 音频设置 - 采样率、声道配置
- [ ] 识别设置 - 模型、语言选择
- [ ] 热词设置 - 热词功能开关
- [ ] 快捷键设置 - 键盘监听配置
- [ ] 高级设置 - 调试、性能选项
- [ ] 关于信息 - 版本、技术栈信息
EOF

echo "✅ 创建了集成手册 settings_integration_manual.md"

echo ""
echo "🎯 下一步操作:"
echo "1. 使用新的 CombinedSettingsView 替换临时设置视图"
echo "2. 测试设置界面功能"
echo "3. 手动将 Sources/Views/Settings/ 文件添加到 Xcode 项目"
echo "4. 替换为完整的 SettingsView 实现"
echo ""
echo "✅ 设置文件集成脚本执行完成!"