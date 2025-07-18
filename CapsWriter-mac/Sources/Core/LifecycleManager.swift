import Foundation
import Combine
import AppKit
import os.log

/// 服务生命周期协议
protocol ServiceLifecycle: AnyObject {
    func onAppLaunched()
    func onAppWillEnterForeground()
    func onAppDidEnterBackground()
    func onAppWillTerminate()
    func onLowMemoryWarning()
    func onSystemSleep()
    func onSystemWake()
}

/// 生命周期阶段
enum LifecyclePhase: String, CaseIterable {
    case launching = "Launching"
    case active = "Active"
    case background = "Background"
    case terminating = "Terminating"
    case sleeping = "Sleeping"
    case error = "Error"
}

/// 生命周期事件
enum LifecycleEvent {
    case appLaunched
    case appWillEnterForeground
    case appDidEnterBackground
    case appWillTerminate
    case lowMemoryWarning
    case systemSleep
    case systemWake
    case userLogout
    case systemShutdown
}

/// 生命周期管理器错误
enum LifecycleManagerError: Error, LocalizedError {
    case serviceRegistrationFailed(String)
    case phaseTransitionFailed(LifecyclePhase, LifecyclePhase)
    case eventHandlingFailed(LifecycleEvent, Error)
    case resourceCleanupFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceRegistrationFailed(let service):
            return "服务注册失败: \(service)"
        case .phaseTransitionFailed(let from, let to):
            return "阶段转换失败: \(from.rawValue) -> \(to.rawValue)"
        case .eventHandlingFailed(let event, let error):
            return "事件处理失败: \(event) - \(error.localizedDescription)"
        case .resourceCleanupFailed(let resource, let error):
            return "资源清理失败: \(resource) - \(error.localizedDescription)"
        }
    }
}

/// 生命周期管理器 - 任务3.4
/// 统一管理应用和服务的生命周期，协调资源初始化和清理
class LifecycleManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LifecycleManager()
    
    private init() {
        setupNotificationObservers()
        print("🔄 LifecycleManager 已初始化")
    }
    
    // MARK: - Published Properties
    
    @Published var currentPhase: LifecyclePhase = .launching
    @Published var isTransitioning: Bool = false
    @Published var lastEventTime: Date = Date()
    @Published var registeredServicesCount: Int = 0
    
    // MARK: - Private Properties
    
    private var registeredServices: [String: ServiceLifecycle] = [:]
    private var resourceManager: ResourceManager { ResourceManager.shared }
    private var cancellables = Set<AnyCancellable>()
    private let lifecycleQueue = DispatchQueue(label: "com.capswriter.lifecycle-manager", qos: .userInitiated)
    
    // 配置参数
    private let transitionTimeout: TimeInterval = 30.0  // 30秒超时
    private let cleanupDelay: TimeInterval = 2.0        // 清理延迟
    
    // 日志记录
    private let logger = Logger(subsystem: "com.capswriter.lifecycle-manager", category: "LifecycleManager")
    
    // MARK: - Service Registration
    
    /// 注册服务生命周期
    func registerService<T: ServiceLifecycle>(_ service: T, identifier: String) throws {
        lifecycleQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.registeredServices[identifier] != nil {
                self.logger.warning("⚠️ 服务已注册，将被替换: \(identifier)")
            }
            
            self.registeredServices[identifier] = service
            
            // 如果应用已启动，立即通知服务
            if self.currentPhase != .launching {
                service.onAppLaunched()
            }
            
            DispatchQueue.main.async {
                self.registeredServicesCount = self.registeredServices.count
            }
            
            self.logger.info("✅ 服务已注册: \(identifier)")
        }
    }
    
    /// 注销服务
    func unregisterService(identifier: String) {
        lifecycleQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.registeredServices.removeValue(forKey: identifier) != nil {
                DispatchQueue.main.async {
                    self.registeredServicesCount = self.registeredServices.count
                }
                self.logger.info("🗑️ 服务已注销: \(identifier)")
            } else {
                self.logger.warning("⚠️ 尝试注销未注册的服务: \(identifier)")
            }
        }
    }
    
    // MARK: - Lifecycle Phase Management
    
    /// 转换生命周期阶段
    private func transitionToPhase(_ newPhase: LifecyclePhase) {
        lifecycleQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let oldPhase = self.currentPhase
            guard oldPhase != newPhase else { return }
            
            DispatchQueue.main.async {
                self.isTransitioning = true
                self.currentPhase = newPhase
                self.lastEventTime = Date()
            }
            
            self.logger.info("🔄 生命周期转换: \(oldPhase.rawValue) -> \(newPhase.rawValue)")
            
            // 执行阶段转换后的清理
            Task {
                await self.performPhaseTransitionCleanup(from: oldPhase, to: newPhase)
                
                DispatchQueue.main.async {
                    self.isTransitioning = false
                }
            }
        }
    }
    
    /// 执行阶段转换后的清理
    private func performPhaseTransitionCleanup(from oldPhase: LifecyclePhase, to newPhase: LifecyclePhase) async {
        switch (oldPhase, newPhase) {
        case (.launching, .active):
            await handleLaunchToActiveTransition()
        case (.active, .background):
            await handleActiveToBackgroundTransition()
        case (.background, .active):
            await handleBackgroundToActiveTransition()
        case (_, .terminating):
            await handleTerminatingTransition()
        case (.active, .sleeping):
            await handleSleepTransition()
        case (.sleeping, .active):
            await handleWakeTransition()
        default:
            break
        }
    }
    
    // MARK: - Event Handling
    
    /// 处理应用启动完成
    private func handleAppLaunched() {
        logger.info("🚀 应用启动完成")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onAppLaunched()
                    self.logger.debug("✅ 服务启动完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务启动失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        transitionToPhase(.active)
    }
    
    /// 处理应用即将进入前台
    private func handleAppWillEnterForeground() {
        logger.info("📱 应用即将进入前台")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onAppWillEnterForeground()
                    self.logger.debug("✅ 服务前台准备完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务前台准备失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        transitionToPhase(.active)
    }
    
    /// 处理应用已进入后台
    private func handleAppDidEnterBackground() {
        logger.info("🔙 应用已进入后台")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onAppDidEnterBackground()
                    self.logger.debug("✅ 服务后台处理完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务后台处理失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        transitionToPhase(.background)
    }
    
    /// 处理应用即将终止
    private func handleAppWillTerminate() {
        logger.info("🛑 应用即将终止")
        
        transitionToPhase(.terminating)
        
        lifecycleQueue.sync { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onAppWillTerminate()
                    self.logger.debug("✅ 服务终止处理完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务终止处理失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 处理低内存警告
    private func handleLowMemoryWarning() {
        logger.warning("⚠️ 收到低内存警告")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onLowMemoryWarning()
                    self.logger.debug("✅ 服务内存清理完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务内存清理失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        // 触发资源管理器清理
        resourceManager.performMemoryCleanup()
    }
    
    /// 处理系统休眠
    private func handleSystemSleep() {
        logger.info("😴 系统即将休眠")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onSystemSleep()
                    self.logger.debug("✅ 服务休眠处理完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务休眠处理失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        transitionToPhase(.sleeping)
    }
    
    /// 处理系统唤醒
    private func handleSystemWake() {
        logger.info("⏰ 系统已唤醒")
        
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (identifier, service) in self.registeredServices {
                do {
                    service.onSystemWake()
                    self.logger.debug("✅ 服务唤醒处理完成: \(identifier)")
                } catch {
                    self.logger.error("❌ 服务唤醒处理失败: \(identifier) - \(error.localizedDescription)")
                }
            }
        }
        
        transitionToPhase(.active)
    }
    
    // MARK: - Phase Transition Handlers
    
    /// 处理启动到活跃状态转换
    private func handleLaunchToActiveTransition() async {
        logger.info("🚀 处理应用启动完成")
        
        // 初始化核心资源
        await initializeCoreResources()
        
        // 验证关键服务状态
        await validateCriticalServices()
    }
    
    /// 处理活跃到后台状态转换
    private func handleActiveToBackgroundTransition() async {
        logger.info("🔙 处理应用后台转换")
        
        // 暂停非关键服务
        await pauseNonCriticalServices()
        
        // 清理缓存和临时资源
        await cleanupTemporaryResources()
        
        // 保存应用状态
        await saveApplicationState()
    }
    
    /// 处理后台到活跃状态转换
    private func handleBackgroundToActiveTransition() async {
        logger.info("📱 处理应用前台转换")
        
        // 恢复暂停的服务
        await resumePausedServices()
        
        // 刷新状态信息
        await refreshApplicationState()
    }
    
    /// 处理终止状态转换
    private func handleTerminatingTransition() async {
        logger.info("🛑 处理应用终止")
        
        // 保存关键数据
        await saveApplicationData()
        
        // 清理所有资源
        await cleanupAllResources()
        
        // 关闭所有服务
        await shutdownAllServices()
    }
    
    /// 处理休眠状态转换
    private func handleSleepTransition() async {
        logger.info("😴 处理系统休眠")
        
        // 暂停所有活动
        await pauseAllActivities()
        
        // 释放可释放的资源
        await releaseOptionalResources()
    }
    
    /// 处理唤醒状态转换
    private func handleWakeTransition() async {
        logger.info("⏰ 处理系统唤醒")
        
        // 恢复必要资源
        await restoreRequiredResources()
        
        // 重新初始化服务
        await reinitializeServices()
    }
    
    // MARK: - Resource Management Integration
    
    /// 初始化核心资源
    private func initializeCoreResources() async {
        logger.info("🏗️ 初始化核心资源")
        
        // 获取所有未初始化的资源
        let uninitializedResources = resourceManager.getResourcesByState(.uninitialized)
        
        for resourceInfo in uninitializedResources {
            do {
                try await resourceManager.initializeResource(resourceInfo.id)
                logger.debug("✅ 资源初始化成功: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 资源初始化失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
    }
    
    /// 验证关键服务状态
    private func validateCriticalServices() async {
        logger.info("🔍 验证关键服务状态")
        
        // 检查关键资源状态
        let criticalResourceTypes: [ResourceType] = [.audio, .recognition, .system]
        
        for resourceType in criticalResourceTypes {
            let resources = resourceManager.getResourcesByType(resourceType)
            let activeResources = resources.filter { $0.state == .active || $0.state == .ready }
            
            if activeResources.isEmpty {
                logger.warning("⚠️ 关键资源类型无活跃实例: \(resourceType.rawValue)")
            }
        }
    }
    
    /// 暂停非关键服务
    private func pauseNonCriticalServices() async {
        logger.info("⏸️ 暂停非关键服务")
        
        // 暂停非关键资源
        let nonCriticalTypes: [ResourceType] = [.ui, .file, .network]
        
        for resourceType in nonCriticalTypes {
            let resources = resourceManager.getResourcesByType(resourceType)
            
            for resourceInfo in resources {
                if resourceInfo.state == .active {
                    do {
                        try resourceManager.deactivateResource(resourceInfo.id)
                        logger.debug("⏸️ 资源已暂停: \(resourceInfo.id)")
                    } catch {
                        logger.error("❌ 资源暂停失败: \(resourceInfo.id) - \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// 清理临时资源
    private func cleanupTemporaryResources() async {
        logger.info("🧹 清理临时资源")
        
        // 触发资源管理器清理
        resourceManager.performMemoryCleanup()
        
        // 清理临时文件
        await cleanupTemporaryFiles()
    }
    
    /// 清理临时文件
    private func cleanupTemporaryFiles() async {
        logger.info("🗑️ 清理临时文件")
        
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            
            for fileURL in tempFiles {
                if fileURL.pathExtension == "tmp" || fileURL.pathExtension == "temp" {
                    try FileManager.default.removeItem(at: fileURL)
                    logger.debug("🗑️ 临时文件已清理: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            logger.error("❌ 临时文件清理失败: \(error.localizedDescription)")
        }
    }
    
    /// 保存应用状态
    private func saveApplicationState() async {
        logger.info("💾 保存应用状态")
        
        // 保存当前配置
        if let configManager = DIContainer.shared.resolve(ConfigurationManagerProtocol.self) {
            configManager.saveConfiguration()
        }
        
        // 保存资源状态
        let resourceState = resourceManager.exportState()
        UserDefaults.standard.set(resourceState, forKey: "ResourceManagerState")
    }
    
    /// 恢复暂停的服务
    private func resumePausedServices() async {
        logger.info("▶️ 恢复暂停的服务")
        
        // 恢复就绪状态的资源
        let readyResources = resourceManager.getResourcesByState(.ready)
        
        for resourceInfo in readyResources {
            // 根据资源类型决定是否需要激活
            if resourceInfo.type == .audio || resourceInfo.type == .recognition {
                do {
                    try resourceManager.activateResource(resourceInfo.id)
                    logger.debug("▶️ 资源已恢复: \(resourceInfo.id)")
                } catch {
                    logger.error("❌ 资源恢复失败: \(resourceInfo.id) - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 刷新应用状态
    private func refreshApplicationState() async {
        logger.info("🔄 刷新应用状态")
        
        // 检查并恢复资源状态
        if let savedState = UserDefaults.standard.object(forKey: "ResourceManagerState") as? [String: Any] {
            logger.debug("📋 发现保存的资源状态，正在恢复...")
            // 这里可以添加状态恢复逻辑
        }
    }
    
    /// 保存应用数据
    private func saveApplicationData() async {
        logger.info("💾 保存应用数据")
        
        // 保存用户偏好
        UserDefaults.standard.synchronize()
        
        // 保存日志
        if let loggingService = DIContainer.shared.resolve(LoggingServiceProtocol.self) {
            await loggingService.flushLogs()
        }
    }
    
    /// 清理所有资源
    private func cleanupAllResources() async {
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
    }
    
    /// 关闭所有服务
    private func shutdownAllServices() async {
        logger.info("🛑 关闭所有服务")
        
        // 清理所有注册的服务
        lifecycleQueue.sync(flags: .barrier) { [weak self] in
            self?.registeredServices.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.registeredServicesCount = 0
        }
    }
    
    /// 暂停所有活动
    private func pauseAllActivities() async {
        logger.info("⏸️ 暂停所有活动")
        
        let activeResources = resourceManager.getResourcesByState(.active)
        
        for resourceInfo in activeResources {
            do {
                try resourceManager.deactivateResource(resourceInfo.id)
                logger.debug("⏸️ 活动已暂停: \(resourceInfo.id)")
            } catch {
                logger.error("❌ 活动暂停失败: \(resourceInfo.id) - \(error.localizedDescription)")
            }
        }
    }
    
    /// 释放可选资源
    private func releaseOptionalResources() async {
        logger.info("🔄 释放可选资源")
        
        // 释放缓存等可选资源
        let optionalTypes: [ResourceType] = [.memory, .file, .network]
        
        for resourceType in optionalTypes {
            let resources = resourceManager.getResourcesByType(resourceType)
            
            for resourceInfo in resources {
                if resourceInfo.state != .active {
                    do {
                        try await resourceManager.disposeResource(resourceInfo.id)
                        logger.debug("🔄 可选资源已释放: \(resourceInfo.id)")
                    } catch {
                        logger.error("❌ 可选资源释放失败: \(resourceInfo.id) - \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// 恢复必要资源
    private func restoreRequiredResources() async {
        logger.info("🔄 恢复必要资源")
        
        // 恢复核心资源
        let coreTypes: [ResourceType] = [.audio, .recognition, .system]
        
        for resourceType in coreTypes {
            let resources = resourceManager.getResourcesByType(resourceType)
            
            if resources.isEmpty {
                logger.warning("⚠️ 核心资源类型无实例，需要重新初始化: \(resourceType.rawValue)")
                // 这里可以添加资源重新创建逻辑
            }
        }
    }
    
    /// 重新初始化服务
    private func reinitializeServices() async {
        logger.info("🔄 重新初始化服务")
        
        // 重新初始化就绪状态的资源
        let readyResources = resourceManager.getResourcesByState(.ready)
        
        for resourceInfo in readyResources {
            if resourceInfo.type == .audio || resourceInfo.type == .recognition {
                do {
                    try resourceManager.activateResource(resourceInfo.id)
                    logger.debug("🔄 服务重新初始化成功: \(resourceInfo.id)")
                } catch {
                    logger.error("❌ 服务重新初始化失败: \(resourceInfo.id) - \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Notification Observers
    
    /// 设置通知观察者
    private func setupNotificationObservers() {
        // 应用生命周期通知
        NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
            .sink { [weak self] _ in
                self?.handleAppLaunched()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
        
        // 系统通知
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                self?.handleSystemSleep()
            }
            .store(in: &cancellables)
        
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.handleSystemWake()
            }
            .store(in: &cancellables)
        
        // 内存警告（如果有的话）
        NotificationCenter.default.publisher(for: NSApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleLowMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 手动触发生命周期事件
    func triggerEvent(_ event: LifecycleEvent) {
        logger.info("🔄 手动触发生命周期事件: \(event)")
        
        switch event {
        case .appLaunched:
            handleAppLaunched()
        case .appWillEnterForeground:
            handleAppWillEnterForeground()
        case .appDidEnterBackground:
            handleAppDidEnterBackground()
        case .appWillTerminate:
            handleAppWillTerminate()
        case .lowMemoryWarning:
            handleLowMemoryWarning()
        case .systemSleep:
            handleSystemSleep()
        case .systemWake:
            handleSystemWake()
        default:
            logger.warning("⚠️ 未支持的手动事件: \(event)")
        }
    }
    
    /// 获取生命周期统计信息
    func getLifecycleStatistics() -> LifecycleStatistics {
        return LifecycleStatistics(
            currentPhase: currentPhase,
            isTransitioning: isTransitioning,
            lastEventTime: lastEventTime,
            registeredServicesCount: registeredServicesCount,
            uptime: Date().timeIntervalSince(lastEventTime)
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
        print("🗑️ LifecycleManager 已清理")
    }
}

// MARK: - Statistics

/// 生命周期统计信息
struct LifecycleStatistics {
    let currentPhase: LifecyclePhase
    let isTransitioning: Bool
    let lastEventTime: Date
    let registeredServicesCount: Int
    let uptime: TimeInterval
}

// MARK: - Extensions

extension LifecycleManager {
    
    /// 获取所有注册的服务标识符
    func getRegisteredServiceIdentifiers() -> [String] {
        return lifecycleQueue.sync {
            return Array(registeredServices.keys).sorted()
        }
    }
    
    /// 检查服务是否已注册
    func isServiceRegistered(identifier: String) -> Bool {
        return lifecycleQueue.sync {
            return registeredServices[identifier] != nil
        }
    }
    
    /// 导出生命周期管理器状态
    func exportState() -> [String: Any] {
        return lifecycleQueue.sync {
            return [
                "currentPhase": currentPhase.rawValue,
                "isTransitioning": isTransitioning,
                "lastEventTime": lastEventTime,
                "registeredServicesCount": registeredServicesCount,
                "registeredServices": Array(registeredServices.keys).sorted()
            ]
        }
    }
}