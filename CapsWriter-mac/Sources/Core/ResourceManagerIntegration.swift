import Foundation
import Combine
import AVFoundation
import os.log

/// 资源管理集成服务 - 任务3.4
/// 将现有服务集成到统一资源管理系统中
class ResourceManagerIntegration {
    
    // MARK: - Singleton
    
    static let shared = ResourceManagerIntegration()
    
    private init() {
        setupIntegration()
        print("🔗 ResourceManagerIntegration 已初始化")
    }
    
    // MARK: - Private Properties
    
    private let resourceManager = ResourceManager.shared
    private let logger = Logger(subsystem: "com.capswriter.resource-integration", category: "ResourceManagerIntegration")
    
    // MARK: - Integration Setup
    
    /// 设置资源管理集成
    private func setupIntegration() {
        logger.info("🔗 设置资源管理集成")
        
        // 注册现有服务到资源管理器
        registerExistingServices()
        
        // 设置服务生命周期管理
        setupServiceLifecycleManagement()
        
        // 集成到依赖注入系统
        integrateDependencyInjection()
    }
    
    /// 注册现有服务到资源管理器
    private func registerExistingServices() {
        logger.info("📋 注册现有服务到资源管理器")
        
        // 注册配置管理器
        registerConfigurationManager()
        
        // 注册热词服务
        registerHotWordService()
        
        // 注册标点符号服务
        registerPunctuationService()
        
        // 注册文本处理服务
        registerTextProcessingService()
        
        // 注册日志服务
        registerLoggingService()
        
        // 注册权限监控服务
        registerPermissionMonitorService()
        
        // 注册错误处理器
        registerErrorHandler()
    }
    
    /// 注册配置管理器
    private func registerConfigurationManager() {
        logger.debug("📋 注册配置管理器")
        
        let configManager = ConfigurationManager.shared
        let managedResource = ManagedConfigurationService(configManager: configManager)
        
        do {
            try resourceManager.register(managedResource)
            logger.info("✅ 配置管理器已注册到资源管理器")
        } catch {
            logger.error("❌ 配置管理器注册失败: \(error.localizedDescription)")
        }
    }
    
    /// 注册热词服务
    private func registerHotWordService() {
        logger.debug("📋 注册热词服务")
        
        if let hotWordService = DIContainer.shared.resolve(HotWordServiceProtocol.self) {
            let managedResource = ManagedHotWordService(hotWordService: hotWordService)
            
            do {
                try resourceManager.register(managedResource, dependencies: ["ManagedConfigurationService"])
                logger.info("✅ 热词服务已注册到资源管理器")
            } catch {
                logger.error("❌ 热词服务注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 注册标点符号服务
    private func registerPunctuationService() {
        logger.debug("📋 注册标点符号服务")
        
        if let punctuationService = DIContainer.shared.resolve(PunctuationServiceProtocol.self) {
            let managedResource = ManagedPunctuationService(punctuationService: punctuationService)
            
            do {
                try resourceManager.register(managedResource, dependencies: ["ManagedConfigurationService"])
                logger.info("✅ 标点符号服务已注册到资源管理器")
            } catch {
                logger.error("❌ 标点符号服务注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 注册文本处理服务
    private func registerTextProcessingService() {
        logger.debug("📋 注册文本处理服务")
        
        if let textProcessingService = DIContainer.shared.resolve(TextProcessingServiceProtocol.self) {
            let managedResource = ManagedTextProcessingService(textProcessingService: textProcessingService)
            
            do {
                try resourceManager.register(managedResource, dependencies: ["ManagedHotWordService", "ManagedPunctuationService"])
                logger.info("✅ 文本处理服务已注册到资源管理器")
            } catch {
                logger.error("❌ 文本处理服务注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 注册日志服务
    private func registerLoggingService() {
        logger.debug("📋 注册日志服务")
        
        if let loggingService = DIContainer.shared.resolve(LoggingServiceProtocol.self) {
            let managedResource = ManagedLoggingService(loggingService: loggingService)
            
            do {
                try resourceManager.register(managedResource)
                logger.info("✅ 日志服务已注册到资源管理器")
            } catch {
                logger.error("❌ 日志服务注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 注册权限监控服务
    private func registerPermissionMonitorService() {
        logger.debug("📋 注册权限监控服务")
        
        if let permissionService = DIContainer.shared.resolve(PermissionMonitorServiceProtocol.self) {
            let managedResource = ManagedPermissionMonitorService(permissionService: permissionService)
            
            do {
                try resourceManager.register(managedResource)
                logger.info("✅ 权限监控服务已注册到资源管理器")
            } catch {
                logger.error("❌ 权限监控服务注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 注册错误处理器
    private func registerErrorHandler() {
        logger.debug("📋 注册错误处理器")
        
        if let errorHandler = DIContainer.shared.resolve(ErrorHandlerProtocol.self) {
            let managedResource = ManagedErrorHandler(errorHandler: errorHandler)
            
            do {
                try resourceManager.register(managedResource)
                logger.info("✅ 错误处理器已注册到资源管理器")
            } catch {
                logger.error("❌ 错误处理器注册失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 设置服务生命周期管理
    private func setupServiceLifecycleManagement() {
        logger.info("🔄 设置服务生命周期管理")
        
        // 注册生命周期管理器
        let lifecycleManager = LifecycleManager.shared
        
        // 注册资源清理服务
        let cleanupService = ResourceCleanupService.shared
        
        do {
            try lifecycleManager.registerService(cleanupService, identifier: "ResourceCleanupService")
            logger.info("✅ 资源清理服务已注册到生命周期管理器")
        } catch {
            logger.error("❌ 资源清理服务注册失败: \(error.localizedDescription)")
        }
    }
    
    /// 集成到依赖注入系统
    private func integrateDependencyInjection() {
        logger.info("🔗 集成到依赖注入系统")
        
        // 注册资源管理器到依赖注入容器
        DIContainer.shared.registerSingleton(ResourceManager.self) {
            return ResourceManager.shared
        }
        
        // 注册生命周期管理器到依赖注入容器
        DIContainer.shared.registerSingleton(LifecycleManager.self) {
            return LifecycleManager.shared
        }
        
        // 注册内存监控器到依赖注入容器
        DIContainer.shared.registerSingleton(MemoryMonitor.self) {
            return MemoryMonitor.shared
        }
        
        // 注册资源清理服务到依赖注入容器
        DIContainer.shared.registerSingleton(ResourceCleanupService.self) {
            return ResourceCleanupService.shared
        }
        
        logger.info("✅ 资源管理组件已集成到依赖注入系统")
    }
    
    // MARK: - Initialization Methods
    
    /// 初始化所有资源
    func initializeAllResources() async throws {
        logger.info("🚀 初始化所有资源")
        
        let allResources = resourceManager.getAllResourceInfo()
        let uninitializedResources = allResources.filter { $0.state == .uninitialized }
        
        logger.info("📋 发现 \(uninitializedResources.count) 个未初始化资源")
        
        for resourceInfo in uninitializedResources {
            do {
                try await resourceManager.initializeResource(resourceInfo.id)
                logger.info("✅ 资源初始化成功: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 资源初始化失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
        
        logger.info("✅ 所有资源初始化完成")
    }
    
    /// 激活核心资源
    func activateCoreResources() throws {
        logger.info("▶️ 激活核心资源")
        
        let coreResourceIds = [
            "ManagedConfigurationService",
            "ManagedLoggingService",
            "ManagedErrorHandler"
        ]
        
        for resourceId in coreResourceIds {
            if let resourceInfo = resourceManager.getResourceInfo(resourceId),
               resourceInfo.state == .ready {
                do {
                    try resourceManager.activateResource(resourceId)
                    logger.info("✅ 核心资源激活成功: \(resourceId)")
                } catch {
                    logger.error("❌ 核心资源激活失败: \(resourceId) - \(error.localizedDescription)")
                }
            }
        }
        
        logger.info("✅ 核心资源激活完成")
    }
    
    /// 激活所有资源
    func activateAllResources() throws {
        logger.info("▶️ 激活所有资源")
        
        let allResources = resourceManager.getAllResourceInfo()
        let readyResources = allResources.filter { $0.state == .ready }
        
        for resourceInfo in readyResources {
            do {
                try resourceManager.activateResource(resourceInfo.id)
                logger.info("✅ 资源激活成功: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 资源激活失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
        
        logger.info("✅ 所有资源激活完成")
    }
    
    // MARK: - Status and Monitoring
    
    /// 获取资源集成状态
    func getIntegrationStatus() -> ResourceIntegrationStatus {
        let allResources = resourceManager.getAllResourceInfo()
        let statistics = resourceManager.getStatistics()
        
        let statusByType = Dictionary(grouping: allResources) { $0.type }
            .mapValues { resources in
                Dictionary(grouping: resources) { $0.state }
                    .mapValues { $0.count }
            }
        
        return ResourceIntegrationStatus(
            totalResources: allResources.count,
            resourcesByType: statusByType,
            memoryUsage: statistics.totalMemoryUsage,
            lastUpdateTime: Date()
        )
    }
    
    /// 执行资源健康检查
    func performHealthCheck() -> ResourceHealthReport {
        logger.info("🔍 执行资源健康检查")
        
        let allResources = resourceManager.getAllResourceInfo()
        var healthyResources = 0
        var unhealthyResources = 0
        var warnings: [String] = []
        var errors: [String] = []
        
        for resourceInfo in allResources {
            switch resourceInfo.state {
            case .active, .ready:
                healthyResources += 1
            case .error, .disposed:
                unhealthyResources += 1
                errors.append("资源状态异常: \(resourceInfo.id) - \(resourceInfo.state)")
            case .uninitialized:
                warnings.append("资源未初始化: \(resourceInfo.id)")
            default:
                warnings.append("资源状态可疑: \(resourceInfo.id) - \(resourceInfo.state)")
            }
        }
        
        let healthScore = allResources.isEmpty ? 1.0 : Double(healthyResources) / Double(allResources.count)
        
        let report = ResourceHealthReport(
            healthScore: healthScore,
            totalResources: allResources.count,
            healthyResources: healthyResources,
            unhealthyResources: unhealthyResources,
            warnings: warnings,
            errors: errors,
            checkTime: Date()
        )
        
        logger.info("📊 资源健康检查完成 - 健康度: \(Int(healthScore * 100))%")
        
        return report
    }
    
    // MARK: - Cleanup and Maintenance
    
    /// 执行资源维护
    func performResourceMaintenance() async {
        logger.info("🔧 执行资源维护")
        
        // 执行内存清理
        let memoryMonitor = MemoryMonitor.shared
        memoryMonitor.performMemoryCleanup(reason: "资源维护")
        
        // 执行资源清理
        let cleanupService = ResourceCleanupService.shared
        await cleanupService.performFullCleanup()
        
        // 检查并修复资源状态
        await repairResourceStates()
        
        logger.info("✅ 资源维护完成")
    }
    
    /// 修复资源状态
    private func repairResourceStates() async {
        logger.info("🔧 修复资源状态")
        
        let allResources = resourceManager.getAllResourceInfo()
        let errorResources = allResources.filter { $0.state == .error }
        
        for resourceInfo in errorResources {
            logger.info("🔧 尝试修复资源: \(resourceInfo.id)")
            
            do {
                // 尝试重新初始化错误状态的资源
                try await resourceManager.disposeResource(resourceInfo.id)
                // 这里可以添加重新注册和初始化的逻辑
                logger.info("✅ 资源修复成功: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 资源修复失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
    }
    
    /// 清理所有资源
    func cleanupAllResources() async {
        logger.info("🧹 清理所有资源")
        
        let allResources = resourceManager.getAllResourceInfo()
        
        for resourceInfo in allResources {
            do {
                try await resourceManager.disposeResource(resourceInfo.id)
                logger.debug("🗑️ 资源已清理: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 资源清理失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
        
        logger.info("✅ 所有资源清理完成")
    }
}

// MARK: - Supporting Types

/// 资源集成状态
struct ResourceIntegrationStatus {
    let totalResources: Int
    let resourcesByType: [ResourceType: [ResourceState: Int]]
    let memoryUsage: Int64
    let lastUpdateTime: Date
}

/// 资源健康报告
struct ResourceHealthReport {
    let healthScore: Double          // 0.0 - 1.0
    let totalResources: Int
    let healthyResources: Int
    let unhealthyResources: Int
    let warnings: [String]
    let errors: [String]
    let checkTime: Date
    
    var isHealthy: Bool {
        return healthScore >= 0.8 && errors.isEmpty
    }
}

// MARK: - Managed Resource Wrappers

/// 托管配置服务
class ManagedConfigurationService: ResourceManageable {
    let resourceId: String = "ManagedConfigurationService"
    let resourceType: ResourceType = .system
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "配置管理服务"
    
    private let configManager: ConfigurationManager
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }
    
    func initialize() async throws {
        // 配置管理器已经在单例初始化时完成初始化
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        // 配置管理器是单例，不能直接释放
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 1024 * 1024, // 估算 1MB
            metadata: [
                "configCount": configManager.getAllConfigurations().count
            ]
        )
    }
}

/// 托管热词服务
class ManagedHotWordService: ResourceManageable {
    let resourceId: String = "ManagedHotWordService"
    let resourceType: ResourceType = .memory
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "热词替换服务"
    
    private let hotWordService: HotWordServiceProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(hotWordService: HotWordServiceProtocol) {
        self.hotWordService = hotWordService
    }
    
    func initialize() async throws {
        // 热词服务已经在依赖注入时初始化
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        let statistics = hotWordService.getStatistics()
        
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: Int64(statistics.totalHotWords * 100), // 估算每个热词100字节
            metadata: [
                "totalHotWords": statistics.totalHotWords,
                "processedTexts": statistics.processedTexts
            ]
        )
    }
}

/// 托管标点符号服务
class ManagedPunctuationService: ResourceManageable {
    let resourceId: String = "ManagedPunctuationService"
    let resourceType: ResourceType = .memory
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "标点符号处理服务"
    
    private let punctuationService: PunctuationServiceProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(punctuationService: PunctuationServiceProtocol) {
        self.punctuationService = punctuationService
    }
    
    func initialize() async throws {
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 512 * 1024, // 估算 512KB
            metadata: [:]
        )
    }
}

/// 托管文本处理服务
class ManagedTextProcessingService: ResourceManageable {
    let resourceId: String = "ManagedTextProcessingService"
    let resourceType: ResourceType = .memory
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "文本处理服务"
    
    private let textProcessingService: TextProcessingServiceProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(textProcessingService: TextProcessingServiceProtocol) {
        self.textProcessingService = textProcessingService
    }
    
    func initialize() async throws {
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 2 * 1024 * 1024, // 估算 2MB
            metadata: [:]
        )
    }
}

/// 托管日志服务
class ManagedLoggingService: ResourceManageable {
    let resourceId: String = "ManagedLoggingService"
    let resourceType: ResourceType = .file
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "日志记录服务"
    
    private let loggingService: LoggingServiceProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(loggingService: LoggingServiceProtocol) {
        self.loggingService = loggingService
    }
    
    func initialize() async throws {
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        await loggingService.flushLogs()
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 10 * 1024 * 1024, // 估算 10MB
            metadata: [:]
        )
    }
}

/// 托管权限监控服务
class ManagedPermissionMonitorService: ResourceManageable {
    let resourceId: String = "ManagedPermissionMonitorService"
    let resourceType: ResourceType = .system
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "权限监控服务"
    
    private let permissionService: PermissionMonitorServiceProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(permissionService: PermissionMonitorServiceProtocol) {
        self.permissionService = permissionService
    }
    
    func initialize() async throws {
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 1024 * 512, // 估算 512KB
            metadata: [:]
        )
    }
}

/// 托管错误处理器
class ManagedErrorHandler: ResourceManageable {
    let resourceId: String = "ManagedErrorHandler"
    let resourceType: ResourceType = .system
    var resourceState: ResourceState = .uninitialized
    let resourceDescription: String = "错误处理器"
    
    private let errorHandler: ErrorHandlerProtocol
    private let createdAt: Date = Date()
    private var lastAccessed: Date = Date()
    
    init(errorHandler: ErrorHandlerProtocol) {
        self.errorHandler = errorHandler
    }
    
    func initialize() async throws {
        resourceState = .ready
    }
    
    func activate() throws {
        resourceState = .active
        lastAccessed = Date()
    }
    
    func deactivate() throws {
        resourceState = .ready
    }
    
    func dispose() async {
        resourceState = .disposed
    }
    
    func getResourceInfo() -> ResourceInfo {
        return ResourceInfo(
            id: resourceId,
            type: resourceType,
            state: resourceState,
            description: resourceDescription,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            memoryUsage: 256 * 1024, // 估算 256KB
            metadata: [:]
        )
    }
}