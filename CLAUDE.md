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