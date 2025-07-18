# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CapsWriter-mac 是一个基于 SwiftUI 的 macOS 语音转录应用，集成了 Sherpa-ONNX 语音识别引擎。应用通过键盘快捷键（连击3下O键）触发语音录制，实现本地语音转文字功能。

**🔒 安全状态**: 已完成5个关键安全漏洞修复（2025-07-19）
- 文件监控安全防护 ✅
- 正则表达式DoS防护 ✅  
- C API调用安全加固 ✅
- 音频缓冲区溢出防护 ✅
- 递归栈溢出防护 ✅
- 安全等级: A级（生产就绪）

## 常用开发命令

### 构建和运行
```bash
# 使用 Xcode 构建项目
xcodebuild -project CapsWriter-mac.xcodeproj -scheme CapsWriter-mac build

# 运行构建前检查脚本
source ~/.zshrc >/dev/null 2>&1
bash build_test.sh

# 项目验证脚本
source ~/.zshrc >/dev/null 2>&1
bash project_validation.sh

# 运行集成测试
source ~/.zshrc >/dev/null 2>&1
swift test_sherpa_integration.swift

# 动态库设置
source ~/.zshrc >/dev/null 2>&1
bash setup_dylib.sh
bash copy_dylib.sh
```

### 测试命令
```bash
# 构建测试
source ~/.zshrc >/dev/null 2>&1
bash CapsWriter-mac/build_test.sh

# Sherpa集成测试
source ~/.zshrc >/dev/null 2>&1
swift CapsWriter-mac/integration_test.swift
```

## 核心架构

### 应用层次结构
```
CapsWriterApp (SwiftUI App)
├── AppDelegate (应用委托, 服务协调)
├── ContentView (主界面)
├── StatusBarController (菜单栏管理)
├── 核心服务层
│   ├── KeyboardMonitor (键盘监听)
│   ├── AudioCaptureService (音频采集) 🔒
│   └── SherpaASRService (语音识别) 🔒
├── 业务服务层
│   ├── HotWordService (热词替换) 🔒
│   ├── TextProcessingService (文本处理)
│   └── PunctuationService (标点符号)
└── 基础架构层
    ├── ResourceManager (资源管理) 🔒
    ├── ConfigurationManager (配置管理)
    ├── DIContainer (依赖注入)
    └── EventBus (事件总线)
```

🔒 = 已完成安全加固

### 关键组件

#### 1. 键盘监听器 (KeyboardMonitor.swift)
- 监听 O 键连击3次的组合键（键码31）
- 使用 Core Graphics Events API 实现系统级监听
- 需要辅助功能权限（Accessibility Permission）
- 实现连击检测机制（3次连击，间隔800ms，防抖100ms）

#### 2. 语音识别服务 (SherpaASRService.swift) 🔒
- 集成 Sherpa-ONNX C API 实现离线语音识别
- 使用 paraformer-zh-streaming 中文流式模型
- 配置：16kHz采样率，单声道，float32格式
- 支持实时部分结果和最终结果回调
- **安全特性**: C API调用安全检查、空指针防护、资源泄漏防护

#### 3. 音频采集服务 (AudioCaptureService.swift) 🔒
- 使用 AVAudioEngine 进行麦克风音频采集
- 自动处理麦克风权限请求
- 音频格式转换：输入格式 → 16kHz单声道float32
- 实时音频流转发到语音识别服务
- **安全特性**: 缓冲区溢出防护、格式验证、边界检查

#### 4. 状态管理 (RecordingState.swift)
- 单例模式管理全局状态
- 使用 ObservableObject 和 @Published 实现响应式更新
- 统一管理录音状态、权限状态、服务状态

### 数据流
```
键盘事件(O键x3) → KeyboardMonitor → AppDelegate.startRecording()
                                         ↓
音频采集 ← AudioCaptureService ← 麦克风权限检查
    ↓
音频缓冲区 → SherpaASRService → 识别结果 → UI更新
```

## 重要配置

### 权限要求
- **辅助功能权限**: 用于键盘事件监听
  - 系统设置 → 隐私与安全性 → 辅助功能
- **麦克风权限**: 用于音频采集
  - 自动请求，首次使用时弹出权限对话框

### 模型文件
- 位置: `CapsWriter-mac/models/paraformer-zh-streaming/`
- 包含: encoder.onnx, decoder.onnx, tokens.txt
- 用途: 中文流式语音识别

### 动态库
- Sherpa-ONNX C API: `CapsWriter-mac/Frameworks/libsherpa-onnx-c-api.dylib`
- 头文件: `CapsWriter-mac/Include/c-api.h`
- 桥接: `SherpaONNX-Bridging-Header.h`

## 开发注意事项

### 调试模式
- 所有服务都有详细的日志输出
- 使用特定emoji前缀区分不同组件的日志
- RecordingState 提供实时状态监控

### 线程安全
- 音频处理在独立队列中执行
- UI更新严格在主线程进行
- 使用 weak self 避免循环引用

### 错误处理
- 权限检查和错误提示
- 服务初始化失败时的降级方案
- 音频引擎异常的自动恢复

### 内存管理
- Sherpa-ONNX 资源的正确清理
- 音频引擎的生命周期管理
- 避免音频缓冲区累积

## 常见问题排查

### 1. 键盘监听不工作
- 检查辅助功能权限是否授予
- 查看控制台日志确认监听器启动状态
- 验证 O 键连击时序（3次，间隔小于800ms）

### 2. 语音识别无结果
- 确认麦克风权限已授予
- 检查模型文件是否完整
- 查看音频采集和识别服务日志

### 3. 动态库链接错误
- 运行 setup_dylib.sh 脚本重新设置
- 检查 libsherpa-onnx-c-api.dylib 路径
- 验证 Xcode 项目中的库引用

### 4. 应用图标不显示
- 参考 DOCK_ICON_FIX.md 修复指南
- 检查 Assets.xcassets 中的图标文件
- 确认 Info.plist 中的 CFBundleIconName 配置

## 扩展开发

### 添加新的语音识别功能
1. 在 SherpaASRService 中扩展识别配置
2. 实现新的 SpeechRecognitionDelegate 方法
3. 在 AppDelegate 中处理新的识别结果

### 修改键盘快捷键
1. 在 KeyboardMonitor.swift 中修改键码常量
2. 调整连击检测逻辑（如需要）
3. 更新 KEYBOARD_MONITOR_SETUP.md 文档

### 集成新的语音模型
1. 将新模型文件放入 models/ 目录
2. 在 SherpaASRService 中更新模型路径配置
3. 根据模型类型调整识别器配置

## 🔒 安全架构

### 已实现的安全防护

#### 1. HotWordService 安全防护
- **路径遍历防护**: 防止 `../` 攻击，限制系统目录访问
- **文件类型检查**: 白名单机制，仅允许 txt/json/plist
- **文件大小限制**: 10MB 大小限制，防止大文件攻击
- **频率限制**: 1秒内最多1次回调，防止资源滥用

#### 2. 正则表达式DoS防护
- **危险模式检测**: 检测 `(.*)+`, `(.+)+` 等灾难性回溯
- **执行超时**: 2秒正则表达式执行超时保护
- **复杂度限制**: 嵌套深度、重复次数限制
- **缓存管理**: 100个正则表达式缓存限制

#### 3. C API调用安全
- **空指针检查**: 所有C API调用前验证指针有效性
- **参数验证**: 字符串长度限制、格式验证
- **资源管理**: 完善的资源释放和清理机制
- **错误处理**: 全面的异常捕获和恢复

#### 4. 音频缓冲区安全
- **缓冲区验证**: 检查缓冲区有效性和边界
- **大小限制**: 1MB frames 最大缓冲区限制
- **格式验证**: 采样率、声道数、数据指针检查
- **安全转换**: 防止整数溢出的格式转换

#### 5. 递归栈溢出防护
- **迭代实现**: 使用迭代替代递归，防止栈溢出
- **深度限制**: 100层最大处理深度限制
- **循环检测**: 检测和处理循环依赖
- **资源队列**: 安全的资源管理和清理

### 安全开发规范

#### 代码审查要点
1. **输入验证**: 所有外部输入必须验证
2. **边界检查**: 数组、缓冲区访问前检查边界
3. **资源管理**: 及时释放资源，避免泄漏
4. **错误处理**: 完善的异常处理机制
5. **权限最小化**: 只请求必要的系统权限

#### 安全测试
- **静态分析**: 使用 Xcode 静态分析工具
- **动态测试**: 边界条件、异常输入测试
- **内存检查**: 检查内存泄漏和越界访问
- **性能测试**: 验证安全检查的性能影响

### 安全监控
- **日志记录**: 记录所有安全相关事件
- **异常监控**: 监控异常和错误模式
- **性能监控**: 监控安全检查对性能的影响
- **定期审计**: 定期进行安全代码审计

### 威胁模型
- **文件系统攻击**: 路径遍历、恶意文件
- **拒绝服务攻击**: 正则表达式、资源耗尽
- **内存攻击**: 缓冲区溢出、栈溢出
- **API攻击**: 恶意参数、空指针利用