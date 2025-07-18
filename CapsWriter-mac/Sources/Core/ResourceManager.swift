import Foundation
import Combine
import AVFoundation
import os.log

/// 资源类型枚举
enum ResourceType: String, CaseIterable {
    case audio = "Audio"          // 音频资源 (AVAudioEngine, 录音器等)
    case recognition = "Recognition"    // 识别引擎 (Sherpa-ONNX)
    case file = "File"           // 文件句柄和临时文件
    case network = "Network"     // 网络连接和会话
    case timer = "Timer"         // 定时器和调度器
    case observer = "Observer"   // 通知观察者
    case memory = "Memory"       // 内存缓存
    case ui = "UI"               // UI 组件引用
    case system = "System"       // 系统资源
}

/// 资源状态枚举
enum ResourceState: String, CaseIterable {
    case uninitialized = "Uninitialized"
    case initializing = "Initializing"
    case ready = "Ready"
    case active = "Active"
    case disposing = "Disposing"
    case disposed = "Disposed"
    case error = "Error"
}

/// 资源管理协议
protocol ResourceManageable: AnyObject {
    var resourceId: String { get }
    var resourceType: ResourceType { get }
    var resourceState: ResourceState { get set }
    var resourceDescription: String { get }
    
    func initialize() async throws
    func activate() throws
    func deactivate() throws
    func dispose() async
    func getResourceInfo() -> ResourceInfo
}

/// 资源信息结构
struct ResourceInfo {
    let id: String
    let type: ResourceType
    let state: ResourceState
    let description: String
    let createdAt: Date
    let lastAccessed: Date
    let memoryUsage: Int64  // 字节
    let metadata: [String: Any]
    
    init(id: String, type: ResourceType, state: ResourceState, description: String, 
         createdAt: Date = Date(), lastAccessed: Date = Date(), 
         memoryUsage: Int64 = 0, metadata: [String: Any] = [:]) {
        self.id = id
        self.type = type
        self.state = state
        self.description = description
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.memoryUsage = memoryUsage
        self.metadata = metadata
    }
}

/// 资源管理器错误类型
enum ResourceManagerError: Error, LocalizedError {
    case resourceNotFound(String)
    case resourceAlreadyExists(String)
    case resourceInvalidState(String, ResourceState)
    case resourceInitializationFailed(String, Error)
    case resourceDisposalFailed(String, Error)
    case dependencyNotMet(String, [String])
    case circularDependency(String)
    case memoryLimitExceeded(String, Int64)
    
    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let id):
            return "资源未找到: \(id)"
        case .resourceAlreadyExists(let id):
            return "资源已存在: \(id)"
        case .resourceInvalidState(let id, let state):
            return "资源状态无效: \(id) - \(state)"
        case .resourceInitializationFailed(let id, let error):
            return "资源初始化失败: \(id) - \(error.localizedDescription)"
        case .resourceDisposalFailed(let id, let error):
            return "资源清理失败: \(id) - \(error.localizedDescription)"
        case .dependencyNotMet(let id, let dependencies):
            return "依赖不满足: \(id) - 缺少: \(dependencies.joined(separator: ", "))"
        case .circularDependency(let id):
            return "循环依赖检测: \(id)"
        case .memoryLimitExceeded(let id, let usage):
            return "内存限制超出: \(id) - 使用: \(usage) 字节"
        }
    }
}

/// 统一资源管理器 - 任务3.4
/// 提供统一的资源生命周期管理、内存监控、依赖管理和自动清理功能
class ResourceManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ResourceManager()
    
    private init() {
        setupMemoryMonitoring()
        setupNotificationObservers()
        print("🏗️ ResourceManager 已初始化")
    }
    
    // MARK: - Published Properties
    
    @Published var totalMemoryUsage: Int64 = 0
    @Published var resourceCount: Int = 0
    @Published var isMonitoringEnabled: Bool = true
    @Published var lastCleanupTime: Date = Date()
    
    // MARK: - Private Properties
    
    private var resources: [String: ResourceWrapper] = [:]
    private var dependencyGraph: [String: Set<String>] = [:]
    private var resourceQueue = DispatchQueue(label: "com.capswriter.resource-manager", attributes: .concurrent)
    private var memoryMonitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 配置参数
    private let maxMemoryUsage: Int64 = 200 * 1024 * 1024  // 200MB
    private let cleanupInterval: TimeInterval = 60 * 5     // 5分钟
    private let memoryMonitorInterval: TimeInterval = 10   // 10秒
    
    // 日志记录
    private let logger = Logger(subsystem: "com.capswriter.resource-manager", category: "ResourceManager")
    
    // MARK: - Resource Wrapper
    
    private class ResourceWrapper {
        let resource: ResourceManageable
        let dependencies: Set<String>
        var lastAccessed: Date
        let createdAt: Date
        
        init(resource: ResourceManageable, dependencies: Set<String> = []) {
            self.resource = resource
            self.dependencies = dependencies
            self.lastAccessed = Date()
            self.createdAt = Date()
        }
        
        func updateAccess() {
            lastAccessed = Date()
        }
    }
    
    // MARK: - Resource Registration
    
    /// 注册资源
    func register<T: ResourceManageable>(_ resource: T, dependencies: Set<String> = []) throws {
        let resourceId = resource.resourceId
        
        try resourceQueue.sync(flags: .barrier) {
            // 检查资源是否已存在
            if resources[resourceId] != nil {
                throw ResourceManagerError.resourceAlreadyExists(resourceId)
            }
            
            // 检查依赖是否满足
            let missingDependencies = dependencies.filter { !resources.keys.contains($0) }
            if !missingDependencies.isEmpty {
                throw ResourceManagerError.dependencyNotMet(resourceId, Array(missingDependencies))
            }
            
            // 检查循环依赖
            if detectCircularDependency(resourceId: resourceId, dependencies: dependencies) {
                throw ResourceManagerError.circularDependency(resourceId)
            }
            
            // 创建资源包装器
            let wrapper = ResourceWrapper(resource: resource, dependencies: dependencies)
            resources[resourceId] = wrapper
            dependencyGraph[resourceId] = dependencies
            
            // 更新统计信息
            updateResourceStatistics()
            
            logger.info("✅ 资源已注册: \(resourceId) - 类型: \(resource.resourceType.rawValue)")
        }
    }
    
    /// 注册资源（异步版本）
    func registerAsync<T: ResourceManageable>(_ resource: T, dependencies: Set<String> = []) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try register(resource, dependencies: dependencies)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Resource Lifecycle Management
    
    /// 初始化资源
    func initializeResource(_ resourceId: String) async throws {
        guard let wrapper = resourceQueue.sync(execute: { resources[resourceId] }) else {
            throw ResourceManagerError.resourceNotFound(resourceId)
        }
        
        let resource = wrapper.resource
        
        // 检查状态
        guard resource.resourceState == .uninitialized else {
            throw ResourceManagerError.resourceInvalidState(resourceId, resource.resourceState)
        }
        
        do {
            resource.resourceState = .initializing
            wrapper.updateAccess()
            
            // 初始化依赖
            try await initializeDependencies(resourceId)
            
            // 初始化资源
            try await resource.initialize()
            resource.resourceState = .ready
            
            logger.info("🚀 资源已初始化: \(resourceId)")
        } catch {
            resource.resourceState = .error
            throw ResourceManagerError.resourceInitializationFailed(resourceId, error)
        }
    }
    
    /// 激活资源
    func activateResource(_ resourceId: String) throws {
        guard let wrapper = resourceQueue.sync(execute: { resources[resourceId] }) else {
            throw ResourceManagerError.resourceNotFound(resourceId)
        }
        
        let resource = wrapper.resource
        
        // 检查状态
        guard resource.resourceState == .ready else {
            throw ResourceManagerError.resourceInvalidState(resourceId, resource.resourceState)
        }
        
        do {
            try resource.activate()
            resource.resourceState = .active
            wrapper.updateAccess()
            
            logger.info("▶️ 资源已激活: \(resourceId)")
        } catch {
            resource.resourceState = .error
            throw error
        }
    }
    
    /// 停用资源
    func deactivateResource(_ resourceId: String) throws {
        guard let wrapper = resourceQueue.sync(execute: { resources[resourceId] }) else {
            throw ResourceManagerError.resourceNotFound(resourceId)
        }
        
        let resource = wrapper.resource
        
        // 检查状态
        guard resource.resourceState == .active else {
            throw ResourceManagerError.resourceInvalidState(resourceId, resource.resourceState)
        }
        
        do {
            try resource.deactivate()
            resource.resourceState = .ready
            wrapper.updateAccess()
            
            logger.info("⏸️ 资源已停用: \(resourceId)")
        } catch {
            resource.resourceState = .error
            throw error
        }
    }
    
    /// 释放资源
    // 🔒 安全修复：防止递归栈溢出，使用迭代方式释放资源
    func disposeResource(_ resourceId: String) async throws {
        try await disposeResourceSafely(resourceId)
    }
    
    // 🔒 安全方法：使用迭代方式释放资源，防止递归栈溢出
    private func disposeResourceSafely(_ resourceId: String) async throws {
        // 🔒 安全检查：防止无限循环和栈溢出
        var processedResources: Set<String> = []
        var resourcesToDispose: [String] = [resourceId]
        let maxDisposeDepth = 100  // 限制最大处理深度
        var currentDepth = 0
        
        while !resourcesToDispose.isEmpty && currentDepth < maxDisposeDepth {
            currentDepth += 1
            
            // 取出下一个要处理的资源
            let currentResourceId = resourcesToDispose.removeFirst()
            
            // 🔒 循环检查：防止重复处理
            if processedResources.contains(currentResourceId) {
                logger.warning("⚠️ 检测到资源依赖循环，跳过: \(currentResourceId)")
                continue
            }
            
            // 检查资源是否存在
            guard let wrapper = resourceQueue.sync(execute: { resources[currentResourceId] }) else {
                logger.warning("⚠️ 资源不存在，跳过: \(currentResourceId)")
                continue
            }
            
            let resource = wrapper.resource
            
            do {
                resource.resourceState = .disposing
                
                // 检查是否有其他资源依赖此资源
                let dependentResources = findDependentResources(currentResourceId)
                if !dependentResources.isEmpty {
                    logger.warning("⚠️ 释放依赖资源: \(currentResourceId) - 依赖者: \(dependentResources)")
                    
                    // 🔒 安全添加：将依赖资源添加到要处理的队列中（非递归）
                    for dependentId in dependentResources {
                        if !processedResources.contains(dependentId) && !resourcesToDispose.contains(dependentId) {
                            resourcesToDispose.append(dependentId)
                        }
                    }
                    
                    // 跳过当前资源，先处理依赖资源
                    resourcesToDispose.append(currentResourceId)
                    continue
                }
                
                // 没有依赖资源，可以安全释放
                await resource.dispose()
                resource.resourceState = .disposed
                
                // 从管理器中移除
                resourceQueue.async(flags: .barrier) { [weak self] in
                    self?.resources.removeValue(forKey: currentResourceId)
                    self?.dependencyGraph.removeValue(forKey: currentResourceId)
                    self?.updateResourceStatistics()
                }
                
                // 标记为已处理
                processedResources.insert(currentResourceId)
                logger.info("🗑️ 资源已释放: \(currentResourceId)")
                
            } catch {
                resource.resourceState = .error
                logger.error("❌ 资源释放失败: \(currentResourceId) - \(error)")
                throw ResourceManagerError.resourceDisposalFailed(currentResourceId, error)
            }
        }
        
        // 🔒 安全检查：检查是否超过最大处理深度
        if currentDepth >= maxDisposeDepth {
            logger.error("❌ 资源释放超过最大深度限制: \(maxDisposeDepth)")
            throw ResourceManagerError.resourceDisposalFailed(resourceId, 
                NSError(domain: "ResourceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "资源释放超过最大深度限制"]))
        }
        
        // 🔒 安全检查：确保所有资源都被处理
        if !resourcesToDispose.isEmpty {
            logger.warning("⚠️ 仍有资源未被处理: \(resourcesToDispose)")
        }
    }
    
    // MARK: - Resource Query Methods
    
    /// 获取资源
    func getResource<T: ResourceManageable>(_ resourceId: String) -> T? {
        return resourceQueue.sync {
            guard let wrapper = resources[resourceId] else { return nil }
            wrapper.updateAccess()
            return wrapper.resource as? T
        }
    }
    
    /// 获取资源信息
    func getResourceInfo(_ resourceId: String) -> ResourceInfo? {
        return resourceQueue.sync {
            guard let wrapper = resources[resourceId] else { return nil }
            wrapper.updateAccess()
            return wrapper.resource.getResourceInfo()
        }
    }
    
    /// 获取所有资源信息
    func getAllResourceInfo() -> [ResourceInfo] {
        return resourceQueue.sync {
            return resources.values.map { $0.resource.getResourceInfo() }
        }
    }
    
    /// 按类型获取资源
    func getResourcesByType(_ type: ResourceType) -> [ResourceInfo] {
        return resourceQueue.sync {
            return resources.values
                .filter { $0.resource.resourceType == type }
                .map { $0.resource.getResourceInfo() }
        }
    }
    
    /// 按状态获取资源
    func getResourcesByState(_ state: ResourceState) -> [ResourceInfo] {
        return resourceQueue.sync {
            return resources.values
                .filter { $0.resource.resourceState == state }
                .map { $0.resource.getResourceInfo() }
        }
    }
    
    // MARK: - Memory Management
    
    // 🔒 安全修复：防止内存清理过程中的递归调用
    /// 触发内存清理
    func performMemoryCleanup() {
        // 🔒 安全检查：防止重入和过度频繁的清理
        let currentTime = Date()
        if let lastCleanup = lastCleanupTime,
           currentTime.timeIntervalSince(lastCleanup) < 5.0 {  // 5秒最小间隔
            logger.info("🔒 内存清理跳过：距离上次清理间隔过短")
            return
        }
        
        resourceQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var cleanedResources: [String] = []
            
            // 找出长时间未访问的资源
            for (resourceId, wrapper) in self.resources {
                let timeSinceLastAccess = currentTime.timeIntervalSince(wrapper.lastAccessed)
                
                // 如果超过清理间隔且不是活跃状态，则清理
                if timeSinceLastAccess > self.cleanupInterval && 
                   wrapper.resource.resourceState != .active {
                    cleanedResources.append(resourceId)
                }
            }
            
            // 🔒 安全限制：限制单次清理的资源数量
            let maxCleanupCount = 50
            if cleanedResources.count > maxCleanupCount {
                cleanedResources = Array(cleanedResources.prefix(maxCleanupCount))
                self.logger.warning("⚠️ 内存清理数量限制：单次最多清理 \(maxCleanupCount) 个资源")
            }
            
            // 异步清理资源
            Task {
                for resourceId in cleanedResources {
                    do {
                        try await self.disposeResource(resourceId)
                    } catch {
                        self.logger.error("清理资源失败: \(resourceId) - \(error.localizedDescription)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.lastCleanupTime = currentTime
                }
            }
            
            self.logger.info("🧹 内存清理完成，清理资源数量: \(cleanedResources.count)")
        }
    }
    
    // 🔒 安全修复：防止内存检查和清理的递归调用
    /// 检查内存使用情况
    func checkMemoryUsage() -> Bool {
        let currentUsage = resourceQueue.sync {
            return resources.values.reduce(0) { total, wrapper in
                total + wrapper.resource.getResourceInfo().memoryUsage
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.totalMemoryUsage = currentUsage
        }
        
        if currentUsage > maxMemoryUsage {
            logger.warning("⚠️ 内存使用超限: \(currentUsage) / \(maxMemoryUsage) 字节")
            
            // 🔒 安全修复：使用异步调用避免递归，并限制清理频率
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.performMemoryCleanup()
            }
            
            return false
        }
        
        return true
    }
    
    // MARK: - Dependency Management
    
    /// 初始化依赖资源
    private func initializeDependencies(_ resourceId: String) async throws {
        guard let dependencies = dependencyGraph[resourceId] else { return }
        
        for dependencyId in dependencies {
            if let wrapper = resources[dependencyId] {
                if wrapper.resource.resourceState == .uninitialized {
                    try await initializeResource(dependencyId)
                }
            }
        }
    }
    
    /// 检测循环依赖
    private func detectCircularDependency(resourceId: String, dependencies: Set<String>) -> Bool {
        for dependency in dependencies {
            if hasCircularDependency(from: dependency, to: resourceId, visited: Set()) {
                return true
            }
        }
        return false
    }
    
    /// 递归检查循环依赖
    private func hasCircularDependency(from: String, to: String, visited: Set<String>) -> Bool {
        if from == to {
            return true
        }
        
        if visited.contains(from) {
            return false
        }
        
        var newVisited = visited
        newVisited.insert(from)
        
        guard let dependencies = dependencyGraph[from] else { return false }
        
        for dependency in dependencies {
            if hasCircularDependency(from: dependency, to: to, visited: newVisited) {
                return true
            }
        }
        
        return false
    }
    
    /// 查找依赖此资源的其他资源
    private func findDependentResources(_ resourceId: String) -> [String] {
        return dependencyGraph.compactMap { (key, dependencies) in
            dependencies.contains(resourceId) ? key : nil
        }
    }
    
    // MARK: - Monitoring and Statistics
    
    /// 设置内存监控
    private func setupMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: memoryMonitorInterval, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    /// 设置通知观察者
    private func setupNotificationObservers() {
        // 应用将进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.performMemoryCleanup()
            }
            .store(in: &cancellables)
        
        // 内存警告
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.performMemoryCleanup()
            }
            .store(in: &cancellables)
    }
    
    /// 更新资源统计信息
    private func updateResourceStatistics() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resourceCount = self.resources.count
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        memoryMonitorTimer?.invalidate()
        cancellables.removeAll()
        
        // 释放所有资源
        Task {
            for resourceId in resources.keys {
                try? await disposeResource(resourceId)
            }
        }
        
        print("🗑️ ResourceManager 已清理")
    }
}

// MARK: - Extensions

extension ResourceManager {
    
    /// 获取资源管理器统计信息
    func getStatistics() -> ResourceManagerStatistics {
        return resourceQueue.sync {
            var typeCount: [ResourceType: Int] = [:]
            var stateCount: [ResourceState: Int] = [:]
            
            for wrapper in resources.values {
                let resource = wrapper.resource
                typeCount[resource.resourceType, default: 0] += 1
                stateCount[resource.resourceState, default: 0] += 1
            }
            
            return ResourceManagerStatistics(
                totalResources: resources.count,
                totalMemoryUsage: totalMemoryUsage,
                typeDistribution: typeCount,
                stateDistribution: stateCount,
                lastCleanupTime: lastCleanupTime
            )
        }
    }
    
    /// 导出资源管理器状态
    func exportState() -> [String: Any] {
        return resourceQueue.sync {
            var state: [String: Any] = [:]
            
            state["totalResources"] = resources.count
            state["totalMemoryUsage"] = totalMemoryUsage
            state["lastCleanupTime"] = lastCleanupTime
            
            var resourcesState: [[String: Any]] = []
            for (_, wrapper) in resources {
                let info = wrapper.resource.getResourceInfo()
                resourcesState.append([
                    "id": info.id,
                    "type": info.type.rawValue,
                    "state": info.state.rawValue,
                    "description": info.description,
                    "createdAt": info.createdAt,
                    "lastAccessed": info.lastAccessed,
                    "memoryUsage": info.memoryUsage
                ])
            }
            state["resources"] = resourcesState
            
            return state
        }
    }
}

/// 资源管理器统计信息
struct ResourceManagerStatistics {
    let totalResources: Int
    let totalMemoryUsage: Int64
    let typeDistribution: [ResourceType: Int]
    let stateDistribution: [ResourceState: Int]
    let lastCleanupTime: Date
}