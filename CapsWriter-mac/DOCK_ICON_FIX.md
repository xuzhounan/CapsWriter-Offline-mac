# Dock 图标问题修复指南

## 问题诊断

经过排查，发现 Dock 中不显示图标的主要原因是：

1. **缺少实际的图标文件**：`AppIcon.appiconset` 目录中只有 `Contents.json` 配置文件，没有实际的 PNG 图标文件
2. **Bundle Identifier 中的连字符可能导致问题**：已修复为 `com.example.CapsWriterMac`
3. **SwiftUI 窗口样式设置**：已移除可能影响 Dock 显示的 `.windowStyle(.hiddenTitleBar)`

## 已修复的配置

### 1. Info.plist 更新
- ✅ 添加 `CFBundleIconName` = `AppIcon`
- ✅ 设置 `LSUIElement` = `false`
- ✅ 修正 `CFBundleIdentifier` 为 `com.example.CapsWriterMac`

### 2. AppDelegate 优化
- ✅ 确保 `NSApp.setActivationPolicy(.regular)` 优先执行
- ✅ 添加 `NSApp.activate(ignoringOtherApps: true)` 强制激活

### 3. SwiftUI 应用配置
- ✅ 移除 `.windowStyle(.hiddenTitleBar)` 以确保正常 Dock 行为

## 需要手动完成的步骤

### 创建应用图标

在 Xcode 中打开项目，然后：

1. 在 Project Navigator 中找到 `Assets.xcassets`
2. 展开并找到 `AppIcon`
3. 点击 `AppIcon`，你会看到各种尺寸的图标槽位
4. 拖拽对应尺寸的 PNG 图标文件到相应的槽位中

**所需图标尺寸：**
- 16x16 (1x)
- 32x32 (1x 和 2x)
- 128x128 (1x 和 2x)
- 256x256 (1x 和 2x)
- 512x512 (1x 和 2x)

### 临时解决方案

如果暂时没有图标文件，可以：

1. 使用系统默认图标：删除 `CFBundleIconName` 配置
2. 或者创建简单的占位图标：使用任何图像编辑软件创建上述尺寸的图标

## 测试步骤

1. 清理项目：Product → Clean Build Folder
2. 重新构建：Product → Build
3. 运行应用：Product → Run
4. 检查 Dock 中是否显示图标
5. 测试 Cmd+Tab 切换器中是否显示

## 预期结果

修复后，应用应该：
- ✅ 在 Dock 中显示图标
- ✅ 出现在 Cmd+Tab 应用切换器中
- ✅ 支持 Dock 图标点击激活应用
- ✅ 菜单栏图标正常工作

## 如果仍然有问题

1. 检查系统日志：Console.app 中查看相关错误
2. 重启 Dock：`killall Dock` 命令
3. 检查 Bundle Identifier 是否唯一
4. 确认没有其他同名应用在运行