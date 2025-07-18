import Foundation

/// 依赖注入协议
protocol DependencyInjectionProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T
    func resolve<T>(_ type: T.Type) -> T?
}

/// 依赖注入容器 - 第二阶段任务2.2
/// 实现服务注册、解析和生命周期管理
/// 支持单例模式、工厂模式和Mock服务替换
class DIContainer: DependencyInjectionProtocol {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    private init() {
        print("🏗️ DIContainer 已初始化")
        setupDefaultRegistrations()
    }
    
    // MARK: - Private Properties
    
    /// 服务注册表 - 存储服务类型和创建工厂
    private var registrations: [String: ServiceRegistration] = [:]
    
    /// 单例实例缓存
    private var singletonInstances: [String: Any] = [:]
    
    /// 线程安全队列
    private let containerQueue = DispatchQueue(label: "com.capswriter.di-container", attributes: .concurrent)
    
    // MARK: - Service Registration Types
    
    /// 服务注册信息
    private struct ServiceRegistration {
        let factory: () -> Any
        let lifecycle: ServiceLifecycle
        let name: String
    }
    
    /// 服务生命周期
    enum ServiceLifecycle {
        case singleton    // 单例 - 整个应用生命周期内只创建一次
        case transient    // 临时 - 每次解析都创建新实例
        case scoped       // 作用域 - 在特定作用域内为单例（暂未实现）
    }
    
    // MARK: - Registration Methods
    
    /// 注册工厂方法创建的服务
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        register(type, lifecycle: .transient, factory: factory)
    }
    
    /// 注册单例实例
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.singletonInstances[key] = instance
            self?.registrations[key] = ServiceRegistration(
                factory: { instance },
                lifecycle: .singleton,
                name: key
            )
            print("📦 已注册单例服务: \(key)")
        }
    }
    
    /// 注册服务（指定生命周期）
    func register<T>(_ type: T.Type, lifecycle: ServiceLifecycle, factory: @escaping () -> T) {
        let key = String(describing: type)
        
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.registrations[key] = ServiceRegistration(
                factory: factory,
                lifecycle: lifecycle,
                name: key
            )
            print("📦 已注册\(lifecycle == .singleton ? "单例" : "临时")服务: \(key)")
        }
    }
    
    /// 注册单例服务
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        register(type, lifecycle: .singleton, factory: factory)
    }
    
    // MARK: - Resolution Methods
    
    /// 解析服务 - 强制解析，找不到时会崩溃
    func resolve<T>(_ type: T.Type) -> T {
        guard let service: T = resolve(type) else {
            fatalError("❌ 无法解析服务: \(String(describing: type))")
        }
        return service
    }
    
    /// 解析服务 - 可选解析，找不到时返回nil
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        return containerQueue.sync { [weak self] in
            guard let self = self else { return nil }
            
            // 检查是否已注册
            guard let registration = self.registrations[key] else {
                print("⚠️ 服务未注册: \(key)")
                return nil
            }
            
            // 根据生命周期决定如何创建实例
            switch registration.lifecycle {
            case .singleton:
                return self.resolveSingleton(key: key, registration: registration)
            case .transient:
                return self.resolveTransient(registration: registration)
            case .scoped:
                // TODO: 实现作用域服务解析
                print("⚠️ 作用域服务暂未实现，使用临时服务模式")
                return self.resolveTransient(registration: registration)
            }
        }
    }
    
    /// 解析指定名称的服务
    func resolve<T>(_ type: T.Type, name: String) -> T? {
        let key = "\(String(describing: type))_\(name)"
        
        return containerQueue.sync { [weak self] in
            guard let self = self else { return nil }
            guard let registration = self.registrations[key] else {
                print("⚠️ 命名服务未注册: \(key)")
                return nil
            }
            
            switch registration.lifecycle {
            case .singleton:
                return self.resolveSingleton(key: key, registration: registration)
            case .transient:
                return self.resolveTransient(registration: registration)
            case .scoped:
                return self.resolveTransient(registration: registration)
            }
        }
    }
    
    // MARK: - Private Resolution Methods
    
    private func resolveSingleton<T>(key: String, registration: ServiceRegistration) -> T? {
        // 检查是否已存在单例实例
        if let existingInstance = singletonInstances[key] as? T {
            return existingInstance
        }
        
        // 创建新的单例实例
        let newInstance = registration.factory() as? T
        if let instance = newInstance {
            singletonInstances[key] = instance
            print("🔨 创建新单例实例: \(key)")
        } else {
            print("❌ 单例实例创建失败: \(key)")
        }
        
        return newInstance
    }
    
    private func resolveTransient<T>(registration: ServiceRegistration) -> T? {
        let instance = registration.factory() as? T
        if instance != nil {
            print("🔨 创建临时实例: \(registration.name)")
        } else {
            print("❌ 临时实例创建失败: \(registration.name)")
        }
        return instance
    }
    
    // MARK: - Management Methods
    
    /// 检查服务是否已注册
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return containerQueue.sync {
            return registrations[key] != nil
        }
    }
    
    /// 注销服务
    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.registrations.removeValue(forKey: key)
            self?.singletonInstances.removeValue(forKey: key)
            print("🗑️ 已注销服务: \(key)")
        }
    }
    
    /// 清理所有单例实例
    func clearSingletons() {
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.singletonInstances.removeAll()
            print("🧹 已清理所有单例实例")
        }
    }
    
    /// 重置容器（清理所有注册和实例）
    func reset() {
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.registrations.removeAll()
            self?.singletonInstances.removeAll()
            print("🔄 DIContainer 已重置")
            self?.setupDefaultRegistrations()
        }
    }
    
    /// 获取已注册服务列表
    func getRegisteredServices() -> [String] {
        return containerQueue.sync {
            return Array(registrations.keys).sorted()
        }
    }
    
    // MARK: - Default Registrations
    
    /// 设置默认服务注册
    private func setupDefaultRegistrations() {
        print("📋 设置默认服务注册...")
        
        // 注册配置管理器（单例）
        registerSingleton(ConfigurationManager.self) {
            return ConfigurationManager.shared
        }
        
        // 注册配置管理器协议映射（单例）
        registerSingleton(ConfigurationManagerProtocol.self) {
            return ConfigurationManager.shared
        }
        
        // 注册文本输入服务（单例）
        registerSingleton(TextInputServiceProtocol.self) {
            return TextInputService.shared
        }
        
        // 注册音频采集服务（每次新建）
        register(AudioCaptureServiceProtocol.self) {
            return AudioCaptureService()
        }
        
        // 注册语音识别服务（每次新建）
        register(SpeechRecognitionServiceProtocol.self) {
            return SherpaASRService()
        }
        
        // 注册键盘监听器（每次新建）
        register(KeyboardMonitorProtocol.self) {
            return KeyboardMonitor()
        }
        
        // 注册错误处理器（单例） - 集成错误处理机制
        registerSingleton(ErrorHandlerProtocol.self) {
            return ErrorHandler()
        }
        
        // 注册热词服务（单例） - 任务2.3
        registerSingleton(HotWordServiceProtocol.self) {
            return HotWordService(configManager: ConfigurationManager.shared)
        }
        
        // 注册标点符号处理服务（单例） - 任务3.1
        registerSingleton(PunctuationServiceProtocol.self) {
            return PunctuationService(configManager: ConfigurationManager.shared)
        }
        
        // 注册文本处理服务（单例） - 任务2.3
        registerSingleton(TextProcessingServiceProtocol.self) {
            return TextProcessingService(configManager: ConfigurationManager.shared)
        }
        
        // TODO: 注册权限监控服务（单例） - 响应式权限管理
        // registerSingleton(PermissionMonitorServiceProtocol.self) {
        //     return PermissionMonitorService()
        // }
        
        print("✅ 默认服务注册完成")
    }
    
    // MARK: - Mock Support
    
    /// 注册Mock服务（用于测试）
    func registerMock<T>(_ type: T.Type, mock: T) {
        let key = String(describing: type)
        
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.registrations[key] = ServiceRegistration(
                factory: { mock },
                lifecycle: .singleton,
                name: "\(key)_Mock"
            )
            self?.singletonInstances[key] = mock
            print("🎭 已注册Mock服务: \(key)")
        }
    }
    
    /// 移除Mock服务，恢复原始注册
    func removeMock<T>(_ type: T.Type) {
        let key = String(describing: type)
        
        containerQueue.async(flags: .barrier) { [weak self] in
            self?.singletonInstances.removeValue(forKey: key)
            // 重新设置默认注册
            self?.setupDefaultRegistrations()
            print("🎭 已移除Mock服务: \(key)")
        }
    }
    
    // MARK: - Debug Support
    
    /// 打印容器状态（调试用）
    func printContainerStatus() {
        containerQueue.sync {
            print("📊 DIContainer 状态:")
            print("   已注册服务数量: \(registrations.count)")
            print("   单例实例数量: \(singletonInstances.count)")
            
            if !registrations.isEmpty {
                print("   已注册服务:")
                for (key, registration) in registrations.sorted(by: { $0.key < $1.key }) {
                    let lifecycleIcon = registration.lifecycle == .singleton ? "🔒" : "🆕"
                    print("     \(lifecycleIcon) \(key)")
                }
            }
            
            if !singletonInstances.isEmpty {
                print("   活跃单例:")
                for key in singletonInstances.keys.sorted() {
                    print("     🟢 \(key)")
                }
            }
        }
    }
}

// MARK: - Extensions

extension DIContainer {
    /// 服务工厂方法 - 为常用服务提供便捷访问
    struct ServiceFactory {
        static func createAudioCaptureService() -> AudioCaptureServiceProtocol {
            return DIContainer.shared.resolve(AudioCaptureServiceProtocol.self)
        }
        
        static func createSpeechRecognitionService() -> SpeechRecognitionServiceProtocol {
            return DIContainer.shared.resolve(SpeechRecognitionServiceProtocol.self)
        }
        
        static func createTextInputService() -> TextInputServiceProtocol {
            return DIContainer.shared.resolve(TextInputServiceProtocol.self)
        }
        
        static func createKeyboardMonitor() -> KeyboardMonitorProtocol {
            return DIContainer.shared.resolve(KeyboardMonitorProtocol.self)
        }
        
        static func createConfigurationManager() -> any ConfigurationManagerProtocol {
            return DIContainer.shared.resolve(ConfigurationManager.self)
        }
        
        static func createErrorHandler() -> ErrorHandlerProtocol {
            return DIContainer.shared.resolve(ErrorHandlerProtocol.self)
        }
        
        static func createHotWordService() -> HotWordServiceProtocol {
            return DIContainer.shared.resolve(HotWordServiceProtocol.self)
        }
        
        static func createTextProcessingService() -> TextProcessingServiceProtocol {
            return DIContainer.shared.resolve(TextProcessingServiceProtocol.self)
        }
        
        static func createPunctuationService() -> PunctuationServiceProtocol {
            return DIContainer.shared.resolve(PunctuationServiceProtocol.self)
        }
        
        // TODO: 恢复权限监控服务工厂方法
        // static func createPermissionMonitorService() -> PermissionMonitorServiceProtocol {
        //     return DIContainer.shared.resolve(PermissionMonitorServiceProtocol.self)
        // }
    }
}

// MARK: - Error Types

enum DIContainerError: Error, LocalizedError {
    case serviceNotRegistered(String)
    case invalidServiceType(String)
    case circularDependency(String)
    case registrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let service):
            return "服务未注册: \(service)"
        case .invalidServiceType(let service):
            return "无效的服务类型: \(service)"
        case .circularDependency(let service):
            return "循环依赖检测: \(service)"
        case .registrationFailed(let service):
            return "服务注册失败: \(service)"
        }
    }
}