# ErrorHandler 集成指南

## 概述

ErrorHandler 是 CapsWriter-mac 项目的统一错误处理系统，提供错误收集、分类、恢复和用户通知功能。本文档说明如何将 ErrorHandler 集成到现有代码中。

## 核心特性

### 🎯 错误分类和严重程度
- **低 (Low)**: 可忽略的错误，不影响核心功能
- **中 (Medium)**: 部分功能受影响，可降级处理  
- **高 (High)**: 核心功能受影响，需要用户处理
- **严重 (Critical)**: 应用无法正常运行

### 🔄 自动恢复策略
- **重试 (Retry)**: 自动重试失败的操作
- **降级 (Fallback)**: 切换到备用方案
- **重启 (Restart)**: 重启相关服务
- **用户操作 (UserAction)**: 需要用户干预

### 📊 错误统计和监控
- 实时错误统计
- 组件级错误分析
- 错误解决率追踪
- 平均解决时间计算

## 快速集成

### 1. 应用启动时初始化

```swift
// 在 AppDelegate 或 CapsWriterApp 中
func applicationDidFinishLaunching() {
    // 初始化错误处理系统
    ErrorHandlerIntegration.integrateWithStates()
    ErrorHandlerIntegration.setupErrorRecoveryHandlers()
    
    print("✅ 错误处理系统已启动")
}
```

### 2. 在服务初始化中使用

```swift
class AudioCaptureService {
    func initialize() {
        do {
            try setupAudioEngine()
        } catch {
            ErrorHandler.shared.reportServiceError(
                "AudioCaptureService",
                message: "音频引擎初始化失败: \(error.localizedDescription)"
            )
        }
    }
}
```

### 3. 权限检查集成

```swift
func checkMicrophonePermission() {
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        if !granted {
            ErrorHandler.shared.reportPermissionError(
                "麦克风权限",
                message: "用户拒绝了麦克风访问权限"
            )
        }
    }
}
```

### 4. 模型加载错误处理

```swift
func loadASRModel() {
    guard FileManager.default.fileExists(atPath: modelPath) else {
        ErrorHandler.shared.reportModelError(
            "Paraformer模型",
            message: "模型文件不存在: \(modelPath)"
        )
        return
    }
    
    // 模型加载逻辑...
}
```

## 详细集成步骤

### 步骤 1: 添加错误处理到现有服务

#### SherpaASRService 集成示例

```swift
class SherpaASRService {
    func initialize() {
        do {
            try setupRecognizer()
            print("✅ ASR 服务初始化成功")
        } catch {
            ErrorHandler.shared.reportServiceError(
                "SherpaASRService",
                message: "ASR 服务初始化失败: \(error.localizedDescription)"
            )
        }
    }
    
    func startRecognition() {
        guard isInitialized else {
            ErrorHandler.shared.reportUnknownError(
                "SherpaASRService",
                operation: "开始识别",
                message: "服务未初始化"
            )
            return
        }
        
        // 识别逻辑...
    }
}
```

#### KeyboardMonitor 集成示例

```swift
class KeyboardMonitor {
    func startMonitoring() {
        guard checkAccessibilityPermission() else {
            ErrorHandler.shared.reportPermissionError(
                "辅助功能权限",
                message: "需要辅助功能权限才能监听键盘事件"
            )
            return
        }
        
        // 监听逻辑...
    }
    
    func handleMonitoringError(_ error: Error) {
        ErrorHandler.shared.reportUnknownError(
            "KeyboardMonitor",
            operation: "键盘监听",
            message: error.localizedDescription
        )
    }
}
```

### 步骤 2: 设置错误恢复处理

#### 监听错误恢复通知

```swift
class ServiceCoordinator {
    init() {
        setupErrorRecoveryHandlers()
    }
    
    private func setupErrorRecoveryHandlers() {
        // 重试处理
        NotificationCenter.default.addObserver(
            forName: .errorRetryRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRetryRequest(notification)
        }
        
        // 重启处理
        NotificationCenter.default.addObserver(
            forName: .errorRestartRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRestartRequest(notification)
        }
    }
    
    private func handleRetryRequest(_ notification: Notification) {
        guard let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord else {
            return
        }
        
        switch record.context.component {
        case "SherpaASRService":
            restartASRService()
        case "AudioCaptureService":
            restartAudioService()
        case "ConfigurationManager":
            reloadConfiguration()
        default:
            print("未知组件重试请求: \(record.context.component)")
        }
    }
}
```

### 步骤 3: UI 集成

#### 错误状态显示

```swift
struct ErrorStatusView: View {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: errorIcon)
                    .foregroundColor(errorColor)
                Text("系统状态")
                    .font(.headline)
                Spacer()
            }
            
            Text(errorHandler.errorSummary)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let highestError = errorHandler.currentHighestSeverityError {
                Text("最新问题: \(highestError.error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var errorIcon: String {
        if errorHandler.activeErrors.isEmpty {
            return "checkmark.circle.fill"
        } else if errorHandler.currentHighestSeverityError?.severity == .critical {
            return "exclamationmark.triangle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }
    
    private var errorColor: Color {
        if errorHandler.activeErrors.isEmpty {
            return .green
        } else if errorHandler.currentHighestSeverityError?.severity == .critical {
            return .red
        } else {
            return .orange
        }
    }
}
```

#### 错误详情对话框

```swift
struct ErrorDetailSheet: View {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("活跃错误") {
                    ForEach(errorHandler.activeErrors.filter { !$0.isResolved }) { record in
                        ErrorRowView(record: record)
                    }
                }
                
                Section("统计信息") {
                    ErrorStatisticsView()
                }
            }
            .navigationTitle("错误详情")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct ErrorRowView: View {
    let record: ErrorHandler.ErrorRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.error.localizedDescription)
                    .font(.headline)
                Spacer()
                Text(record.severity.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(4)
            }
            
            Text("\(record.context.component) • \(record.context.operation)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(record.formattedTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private var severityColor: Color {
        switch record.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}
```

### 步骤 4: 配置错误阈值和行为

```swift
extension ErrorHandler {
    /// 配置错误处理行为
    func configureErrorBehavior() {
        // 可以在这里添加配置相关的设置
        // 例如：错误通知阈值、重试次数限制等
    }
}
```

## 最佳实践

### 1. 错误报告时机
- **立即报告**: 服务初始化失败、权限被拒绝
- **延迟报告**: 网络超时、临时资源不可用
- **批量报告**: 配置验证错误

### 2. 错误上下文信息
```swift
// 好的例子：提供详细上下文
ErrorHandler.shared.reportError(
    .modelLoadFailed("文件读取失败"),
    context: ErrorHandler.ErrorContext(
        component: "SherpaASRService",
        operation: "加载Paraformer模型",
        userInfo: [
            "modelPath": modelPath,
            "fileSize": fileSize,
            "availableMemory": availableMemory
        ]
    )
)

// 避免：上下文信息不足
ErrorHandler.shared.reportError(.unknownError("出错了"))
```

### 3. 错误恢复策略选择
- **权限错误**: 使用 `userAction` 策略
- **网络错误**: 使用 `retry` 策略
- **配置错误**: 使用 `fallback` 策略
- **服务崩溃**: 使用 `restart` 策略

### 4. 错误解决标记
```swift
// 在问题真正解决后标记
if serviceIsWorkingNormally() {
    ErrorHandler.shared.markErrorResolved(errorId)
}
```

## 测试错误处理

### 单元测试示例

```swift
class ErrorHandlerTests: XCTestCase {
    var errorHandler: ErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler()
    }
    
    func testErrorReporting() {
        let expectation = XCTestExpectation(description: "错误报告")
        
        NotificationCenter.default.addObserver(
            forName: .errorDidOccur,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        errorHandler.reportConfigurationError("测试错误")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(errorHandler.activeErrors.count, 1)
    }
    
    func testErrorResolution() {
        errorHandler.reportConfigurationError("测试错误")
        let errorId = errorHandler.activeErrors.first!.id
        
        errorHandler.markErrorResolved(errorId)
        
        XCTAssertTrue(errorHandler.activeErrors.first!.isResolved)
    }
}
```

## 性能考虑

1. **异步处理**: 错误处理在后台队列中进行
2. **内存限制**: 历史记录限制在 500 条以内
3. **定时器管理**: 自动清理无效的重试定时器
4. **线程安全**: 使用并发队列和屏障保证线程安全

## 故障排除

### 常见问题

1. **错误未被捕获**
   - 检查是否正确调用 `reportError`
   - 确认错误处理器已初始化

2. **恢复策略不生效**
   - 检查是否设置了错误恢复处理器
   - 确认通知监听器正确注册

3. **UI 未更新**
   - 确保在主线程更新 UI
   - 检查 `@ObservedObject` 绑定是否正确

### 调试工具

```swift
// 打印错误处理器调试信息
print(ErrorHandler.shared.debugDescription)

// 查看特定组件的错误统计
let stats = ErrorHandler.shared.getErrorStatistics(for: "ASR服务")
print("ASR服务错误统计: \(stats)")
```

## 总结

ErrorHandler 提供了完整的错误处理解决方案，通过正确集成可以显著提升应用的稳定性和用户体验。关键是：

1. **及时报告**: 在错误发生时立即报告
2. **提供上下文**: 包含足够的调试信息
3. **选择合适的恢复策略**: 根据错误类型选择最佳恢复方案
4. **监控和统计**: 持续监控错误趋势
5. **用户友好**: 提供清晰的错误信息和解决方案

通过遵循本指南，可以将 ErrorHandler 无缝集成到 CapsWriter-mac 项目中，构建更加稳定和可靠的语音输入应用。