import Foundation
import AVFoundation
import Combine

// MARK: - Service Protocols
// Note: Basic service protocols are defined in their respective service files
// This file contains additional protocols for DI, error handling, and architecture

// MARK: - Error Handling Protocol

/// 错误处理服务协议
protocol ErrorHandlerProtocol: AnyObject {
    func handle(_ error: Error, context: String)
    func handleVoiceInputError(_ error: VoiceInputController.VoiceInputError)
    func reportError(_ error: Error, userInfo: [String: Any]?)
}

// MARK: - Logging Protocol
// LoggingServiceProtocol 和 LogLevel 枚举已移到 LoggingService.swift 中定义

// MARK: - Service Status Protocol

/// 服务状态协议
protocol ServiceStatusProtocol {
    var isInitialized: Bool { get }
    var isRunning: Bool { get }
    var lastError: Error? { get }
    var statusDescription: String { get }
}

// MARK: - Service Lifecycle Protocol

/// 服务生命周期管理协议
protocol ServiceLifecycleProtocol: AnyObject {
    func initialize() throws
    func start() throws
    func stop()
    func cleanup()
}

// MARK: - Dependency Injection (see DIContainer.swift for implementation)

// MARK: - Mock Support Protocols

// MARK: - Service Factory Protocol (基于现有协议，不重新定义)

/// 服务工厂协议 - 引用现有的协议
protocol ServiceFactoryProtocol {
    // 引用各服务文件中已定义的协议
    // AudioCaptureServiceProtocol 定义在 AudioCaptureService.swift
    // SpeechRecognitionServiceProtocol 定义在 SherpaASRService.swift  
    // TextInputServiceProtocol 定义在 TextInputService.swift
    // KeyboardMonitorProtocol 定义在 KeyboardMonitor.swift
    // ConfigurationManagerProtocol 定义在 ConfigurationManager.swift
}

// MARK: - Hot Word Service Protocol (引用)

// HotWordServiceProtocol 和 TextProcessingServiceProtocol 在各自的服务文件中定义
// 这里仅做协议引用声明，避免循环依赖

// MARK: - Permission Monitor Service Protocol

/// 权限监控服务协议 - 引用于 PermissionMonitorService.swift
/// 提供响应式权限状态管理，替代轮询机制
// PermissionMonitorServiceProtocol 在 PermissionMonitorService.swift 中定义

// MARK: - Event Bus Protocol

/// 事件总线协议 (为后续扩展预留)
protocol EventBusProtocol: AnyObject {
    func publish<T>(_ event: T)
    func subscribe<T>(_ eventType: T.Type, handler: @escaping (T) -> Void)
    func unsubscribe<T>(_ eventType: T.Type)
}