# 键盘监听器设置指南

## 功能说明

CapsWriter-mac 应用现在包含了一个全局键盘监听器 `KeyboardMonitor`，可以监听右 Shift 键的按下和释放事件，用于语音识别功能的触发。

## 文件结构

```
CapsWriter-mac/
├── CapsWriter-mac/
│   ├── KeyboardMonitor.swift          # 键盘监听器实现
│   ├── AppDelegate.swift              # 应用委托，启动监听器
│   ├── StatusBarController.swift     # 菜单栏控制器
│   ├── ContentView.swift             # 主界面
│   └── CapsWriterApp.swift           # 应用入口
```

## 核心功能

### 1. KeyboardMonitor 类

位于 `KeyboardMonitor.swift` 文件中，主要功能：

- **全局键盘监听**: 使用 `CGEventTapCreate` 监听系统级键盘事件
- **右 Shift 键识别**: 键码为 60，区分左右 Shift 键
- **事件处理**: 处理 `kCGEventKeyDown` 和 `kCGEventKeyUp` 事件
- **回调机制**: 提供 `startRecordingCallback` 和 `stopRecordingCallback`
- **后台运行**: 在独立线程中运行 `CFRunLoopRun()` 保持监听活跃

### 2. 集成方式

在 `AppDelegate.swift` 中：
- 在 `applicationDidFinishLaunching` 中初始化并启动监听器
- 在 `applicationWillTerminate` 中清理监听器资源
- 提供 `startRecording()` 和 `stopRecording()` 回调函数

## 使用方法

### 1. 启动监听

应用启动后，键盘监听器会自动启动。控制台会显示：
```
✅ 键盘监听器已启动
📝 按住右 Shift 键开始录音，释放结束录音
```

### 2. 使用快捷键

- **按下右 Shift 键**: 开始语音识别（控制台显示 "🎤 开始识别"）
- **释放右 Shift 键**: 结束语音识别（控制台显示 "⏹️ 结束识别"）

## 权限设置

### 重要提醒

**此功能需要辅助功能权限（Accessibility Permission）**

### 设置步骤

1. **打开系统设置**
   - 点击苹果菜单 → 系统设置

2. **导航到隐私与安全性**
   - 左侧边栏选择 "隐私与安全性"

3. **找到辅助功能设置**
   - 在右侧面板中找到 "辅助功能"
   - 点击进入

4. **添加 CapsWriter-mac**
   - 点击 "+" 按钮添加应用
   - 选择 CapsWriter-mac 应用
   - 或者在应用列表中找到 CapsWriter-mac 并勾选

5. **确认权限**
   - 确保 CapsWriter-mac 旁边的开关是打开状态

### 自动请求权限

如果应用没有权限，`KeyboardMonitor` 会：
- 自动检测权限状态
- 显示权限提示对话框
- 在控制台输出设置路径说明

## 技术细节

### 右 Shift 键识别

```swift
private let rightShiftKeyCode: CGKeyCode = 60
```

### 事件处理流程

1. **事件捕获**: `CGEventTapCreate` 捕获系统键盘事件
2. **键码过滤**: 只处理右 Shift 键（键码 60）
3. **状态跟踪**: 跟踪按键状态，防止重复触发
4. **回调执行**: 在主线程执行回调函数
5. **事件传递**: 继续传递事件，不影响其他应用

### 线程安全

- 事件监听在后台线程运行
- 回调函数在主线程执行
- 使用 `weak self` 防止循环引用

## 调试功能

### 控制台输出

- `✅ 键盘监听器已启动`
- `🎤 开始识别`
- `⏹️ 结束识别`
- `⚠️ 请在系统设置中启用辅助功能权限`

### 权限检查

```swift
// 检查权限
KeyboardMonitor.checkAccessibilityPermission()

// 请求权限
KeyboardMonitor.requestAccessibilityPermission()
```

## 扩展接口

### 添加语音识别功能

在 `AppDelegate.swift` 的回调函数中添加具体实现：

```swift
private func startRecording() {
    print("🎤 开始语音识别...")
    // TODO: 添加语音识别开始逻辑
    // speechRecognizer.startRecording()
}

private func stopRecording() {
    print("⏹️ 结束语音识别...")
    // TODO: 添加语音识别结束逻辑
    // speechRecognizer.stopRecording()
}
```

### 自定义回调

```swift
keyboardMonitor?.setCallbacks(
    startRecording: {
        // 自定义开始录音逻辑
    },
    stopRecording: {
        // 自定义结束录音逻辑
    }
)
```

## 故障排除

### 1. 权限问题

**问题**: 控制台显示权限警告
**解决**: 按照上述步骤在系统设置中启用辅助功能权限

### 2. 监听器无响应

**问题**: 按右 Shift 键无反应
**解决**: 
- 检查权限是否正确设置
- 重启应用
- 检查控制台是否有错误信息

### 3. 应用崩溃

**问题**: 启动后应用崩溃
**解决**:
- 检查 Xcode 构建错误
- 确保所有文件都正确添加到项目中
- 检查代码签名和entitlements

## 性能考虑

- 监听器运行在独立线程，不影响主UI
- 只监听右 Shift 键，过滤其他按键事件
- 使用状态跟踪避免重复处理
- 应用退出时自动清理资源

## 安全性

- 只监听键盘事件，不记录具体按键内容
- 不存储或传输任何键盘数据
- 仅在用户主动按下右 Shift 时触发功能
- 遵循 macOS 隐私和安全规范