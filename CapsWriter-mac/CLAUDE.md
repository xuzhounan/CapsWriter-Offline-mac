# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CapsWriter-mac 是一个基于 SwiftUI 的 macOS 语音转录应用，集成了 Sherpa-ONNX 语音识别引擎。应用通过键盘快捷键（连击3下O键）触发语音录制，实现本地语音转文字功能。

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
└── 服务层
    ├── KeyboardMonitor (键盘监听)
    ├── AudioCaptureService (音频采集)
    └── SherpaASRService (语音识别)
```

### 关键组件

#### 1. 键盘监听器 (KeyboardMonitor.swift)
- 监听 O 键连击3次的组合键（键码31）
- 使用 Core Graphics Events API 实现系统级监听
- 需要辅助功能权限（Accessibility Permission）
- 实现连击检测机制（3次连击，间隔800ms，防抖100ms）

#### 2. 语音识别服务 (SherpaASRService.swift)
- 集成 Sherpa-ONNX C API 实现离线语音识别
- 使用 paraformer-zh-streaming 中文流式模型
- 配置：16kHz采样率，单声道，float32格式
- 支持实时部分结果和最终结果回调

#### 3. 音频采集服务 (AudioCaptureService.swift)
- 使用 AVAudioEngine 进行麦克风音频采集
- 自动处理麦克风权限请求
- 音频格式转换：输入格式 → 16kHz单声道float32
- 实时音频流转发到语音识别服务

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