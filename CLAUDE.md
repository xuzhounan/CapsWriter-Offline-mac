# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CapsWriter-Offline 是一个离线语音输入工具，支持 Windows/Linux/macOS，提供两个主要功能：
1. 按 CapsLock 键进行实时语音输入（录音-识别-输入）
2. 音视频文件拖拽转录生成字幕

## 架构设计

项目采用客户端-服务端分离架构：

### Python 端 (跨平台核心)
- **core_server.py**: WebSocket 服务端，负责语音识别处理
- **core_client.py**: 客户端，负责音频捕获、键盘监听、结果输出
- **config.py**: 统一配置文件，包含服务器地址、快捷键设置等

### macOS 原生端 (Swift)
- **CapsWriter-mac/**: SwiftUI 应用，为 macOS 提供原生体验
- **ConfigurationManager.swift**: 统一配置管理系统，支持持久化和响应式更新
- **SherpaOnnx.swift**: Sherpa-ONNX 语音识别引擎的 Swift 封装
- **KeyboardMonitor.swift**: macOS 系统级键盘事件监听
- **AudioCaptureService.swift**: 音频录制服务

### 核心技术栈
- **语音识别**: Sherpa-ONNX + Paraformer 模型（阿里巴巴开源）
- **标点符号**: CT-Transformer 模型
- **通信**: WebSocket (Python asyncio)
- **音频处理**: PyAudio, soundfile
- **键盘监听**: keyboard (Python), Carbon API (macOS)

## 常用开发命令

### Python 环境
```bash
# 安装服务端依赖
pip install -r requirements-server.txt

# 安装客户端依赖  
pip install -r requirements-client.txt

# 启动服务端
python core_server.py

# 启动客户端 (macOS 需要 sudo)
python core_client.py
```

### macOS 开发
```bash
# Xcode 项目路径
open CapsWriter-mac/CapsWriter-mac.xcodeproj

# 构建测试
cd CapsWriter-mac/CapsWriter-mac
./build_test.sh

# 集成测试
swift test_sherpa_integration.swift
```

### 打包构建
```bash
# Python 打包 (使用 PyInstaller)
pyinstaller build.spec

# Sherpa-ONNX 构建
./build_sherpa_onnx_latest.sh

# 复制动态库
./copy_dylib.sh
```

## 模型和依赖

### 模型文件结构
```
models/
├── paraformer-offline-zh/          # 中文语音识别模型
│   ├── model.int8.onnx
│   └── tokens.txt
└── punc_ct-transformer_cn-en/      # 中英文标点符号模型
```

### 关键配置文件
- **hot-zh.txt**: 中文热词替换
- **hot-en.txt**: 英文热词替换  
- **hot-rule.txt**: 自定义替换规则
- **keywords.txt**: 关键词日记功能

## 项目特有约定

### 音频处理
- 默认采样率: 16kHz
- 录音格式: WAV (无 FFmpeg) / MP3 (有 FFmpeg)
- 分段处理: 麦克风 15s，文件 25s，重叠 2s

### 平台特殊处理
- **macOS**: 需要 sudo 权限运行客户端，默认快捷键改为 'right shift'
- **Windows**: 支持隐藏黑窗口启动，自启动配置
- **Linux**: 需要 xclip 支持剪贴板操作

### 开发注意事项
- macOS Swift 代码需要处理权限请求 (麦克风、辅助功能)
- 跨进程通信使用 multiprocessing.Manager()
- WebSocket 连接状态需要在识别进程中检查
- 热词更新采用文件监控机制，支持动态重载

### 调试和测试
- Sherpa-ONNX C API 测试: `SherpaAPITest.swift`
- 集成测试: `integration_test.swift` 
- 项目验证: `project_validation.sh`

## 常见问题解决

1. **macOS 权限问题**: 确保授予麦克风和辅助功能权限
2. **模型加载失败**: 检查 models 目录和模型文件完整性
3. **键盘监听失效**: macOS 下尝试使用 sudo 或更换快捷键
4. **WebSocket 连接问题**: 检查防火墙和端口占用

---

# 🚀 CapsWriter-mac 架构优化实施计划

## 📋 项目优化概述

基于对原 CapsWriter 项目和当前 macOS 应用的深入分析，制定以下分阶段的架构优化实施计划。目标是在保持 Swift + Sherpa-ONNX 技术栈的基础上，提升代码质量、功能完整度和用户体验。

## 🎯 第一阶段：核心架构重构 (Week 1-2)

### ✅ 任务 1.1: 配置管理系统
**文件**: `CapsWriter-mac/Sources/Configuration/ConfigurationManager.swift`
```swift
// 实现统一的配置管理
// 支持 UserDefaults 持久化
// 支持运行时动态更新
// 替换所有硬编码配置项
```

### ✅ 任务 1.2: 状态管理分层重构 **[已完成]**
**文件**: 
- `CapsWriter-mac/Sources/States/AudioState.swift`
- `CapsWriter-mac/Sources/States/RecognitionState.swift` 
- `CapsWriter-mac/Sources/States/AppState.swift`
```swift
// ✅ 拆分 RecordingState 为多个专门状态类
// ✅ 按功能域划分状态管理
// ✅ 减少单一类的职责过重问题
// Git: 1da784e feat(state): 完成状态管理分层重构并集成到 Xcode 项目
```

### ✅ 任务 1.3: 错误处理机制 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Core/ErrorHandler.swift`
```swift
// ✅ 统一错误处理和恢复机制
// ✅ 用户友好的错误信息
// ✅ 错误分类和自动恢复
// Git: cfedd5d feat(core): 实现统一错误处理机制
```

### ✅ 任务 1.4: 事件驱动架构 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Core/EventBus.swift`
```swift
// ✅ 引入事件总线解耦组件
// ✅ 支持异步事件处理
// ✅ 提升系统扩展性
// Git: 093ef03 feat(core): 实现事件驱动架构
```

## 🔧 第二阶段：服务层重构 (Week 3-4)

### ✅ 任务 2.1: 核心业务逻辑层 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Controllers/VoiceInputController.swift`
```swift
// ✅ 创建统一的语音输入控制器
// ✅ 协调各服务完成业务流程
// ✅ 从 AppDelegate 中分离业务逻辑
// Git: 28f8576 fix(controllers): 修复VoiceInputController重大bug并完善实现
```

### ✅ 任务 2.2: 服务协议化和依赖注入 **[已完成]**
**文件**: 
- `CapsWriter-mac/Sources/Protocols/ServiceProtocols.swift`
- `CapsWriter-mac/Sources/Core/DIContainer.swift`
```swift
// ✅ 为所有服务定义协议接口
// ✅ 实现依赖注入容器
// ✅ 支持 Mock 测试和解耦
// Git: 5d5f131 feat(core): 实现服务协议化和依赖注入架构
```

### ✅ 任务 2.3: 热词替换系统 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Services/HotWordService.swift`
```swift
// ✅ 移植原项目热词替换功能
// ✅ 支持中文/英文/规则替换
// ✅ 动态热词重载机制
// Git: f09f02e feat(textprocessing): 完成热词替换系统核心实现
// Git: a03bad5 feat(test): 完成热词替换系统全面测试和验证
```

### ✅ 任务 2.4: 文本后处理服务 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Services/TextProcessingService.swift`
```swift
// ✅ 统一文本后处理管道
// ✅ 集成热词、标点、格式化
// ✅ 可配置的处理链
// Git: 7886643 feat(textprocessing): 实现热词替换系统和文本处理管道
```

## 🎨 第三阶段：功能补齐 (Week 5-6)

### ✅ 任务 3.1: 标点符号处理 **[已完成]**
**文件**: `CapsWriter-mac/Sources/Services/PunctuationService.swift`
```swift
// ✅ 实现标点符号自动添加
// ✅ 可选择基于规则或 AI 模型
// ✅ 与文本处理服务集成
// Git: 80329fb feat(textprocessing): 实现标点符号处理系统
```

### ⏳ 任务 3.2: 文件转录功能 **[待实现]**
**文件**: 
- `CapsWriter-mac/Sources/Services/FileTranscriptionService.swift`
- `CapsWriter-mac/Sources/Views/FileTranscriptionView.swift`
```swift
// ⏳ 实现音视频文件转录
// ⏳ 支持进度显示和批量处理
// ⏳ 结果导出和格式化
// 状态: 只有AppState中的枚举定义，实际功能待开发
// 注意: bd137cc/851c8b8 提交涉及的是实时转录，非文件转录
```

### ⏳ 任务 3.3: 日志系统 **[需要完善]**
**文件**: 
- `CapsWriter-mac/Sources/Services/LoggingService.swift`
- `CapsWriter-mac/Sources/Views/LogView.swift`
```swift
// ⏳ 结构化日志记录
// ⏳ 实时日志显示界面
// ⏳ 日志过滤和导出功能
// 状态: 基础日志功能已存在，需要系统化完善
```

### ⏳ 任务 3.4: 资源管理优化 **[需要完善]**
**文件**: `CapsWriter-mac/Sources/Core/ResourceManager.swift`
```swift
// ⏳ 统一资源生命周期管理
// ⏳ 内存泄漏防护
// ⏳ 服务注册和清理
// 状态: 基础资源管理已实现，需要系统化优化
```

## 🎯 第四阶段：UI 和体验优化 (Week 7-8)

### ✅ 任务 4.1: UI 组件重构
**文件**: 
- `CapsWriter-mac/Sources/Views/Components/`
- `CapsWriter-mac/Sources/Views/Enhanced/`
```swift
// 模块化 UI 组件
// 增强录音指示器
// 改进状态反馈界面
```

### ✅ 任务 4.2: 配置界面
**文件**: `CapsWriter-mac/Sources/Views/SettingsView.swift`
```swift
// 完整的配置管理界面
// 热词编辑和导入导出
// 快捷键自定义
```

### ✅ 任务 4.3: 用户引导和帮助
**文件**: `CapsWriter-mac/Sources/Views/OnboardingView.swift`
```swift
// 首次使用引导
// 权限申请流程优化
// 功能说明和帮助文档
```

## 📊 第五阶段：测试和优化 (Week 9-10)

### ✅ 任务 5.1: 单元测试框架
**文件**: `CapsWriter-macTests/`
```swift
// 为核心服务添加单元测试
// Mock 服务实现
// 测试覆盖率报告
```

### ✅ 任务 5.2: 性能优化
```swift
// 内存使用优化
// 音频处理性能调优
// 识别延迟优化
```

### ✅ 任务 5.3: 稳定性测试
```swift
// 长时间运行测试
// 边界条件测试
// 异常恢复测试
```

## 📅 实施时间表

| 阶段 | 时间 | 主要交付物 | 验收标准 | 完成状态 |
|------|------|------------|----------|----------|
| 第一阶段 | Week 1-2 | 核心架构重构 | 配置系统可用，状态管理清晰 | ✅ 已完成 |
| 第二阶段 | Week 3-4 | 服务层重构 | 热词功能恢复，业务逻辑分离 | ✅ 已完成 |
| 第三阶段 | Week 5-6 | 功能补齐 | 标点处理，文件转录可用 | 🔄 60% 完成 |
| 第四阶段 | Week 7-8 | UI 体验优化 | 用户界面完善，配置便捷 | ⏳ 进行中 |
| 第五阶段 | Week 9-10 | 测试和优化 | 性能稳定，测试覆盖率 >80% | ⏳ 计划中 |

## 🔍 关键里程碑

### 🎯 里程碑 1 (Week 2): 架构基础完成 **[✅ 已完成]**
- ✅ 配置管理系统可用 **[已完成]**
  - 创建 ConfigurationManager.swift 统一配置管理
  - 6个配置分类覆盖所有硬编码项 
  - 集成 UserDefaults 持久化和响应式更新
  - 所有服务已重构使用配置管理器
- ✅ 状态管理分层清晰 **[已完成]**
- ✅ 错误处理统一 **[已完成]**

### 🎯 里程碑 2 (Week 4): 核心功能恢复 **[✅ 已完成]**
- ✅ 热词替换功能完整
- ✅ 业务逻辑从 AppDelegate 分离
- ✅ 服务间解耦完成

### 🎯 里程碑 3 (Week 6): 功能对等 **[🔄 60% 完成]**
- ✅ 标点符号处理可用
- ⏳ 文件转录功能完整 **[待实现]**
- ⏳ 日志系统完善 **[需要优化]**

### 🎯 里程碑 4 (Week 8): 用户体验完善 **[⏳ 进行中]**
- ⏳ UI 界面美观易用 **[基础完成，需要优化]**
- ⏳ 配置管理便捷 **[基础完成，需要界面]**
- ⏳ 用户引导完整 **[待开发]**

### 🎯 里程碑 5 (Week 10): 生产就绪 **[⏳ 计划中]**
- ⏳ 测试覆盖率 >80% **[待开发]**
- ⏳ 性能指标达标 **[待验证]**
- ⏳ 稳定性验证通过 **[待测试]**

## ⚠️ 风险控制

### 🚨 技术风险
- **Sherpa-ONNX 集成复杂度**: 预留额外测试时间
- **权限管理变更**: 保持向后兼容性
- **性能回归**: 建立基准测试

### 🚨 进度风险
- **需求变更**: 采用敏捷开发，允许调整
- **技术难点**: 预留 20% 时间缓冲
- **依赖阻塞**: 关键路径优先开发

## 📋 验收标准

### ✅ 功能完整性
- [ ] 支持实时语音输入
- [ ] 支持文件转录
- [ ] 热词替换功能完整
- [ ] 标点符号自动添加
- [ ] 配置管理便捷

### ✅ 性能指标
- [ ] 音频处理延迟 < 100ms
- [ ] 识别响应时间 < 500ms  
- [ ] 内存使用 < 200MB
- [ ] CPU 使用率 < 30%

### ✅ 稳定性要求
- [ ] 连续运行 24 小时无崩溃
- [ ] 异常恢复机制完善
- [ ] 内存泄漏检查通过

### ✅ 用户体验
- [ ] 界面响应流畅
- [ ] 权限申请流程清晰
- [ ] 错误提示友好
- [ ] 配置操作直观

## 🎯 成功指标

优化完成后，预期达成以下指标：

- **代码可维护性提升 60%** - 模块清晰，职责明确
- **功能完整度提升 80%** - 对标原项目功能
- **用户体验提升 40%** - 界面友好，操作便捷  
- **开发效率提升 50%** - 架构清晰，扩展容易
- **系统稳定性提升 70%** - 错误处理完善，资源管理优化

---

## 📝 开发规范

### 代码规范
- 遵循 Swift API Design Guidelines
- 使用 SwiftLint 进行代码检查
- 保持一致的命名约定
- 添加必要的文档注释

### Git 提交规范
- 使用 Conventional Commits 格式
- 每个功能模块独立提交
- 提交信息包含模块名前缀
- 及时更新 .gitignore

### 测试规范
- 核心业务逻辑必须有单元测试
- 集成测试覆盖主要流程
- 性能测试验证关键指标
- 用户体验测试确保易用性