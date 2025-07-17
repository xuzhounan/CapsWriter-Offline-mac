# Xcode 文件添加指南

## 需要添加的文件

已创建的三个状态管理文件位于：
- `/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac/AudioState.swift`
- `/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac/RecognitionState.swift`
- `/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac/AppState.swift`

## 手动添加到 Xcode 项目的步骤

### 方法1：拖拽添加
1. 打开 Xcode 项目：`CapsWriter-mac.xcodeproj`
2. 在 Project Navigator 中找到 `CapsWriter-mac` 目标
3. 创建一个新的组（文件夹）叫 `States`：
   - 右键点击 `CapsWriter-mac` 组
   - 选择 "New Group"
   - 命名为 "States"
4. 从 Finder 中拖拽三个 `.swift` 文件到 `States` 组中
5. 确保在弹出的对话框中：
   - 勾选 "Add to target: CapsWriter-mac"
   - 选择 "Copy items if needed"

### 方法2：使用 Add Files 菜单
1. 在 Xcode 中右键点击 `CapsWriter-mac` 组
2. 选择 "Add Files to 'CapsWriter-mac'"
3. 导航到文件位置并选择三个 `.swift` 文件
4. 确保目标包含 `CapsWriter-mac`
5. 点击 "Add"

### 方法3：使用命令行（如果上述方法失败）
```bash
# 进入项目目录
cd /Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac

# 使用 xcodebuild 添加文件（需要配置）
# 或者直接修改 .xcodeproj 文件（不推荐）
```

## 验证文件已正确添加

1. 在 Project Navigator 中确认文件显示为蓝色（而非红色）
2. 选择文件并确认在 File Inspector 中显示正确的目标成员资格
3. 尝试编译项目（⌘+B）确认没有编译错误

## 文件说明

### AudioState.swift
- 管理音频录制状态
- 包含录音状态、音量级别、设备状态等
- 提供录音开始/停止、音量更新等方法

### RecognitionState.swift  
- 管理语音识别状态
- 包含识别状态、当前文本、历史记录等
- 提供识别开始/完成、文本更新等方法

### AppState.swift
- 管理应用程序整体状态
- 包含应用状态、权限状态、模式切换等
- 提供统一的应用状态管理

## 编译测试

文件添加后，可以运行以下命令测试编译：

```bash
cd /Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac
swift test_states.swift
```

如果编译成功，应该会看到状态测试的输出。

## 后续步骤

1. 文件添加到项目后，需要在相关的 SwiftUI 视图中导入和使用这些状态类
2. 逐步从原有的 `RecordingState` 迁移到新的分层状态管理
3. 确保所有引用都正确更新