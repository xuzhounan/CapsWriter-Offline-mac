# CapsWriter-mac

CapsWriter-mac 是一个基于 SwiftUI 的 macOS 应用，为 CapsWriter 音频转录工具提供原生的 macOS 用户界面。

## 功能特性

- ✅ **主窗体界面**：显示欢迎信息和功能介绍
- ✅ **Dock 图标**：正常显示在 macOS Dock 中
- ✅ **菜单栏图标**：系统菜单栏中的快捷访问
- ✅ **现代 UI**：使用 SwiftUI 构建的原生 macOS 体验

## 系统要求

- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本（开发构建）

## 功能说明

### 主窗体
- 启动时显示欢迎界面
- 显示应用功能介绍
- 可通过 Dock 图标或菜单栏重新打开

### 菜单栏功能
- **打开主窗口**：点击后显示或激活主窗体
- **退出 CapsWriter**：完全退出应用程序

### 应用生命周期
- 关闭主窗口时应用继续在后台运行
- 支持在 Dock 中点击重新打开窗口
- 菜单栏图标提供持久化访问

## 开发构建

1. 使用 Xcode 打开 `CapsWriter-mac.xcodeproj`
2. 选择目标设备（Mac）
3. 点击 Run 按钮或使用 Cmd+R

## 项目结构

```
CapsWriter-mac/
├── CapsWriter-mac.xcodeproj/          # Xcode 项目文件
├── CapsWriter-mac/
│   ├── CapsWriterApp.swift            # 应用入口
│   ├── AppDelegate.swift              # 应用委托
│   ├── ContentView.swift              # 主窗体视图
│   ├── MenuBarController.swift        # 菜单栏控制器
│   ├── Assets.xcassets/               # 应用资源
│   ├── Info.plist                     # 应用信息
│   └── CapsWriter-mac.entitlements    # 应用权限
└── README.md                          # 说明文档
```

## 技术栈

- **SwiftUI**：用户界面框架
- **AppKit**：macOS 原生功能（菜单栏集成）
- **Foundation**：基础系统服务

## 许可证

本项目是 CapsWriter 项目的一部分。