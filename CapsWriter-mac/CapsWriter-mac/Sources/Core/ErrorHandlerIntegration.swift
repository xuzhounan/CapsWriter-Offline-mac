import Foundation

/// ErrorHandler 集成辅助工具
/// 提供便捷的错误处理集成方法
class ErrorHandlerIntegration {
    
    /// 为现有状态管理类集成错误处理
    static func integrateWithStates() {
        setupAppStateIntegration()
        setupAudioStateIntegration()
        setupRecognitionStateIntegration()
    }
    
    /// 集成 AppState 错误处理
    private static func setupAppStateIntegration() {
        NotificationCenter.default.addObserver(
            forName: .appErrorDidOccur,
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?["error"] as? AppError {
                ErrorHandler.shared.reportError(
                    error,
                    context: ErrorHandler.ErrorContext(
                        component: "AppState",
                        operation: "状态管理"
                    )
                )
            }
        }
        
        print("✅ ErrorHandlerIntegration: AppState 集成完成")
    }
    
    /// 集成 AudioState 错误处理
    private static func setupAudioStateIntegration() {
        NotificationCenter.default.addObserver(
            forName: .microphonePermissionDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let hasPermission = notification.userInfo?["hasPermission"] as? Bool,
               !hasPermission {
                ErrorHandler.shared.reportPermissionError(
                    "麦克风权限",
                    message: "用户拒绝了麦克风权限访问"
                )
            }
        }
        
        print("✅ ErrorHandlerIntegration: AudioState 集成完成")
    }
    
    /// 集成 RecognitionState 错误处理
    private static func setupRecognitionStateIntegration() {
        NotificationCenter.default.addObserver(
            forName: .asrServiceStatusDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let isRunning = notification.userInfo?["isRunning"] as? Bool,
               !isRunning {
                ErrorHandler.shared.reportServiceError(
                    "ASR服务",
                    message: "语音识别服务意外停止"
                )
            }
        }
        
        print("✅ ErrorHandlerIntegration: RecognitionState 集成完成")
    }
    
    /// 设置错误恢复处理器
    static func setupErrorRecoveryHandlers() {
        setupRetryHandlers()
        setupFallbackHandlers()
        setupRestartHandlers()
    }
    
    /// 设置重试处理器
    private static func setupRetryHandlers() {
        NotificationCenter.default.addObserver(
            forName: .errorRetryRequested,
            object: nil,
            queue: .main
        ) { notification in
            guard let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord else {
                return
            }
            
            handleRetryRequest(for: record)
        }
        
        print("✅ ErrorHandlerIntegration: 重试处理器已设置")
    }
    
    /// 设置降级处理器
    private static func setupFallbackHandlers() {
        NotificationCenter.default.addObserver(
            forName: .errorFallbackRequested,
            object: nil,
            queue: .main
        ) { notification in
            guard let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord else {
                return
            }
            
            handleFallbackRequest(for: record)
        }
        
        print("✅ ErrorHandlerIntegration: 降级处理器已设置")
    }
    
    /// 设置重启处理器
    private static func setupRestartHandlers() {
        NotificationCenter.default.addObserver(
            forName: .errorRestartRequested,
            object: nil,
            queue: .main
        ) { notification in
            guard let record = notification.userInfo?["record"] as? ErrorHandler.ErrorRecord else {
                return
            }
            
            handleRestartRequest(for: record)
        }
        
        print("✅ ErrorHandlerIntegration: 重启处理器已设置")
    }
    
    // MARK: - Recovery Handlers
    
    /// 处理重试请求
    private static func handleRetryRequest(for record: ErrorHandler.ErrorRecord) {
        let component = record.context.component
        let operation = record.context.operation
        
        print("🔄 ErrorHandlerIntegration: 处理重试请求 - \(component).\(operation)")
        
        switch component {
        case "Configuration":
            retryConfigurationOperation()
        case "ASR服务":
            retryASRService()
        case "Model":
            retryModelLoading()
        default:
            print("⚠️ ErrorHandlerIntegration: 未知组件重试请求 - \(component)")
        }
    }
    
    /// 处理降级请求
    private static func handleFallbackRequest(for record: ErrorHandler.ErrorRecord) {
        let component = record.context.component
        
        print("⚠️ ErrorHandlerIntegration: 处理降级请求 - \(component)")
        
        switch component {
        case "Configuration":
            ConfigurationManager.shared.resetToDefaults()
        case "Model":
            print("使用基础模式运行")
        default:
            print("⚠️ ErrorHandlerIntegration: 未知组件降级请求 - \(component)")
        }
        
        ErrorHandler.shared.markErrorResolved(record.id)
    }
    
    /// 处理重启请求
    private static func handleRestartRequest(for record: ErrorHandler.ErrorRecord) {
        let component = record.context.component
        
        print("🔄 ErrorHandlerIntegration: 处理重启请求 - \(component)")
        
        switch component {
        case "ASR服务":
            restartASRService()
        case "AudioCaptureService":
            restartAudioService()
        default:
            print("⚠️ ErrorHandlerIntegration: 未知组件重启请求 - \(component)")
        }
    }
    
    // MARK: - Specific Recovery Operations
    
    private static func retryConfigurationOperation() {
        DispatchQueue.global(qos: .utility).async {
            ConfigurationManager.shared.loadConfiguration()
            
            DispatchQueue.main.async {
                if ConfigurationManager.shared.isConfigurationValid {
                    print("✅ ErrorHandlerIntegration: 配置重试成功")
                } else {
                    print("❌ ErrorHandlerIntegration: 配置重试失败")
                }
            }
        }
    }
    
    private static func retryASRService() {
        NotificationCenter.default.post(
            name: Notification.Name("restartASRService"),
            object: nil
        )
        
        print("🔄 ErrorHandlerIntegration: 已请求 ASR 服务重试")
    }
    
    private static func retryModelLoading() {
        NotificationCenter.default.post(
            name: Notification.Name("reloadModel"),
            object: nil
        )
        
        print("🔄 ErrorHandlerIntegration: 已请求模型重新加载")
    }
    
    private static func restartASRService() {
        NotificationCenter.default.post(
            name: Notification.Name("fullRestartASRService"),
            object: nil
        )
        
        print("🔄 ErrorHandlerIntegration: 已请求完全重启 ASR 服务")
    }
    
    private static func restartAudioService() {
        NotificationCenter.default.post(
            name: Notification.Name("restartAudioService"),
            object: nil
        )
        
        print("🔄 ErrorHandlerIntegration: 已请求重启音频服务")
    }
}

// MARK: - ConfigurationManager Extension for Error Handling

extension ConfigurationManager {
    
    /// 重置为默认配置（降级处理）
    func resetToDefaults() {
        print("⚠️ ConfigurationManager: 重置为默认配置")
        
        audioConfig = AudioConfiguration()
        recognitionConfig = RecognitionConfiguration()
        keyboardConfig = KeyboardConfiguration()
        uiConfig = UIConfiguration()
        systemConfig = SystemConfiguration()
        loggingConfig = LoggingConfiguration()
        
        saveConfiguration()
        
        print("✅ ConfigurationManager: 默认配置已应用")
    }
    
    /// 验证配置有效性
    var isConfigurationValid: Bool {
        return !audioConfig.inputDeviceId.isEmpty &&
               recognitionConfig.sampleRate > 0 &&
               !systemConfig.appVersion.isEmpty
    }
}