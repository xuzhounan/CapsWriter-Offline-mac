import Foundation
import os.log
import Combine

/// 智能内存管理器 - 优化内存使用和防止内存泄漏
/// 
/// 功能特点：
/// - 自动内存监控和预警
/// - 智能对象池管理
/// - 内存泄漏检测和预防
/// - 自动垃圾回收优化
/// - 缓存管理和清理策略
class MemoryManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MemoryManager()
    
    // MARK: - Published Properties
    @Published var currentMemoryUsage: Double = 0.0  // MB
    @Published var peakMemoryUsage: Double = 0.0     // MB
    @Published var objectPoolStats: [String: Int] = [:]
    @Published var cacheStats: CacheStatistics = CacheStatistics()
    @Published var memoryWarnings: [MemoryWarning] = []
    
    // MARK: - Private Properties
    private let monitoringQueue = DispatchQueue(label: "com.capswriter.memory-monitor", qos: .utility)
    private let cleanupQueue = DispatchQueue(label: "com.capswriter.memory-cleanup", qos: .background)
    
    private var monitoringTimer: Timer?
    private let logger = os.Logger(subsystem: "com.capswriter", category: "MemoryManager")
    
    // 对象池管理
    private var audioBufferPool = ObjectPool<AudioBufferWrapper>()
    private var stringPool = ObjectPool<NSMutableString>()
    private var dataPool = ObjectPool<NSMutableData>()
    
    // 缓存管理
    private var audioDataCache = MemoryCache<String, Data>()
    private var stringCache = MemoryCache<String, String>()
    private var configCache = MemoryCache<String, Any>()
    
    // 弱引用监控
    private var trackedObjects = NSHashTable<AnyObject>.weakObjects()
    private var trackedObjectsMetadata: [String: TrackedObjectMetadata] = [:]
    
    // 配置参数
    private let monitoringInterval: TimeInterval = 5.0  // 5秒监控间隔
    private let memoryWarningThreshold: Double = 150.0  // 150MB警告阈值
    private let memoryCriticalThreshold: Double = 200.0 // 200MB严重阈值
    private let maxCacheSize: Int = 50 * 1024 * 1024    // 50MB最大缓存
    
    // MARK: - Initialization
    private init() {
        setupObjectPools()
        setupCaches()
        startMemoryMonitoring()
        setupMemoryPressureObserver()
        logger.info("🧠 MemoryManager 初始化完成")
    }
    
    deinit {
        stopMemoryMonitoring()
        cleanupAllResources()
        logger.info("🧠 MemoryManager 销毁")
    }
    
    // MARK: - Public Methods
    
    /// 获取或创建音频缓冲区包装器
    /// - Parameter capacity: 缓冲区容量
    /// - Returns: 音频缓冲区包装器
    func getAudioBufferWrapper(capacity: Int) -> AudioBufferWrapper {
        if let wrapper = audioBufferPool.acquire() {
            wrapper.resize(capacity: capacity)
            return wrapper
        } else {
            return AudioBufferWrapper(capacity: capacity)
        }
    }
    
    /// 释放音频缓冲区包装器
    /// - Parameter wrapper: 要释放的包装器
    func releaseAudioBufferWrapper(_ wrapper: AudioBufferWrapper) {
        wrapper.reset()
        audioBufferPool.release(wrapper)
    }
    
    /// 获取或创建可变字符串
    /// - Parameter initialCapacity: 初始容量
    /// - Returns: 可变字符串
    func getMutableString(initialCapacity: Int = 256) -> NSMutableString {
        if let string = stringPool.acquire() {
            string.setString("")
            return string
        } else {
            return NSMutableString(capacity: initialCapacity)
        }
    }
    
    /// 释放可变字符串
    /// - Parameter string: 要释放的字符串
    func releaseMutableString(_ string: NSMutableString) {
        string.setString("")  // 清空内容
        stringPool.release(string)
    }
    
    /// 获取或创建可变数据
    /// - Parameter initialCapacity: 初始容量
    /// - Returns: 可变数据
    func getMutableData(initialCapacity: Int = 1024) -> NSMutableData {
        if let data = dataPool.acquire() {
            data.length = 0
            return data
        } else {
            return NSMutableData(capacity: initialCapacity) ?? NSMutableData()
        }
    }
    
    /// 释放可变数据
    /// - Parameter data: 要释放的数据
    func releaseMutableData(_ data: NSMutableData) {
        data.length = 0  // 清空内容
        dataPool.release(data)
    }
    
    /// 缓存音频数据
    /// - Parameters:
    ///   - key: 缓存键
    ///   - data: 音频数据
    func cacheAudioData(key: String, data: Data) {
        audioDataCache.setValue(data, forKey: key)
        updateCacheStats()
    }
    
    /// 获取缓存的音频数据
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的音频数据
    func getCachedAudioData(key: String) -> Data? {
        return audioDataCache.getValue(forKey: key)
    }
    
    /// 缓存字符串
    /// - Parameters:
    ///   - key: 缓存键
    ///   - string: 字符串
    func cacheString(key: String, string: String) {
        stringCache.setValue(string, forKey: key)
        updateCacheStats()
    }
    
    /// 获取缓存的字符串
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的字符串
    func getCachedString(key: String) -> String? {
        return stringCache.getValue(forKey: key)
    }
    
    /// 追踪对象生命周期
    /// - Parameters:
    ///   - object: 要追踪的对象
    ///   - name: 对象名称
    ///   - metadata: 元数据
    func trackObject(_ object: AnyObject, name: String, metadata: TrackedObjectMetadata? = nil) {
        trackedObjects.add(object)
        
        let objectId = String(format: "%p", unsafeBitCast(object, to: Int.self))
        trackedObjectsMetadata[objectId] = metadata ?? TrackedObjectMetadata(
            name: name,
            createdAt: Date(),
            className: String(describing: type(of: object))
        )
        
        logger.debug("📍 开始追踪对象: \(name) (\(objectId))")
    }
    
    /// 执行内存清理
    /// - Parameter force: 是否强制清理
    func performMemoryCleanup(force: Bool = false) {
        cleanupQueue.async { [weak self] in
            self?.executeMemoryCleanup(force: force)
        }
    }
    
    /// 清理所有缓存
    func clearAllCaches() {
        audioDataCache.removeAll()
        stringCache.removeAll()
        configCache.removeAll()
        
        updateCacheStats()
        logger.info("🧹 所有缓存已清理")
    }
    
    /// 获取内存使用报告
    /// - Returns: 内存使用报告
    func getMemoryReport() -> MemoryReport {
        let currentUsage = getCurrentMemoryUsage()
        
        return MemoryReport(
            currentUsage: currentUsage,
            peakUsage: peakMemoryUsage,
            objectPoolStats: objectPoolStats,
            cacheStats: cacheStats,
            trackedObjectsCount: trackedObjects.count,
            warnings: memoryWarnings,
            recommendations: generateMemoryRecommendations()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupObjectPools() {
        // 配置音频缓冲区池
        audioBufferPool.configure(
            initialSize: 5,
            maxSize: 20,
            factory: { AudioBufferWrapper(capacity: 1024) },
            reset: { $0.reset() }
        )
        
        // 配置字符串池
        stringPool.configure(
            initialSize: 10,
            maxSize: 50,
            factory: { NSMutableString(capacity: 256) },
            reset: { $0.setString("") }
        )
        
        // 配置数据池
        dataPool.configure(
            initialSize: 5,
            maxSize: 20,
            factory: { NSMutableData(capacity: 1024) ?? NSMutableData() },
            reset: { $0.length = 0 }
        )
        
        updateObjectPoolStats()
        logger.info("🏊 对象池配置完成")
    }
    
    private func setupCaches() {
        // 配置音频数据缓存
        audioDataCache.configure(maxSize: maxCacheSize / 2, ttl: 300) // 5分钟TTL
        
        // 配置字符串缓存
        stringCache.configure(maxSize: maxCacheSize / 4, ttl: 600) // 10分钟TTL
        
        // 配置配置缓存
        configCache.configure(maxSize: maxCacheSize / 4, ttl: -1) // 永不过期
        
        updateCacheStats()
        logger.info("💾 缓存系统配置完成")
    }
    
    private func startMemoryMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.monitorMemoryUsage()
        }
        logger.info("🔍 内存监控已启动")
    }
    
    private func stopMemoryMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("🔍 内存监控已停止")
    }
    
    private func setupMemoryPressureObserver() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: monitoringQueue)
        
        source.setEventHandler { [weak self] in
            let event = source.mask
            if event.contains(.warning) {
                self?.handleMemoryPressure(level: .warning)
            } else if event.contains(.critical) {
                self?.handleMemoryPressure(level: .critical)
            }
        }
        
        source.resume()
        logger.info("📊 内存压力监控已设置")
    }
    
    private func monitorMemoryUsage() {
        let currentUsage = getCurrentMemoryUsage()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentMemoryUsage = currentUsage
            
            if currentUsage > self.peakMemoryUsage {
                self.peakMemoryUsage = currentUsage
            }
            
            // 检查内存警告阈值
            if currentUsage > self.memoryCriticalThreshold {
                self.addMemoryWarning(.critical, message: "内存使用严重超标: \(Int(currentUsage))MB")
                self.performMemoryCleanup(force: true)
            } else if currentUsage > self.memoryWarningThreshold {
                self.addMemoryWarning(.warning, message: "内存使用较高: \(Int(currentUsage))MB")
                self.performMemoryCleanup(force: false)
            }
        }
        
        // 更新统计信息
        updateObjectPoolStats()
        updateCacheStats()
        checkForLeaks()
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0  // Convert to MB
        }
        
        return 0.0
    }
    
    private func handleMemoryPressure(level: MemoryPressureLevel) {
        logger.warning("⚠️ 系统内存压力: \(level)")
        
        switch level {
        case .warning:
            addMemoryWarning(.warning, message: "系统内存压力警告")
            performMemoryCleanup(force: false)
            
        case .critical:
            addMemoryWarning(.critical, message: "系统内存压力严重")
            performMemoryCleanup(force: true)
            clearAllCaches()
        }
    }
    
    private func executeMemoryCleanup(force: Bool) {
        logger.info("🧹 执行内存清理 (强制: \(force))")
        
        // 清理过期缓存
        audioDataCache.removeExpired()
        stringCache.removeExpired()
        configCache.removeExpired()
        
        // 如果强制清理，释放部分缓存
        if force {
            audioDataCache.reduceSizeTo(maxSize: maxCacheSize / 4)
            stringCache.reduceSizeTo(maxSize: maxCacheSize / 8)
        }
        
        // 清理对象池中的多余对象
        audioBufferPool.shrink()
        stringPool.shrink()
        dataPool.shrink()
        
        // 触发垃圾回收
        if force {
            autoreleasepool {
                // 强制释放autorelease对象
            }
        }
        
        updateCacheStats()
        updateObjectPoolStats()
        
        logger.info("✅ 内存清理完成")
    }
    
    private func checkForLeaks() {
        // 清理已释放的对象元数据
        let validObjectIds = Set(trackedObjects.allObjects.map { object in
            String(format: "%p", unsafeBitCast(object, to: Int.self))
        })
        
        let allTrackedIds = Set(trackedObjectsMetadata.keys)
        let leakedIds = allTrackedIds.subtracting(validObjectIds)
        
        for leakedId in leakedIds {
            if let metadata = trackedObjectsMetadata.removeValue(forKey: leakedId) {
                let lifetime = Date().timeIntervalSince(metadata.createdAt)
                logger.debug("🗑️ 对象已释放: \(metadata.name) (存活 \(Int(lifetime))秒)")
            }
        }
    }
    
    private func updateObjectPoolStats() {
        DispatchQueue.main.async { [weak self] in
            self?.objectPoolStats = [
                "AudioBuffer": self?.audioBufferPool.availableCount ?? 0,
                "String": self?.stringPool.availableCount ?? 0,
                "Data": self?.dataPool.availableCount ?? 0
            ]
        }
    }
    
    private func updateCacheStats() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.cacheStats = CacheStatistics(
                audioDataCacheSize: self.audioDataCache.currentSize,
                stringCacheSize: self.stringCache.currentSize,
                configCacheSize: self.configCache.currentSize,
                totalCacheSize: self.audioDataCache.currentSize + self.stringCache.currentSize + self.configCache.currentSize,
                audioDataCacheHitRate: self.audioDataCache.hitRate,
                stringCacheHitRate: self.stringCache.hitRate,
                configCacheHitRate: self.configCache.hitRate
            )
        }
    }
    
    private func addMemoryWarning(_ level: MemoryWarningLevel, message: String) {
        let warning = MemoryWarning(
            level: level,
            message: message,
            timestamp: Date(),
            memoryUsage: currentMemoryUsage
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.memoryWarnings.append(warning)
            
            // 限制警告数量
            if let count = self?.memoryWarnings.count, count > 20 {
                self?.memoryWarnings.removeFirst(count - 20)
            }
        }
        
        logger.warning("⚠️ 内存警告: \(message)")
    }
    
    private func generateMemoryRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if currentMemoryUsage > memoryCriticalThreshold {
            recommendations.append("内存使用严重过高，建议重启应用")
            recommendations.append("检查是否存在内存泄漏")
        } else if currentMemoryUsage > memoryWarningThreshold {
            recommendations.append("内存使用较高，建议清理缓存")
            recommendations.append("减少同时处理的音频缓冲区数量")
        }
        
        if cacheStats.totalCacheSize > maxCacheSize * 3 / 4 {
            recommendations.append("缓存使用过多，建议清理部分缓存")
        }
        
        if objectPoolStats.values.contains(where: { $0 > 15 }) {
            recommendations.append("对象池中对象过多，可能存在资源未正确释放")
        }
        
        if recommendations.isEmpty {
            recommendations.append("内存使用正常")
        }
        
        return recommendations
    }
    
    private func cleanupAllResources() {
        clearAllCaches()
        audioBufferPool.removeAll()
        stringPool.removeAll()
        dataPool.removeAll()
        trackedObjects.removeAllObjects()
        trackedObjectsMetadata.removeAll()
    }
}

// MARK: - Supporting Data Models

/// 音频缓冲区包装器
class AudioBufferWrapper {
    private var data: UnsafeMutablePointer<Float>?
    private var capacity: Int = 0
    private var currentSize: Int = 0
    
    init(capacity: Int) {
        resize(capacity: capacity)
    }
    
    deinit {
        reset()
    }
    
    func resize(capacity: Int) {
        if capacity != self.capacity {
            reset()
            self.capacity = capacity
            self.data = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        }
        currentSize = 0
    }
    
    func reset() {
        if let data = data {
            data.deallocate()
            self.data = nil
        }
        capacity = 0
        currentSize = 0
    }
    
    func getData() -> UnsafeMutablePointer<Float>? {
        return data
    }
    
    func getCapacity() -> Int {
        return capacity
    }
}

/// 通用对象池
class ObjectPool<T> {
    private var objects: [T] = []
    private var maxSize: Int = 10
    private var factory: (() -> T)?
    private var resetHandler: ((T) -> Void)?
    private let queue = DispatchQueue(label: "com.capswriter.objectpool", attributes: .concurrent)
    
    var availableCount: Int {
        return queue.sync { objects.count }
    }
    
    func configure(initialSize: Int, maxSize: Int, factory: @escaping () -> T, reset: @escaping (T) -> Void) {
        queue.async(flags: .barrier) {
            self.maxSize = maxSize
            self.factory = factory
            self.resetHandler = reset
            
            // 预分配初始对象
            for _ in 0..<initialSize {
                self.objects.append(factory())
            }
        }
    }
    
    func acquire() -> T? {
        return queue.sync {
            if !objects.isEmpty {
                return objects.removeLast()
            }
            return factory?()
        }
    }
    
    func release(_ object: T) {
        queue.async(flags: .barrier) {
            if self.objects.count < self.maxSize {
                self.resetHandler?(object)
                self.objects.append(object)
            }
        }
    }
    
    func shrink() {
        queue.async(flags: .barrier) {
            let targetSize = max(1, self.objects.count / 2)
            while self.objects.count > targetSize {
                _ = self.objects.removeLast()
            }
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.objects.removeAll()
        }
    }
}

/// 内存缓存
class MemoryCache<Key: Hashable, Value> {
    private struct CacheItem {
        let value: Value
        let expiresAt: Date?
        let accessCount: Int
        let createdAt: Date
        
        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() > expiresAt
        }
    }
    
    private var cache: [Key: CacheItem] = [:]
    private var maxSize: Int = 100
    private var ttl: TimeInterval = 300 // 5分钟
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private let queue = DispatchQueue(label: "com.capswriter.memorycache", attributes: .concurrent)
    
    var currentSize: Int {
        return queue.sync { cache.count }
    }
    
    var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    func configure(maxSize: Int, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            self.maxSize = maxSize
            self.ttl = ttl
        }
    }
    
    func setValue(_ value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            let expiresAt = self.ttl > 0 ? Date().addingTimeInterval(self.ttl) : nil
            let item = CacheItem(value: value, expiresAt: expiresAt, accessCount: 0, createdAt: Date())
            
            self.cache[key] = item
            
            // 如果超过最大大小，移除最旧的项目
            if self.cache.count > self.maxSize {
                self.evictOldestItems()
            }
        }
    }
    
    func getValue(forKey key: Key) -> Value? {
        return queue.sync {
            if let item = cache[key] {
                if item.isExpired {
                    cache.removeValue(forKey: key)
                    missCount += 1
                    return nil
                } else {
                    hitCount += 1
                    return item.value
                }
            } else {
                missCount += 1
                return nil
            }
        }
    }
    
    func removeExpired() {
        queue.async(flags: .barrier) {
            self.cache = self.cache.filter { !$0.value.isExpired }
        }
    }
    
    func reduceSizeTo(maxSize: Int) {
        queue.async(flags: .barrier) {
            while self.cache.count > maxSize {
                self.evictOldestItems()
            }
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    private func evictOldestItems() {
        let sortedKeys = cache.keys.sorted { key1, key2 in
            let item1 = cache[key1]!
            let item2 = cache[key2]!
            return item1.createdAt < item2.createdAt
        }
        
        if let oldestKey = sortedKeys.first {
            cache.removeValue(forKey: oldestKey)
        }
    }
}

/// 追踪对象元数据
struct TrackedObjectMetadata {
    let name: String
    let createdAt: Date
    let className: String
    var additionalInfo: [String: Any]?
}

/// 内存警告级别
enum MemoryWarningLevel {
    case warning
    case critical
}

/// 内存压力级别
enum MemoryPressureLevel {
    case warning
    case critical
}

/// 内存警告
struct MemoryWarning: Identifiable {
    let id = UUID()
    let level: MemoryWarningLevel
    let message: String
    let timestamp: Date
    let memoryUsage: Double
}

/// 缓存统计信息
struct CacheStatistics {
    var audioDataCacheSize: Int = 0
    var stringCacheSize: Int = 0
    var configCacheSize: Int = 0
    var totalCacheSize: Int = 0
    var audioDataCacheHitRate: Double = 0.0
    var stringCacheHitRate: Double = 0.0
    var configCacheHitRate: Double = 0.0
}

/// 内存使用报告
struct MemoryReport {
    let currentUsage: Double
    let peakUsage: Double
    let objectPoolStats: [String: Int]
    let cacheStats: CacheStatistics
    let trackedObjectsCount: Int
    let warnings: [MemoryWarning]
    let recommendations: [String]
    let generatedAt = Date()
}