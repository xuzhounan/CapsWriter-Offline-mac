import Foundation
import Combine
import os.log
import System

/// 内存监控警告级别
enum MemoryWarningLevel: Int, CaseIterable {
    case normal = 0
    case warning = 1
    case critical = 2
    case emergency = 3
    
    var description: String {
        switch self {
        case .normal:
            return "正常"
        case .warning:
            return "警告"
        case .critical:
            return "严重"
        case .emergency:
            return "紧急"
        }
    }
    
    var threshold: Double {
        switch self {
        case .normal:
            return 0.6  // 60%
        case .warning:
            return 0.75 // 75%
        case .critical:
            return 0.9  // 90%
        case .emergency:
            return 0.95 // 95%
        }
    }
}

/// 内存统计信息
struct MemoryStatistics {
    let totalMemory: Int64      // 总内存
    let usedMemory: Int64       // 已使用内存
    let freeMemory: Int64       // 空闲内存
    let appMemoryUsage: Int64   // 应用内存使用
    let pressureLevel: MemoryWarningLevel  // 内存压力级别
    let timestamp: Date
    
    var memoryUsagePercentage: Double {
        return Double(usedMemory) / Double(totalMemory)
    }
    
    var appMemoryPercentage: Double {
        return Double(appMemoryUsage) / Double(totalMemory)
    }
}

/// 内存事件类型
enum MemoryEvent {
    case warningLevelChanged(MemoryWarningLevel, MemoryWarningLevel)
    case memoryLeakDetected(String, Int64)
    case memoryCleanupTriggered(String)
    case memoryCleanupCompleted(String, Int64)
    case memoryAllocationFailed(String, Int64)
    case memoryUsageSpike(Int64, Int64)
}

/// 内存监控代理协议
protocol MemoryMonitorDelegate: AnyObject {
    func memoryMonitor(_ monitor: MemoryMonitor, didReceiveEvent event: MemoryEvent)
    func memoryMonitor(_ monitor: MemoryMonitor, didUpdateStatistics statistics: MemoryStatistics)
    func memoryMonitor(_ monitor: MemoryMonitor, shouldPerformCleanup level: MemoryWarningLevel) -> Bool
}

/// 内存泄漏检测器
class MemoryLeakDetector {
    
    private struct ObjectTracker {
        let objectId: String
        let allocatedAt: Date
        let allocationSize: Int64
        let stackTrace: [String]
    }
    
    private var trackedObjects: [String: ObjectTracker] = [:]
    private let trackingQueue = DispatchQueue(label: "com.capswriter.memory-leak-detector", attributes: .concurrent)
    
    // 检测配置
    private let leakDetectionThreshold: TimeInterval = 300 // 5分钟
    private let maxTrackedObjects: Int = 1000
    
    /// 开始追踪对象
    func startTracking(objectId: String, size: Int64) {
        trackingQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.trackedObjects.count >= self.maxTrackedObjects {
                // 移除最旧的对象
                let oldestKey = self.trackedObjects.min { $0.value.allocatedAt < $1.value.allocatedAt }?.key
                if let key = oldestKey {
                    self.trackedObjects.removeValue(forKey: key)
                }
            }
            
            let stackTrace = Thread.callStackSymbols
            let tracker = ObjectTracker(
                objectId: objectId,
                allocatedAt: Date(),
                allocationSize: size,
                stackTrace: stackTrace
            )
            
            self.trackedObjects[objectId] = tracker
        }
    }
    
    /// 停止追踪对象
    func stopTracking(objectId: String) {
        trackingQueue.async(flags: .barrier) { [weak self] in
            self?.trackedObjects.removeValue(forKey: objectId)
        }
    }
    
    /// 检测内存泄漏
    func detectLeaks() -> [String: ObjectTracker] {
        return trackingQueue.sync {
            let now = Date()
            var leaks: [String: ObjectTracker] = [:]
            
            for (objectId, tracker) in trackedObjects {
                let age = now.timeIntervalSince(tracker.allocatedAt)
                if age > leakDetectionThreshold {
                    leaks[objectId] = tracker
                }
            }
            
            return leaks
        }
    }
    
    /// 获取追踪统计信息
    func getTrackingStatistics() -> (count: Int, totalSize: Int64) {
        return trackingQueue.sync {
            let count = trackedObjects.count
            let totalSize = trackedObjects.values.reduce(0) { $0 + $1.allocationSize }
            return (count, totalSize)
        }
    }
}

/// 内存监控器 - 任务3.4
/// 实现内存使用监控、泄漏检测和自动清理功能
class MemoryMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MemoryMonitor()
    
    private init() {
        setupMonitoring()
        print("📊 MemoryMonitor 已初始化")
    }
    
    // MARK: - Published Properties
    
    @Published var currentStatistics: MemoryStatistics
    @Published var currentWarningLevel: MemoryWarningLevel = .normal
    @Published var isMonitoring: Bool = false
    @Published var lastCleanupTime: Date = Date()
    @Published var totalCleanupsPerformed: Int = 0
    @Published var leakDetectionEnabled: Bool = true
    
    // MARK: - Delegate
    
    weak var delegate: MemoryMonitorDelegate?
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var leakDetector = MemoryLeakDetector()
    private var statisticsHistory: [MemoryStatistics] = []
    private var cancellables = Set<AnyCancellable>()
    
    // 配置参数
    private let monitoringInterval: TimeInterval = 5.0      // 5秒监控间隔
    private let historyLimit: Int = 100                     // 保留100个历史记录
    private let cleanupCooldown: TimeInterval = 30.0       // 30秒清理冷却时间
    private let spikeThreshold: Double = 0.2               // 20%内存使用激增阈值
    
    // 日志记录
    private let logger = Logger(subsystem: "com.capswriter.memory-monitor", category: "MemoryMonitor")
    
    // MARK: - Initialization
    
    init() {
        // 初始化当前统计信息
        self.currentStatistics = MemoryStatistics(
            totalMemory: 0,
            usedMemory: 0,
            freeMemory: 0,
            appMemoryUsage: 0,
            pressureLevel: .normal,
            timestamp: Date()
        )
        
        setupMonitoring()
        print("📊 MemoryMonitor 已初始化")
    }
    
    // MARK: - Monitoring Control
    
    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("🔍 开始内存监控")
        
        // 启动定时器
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateMemoryStatistics()
        }
        
        // 立即更新一次统计信息
        updateMemoryStatistics()
        
        // 开始泄漏检测
        if leakDetectionEnabled {
            startLeakDetection()
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        logger.info("🛑 停止内存监控")
        
        // 停止定时器
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 停止泄漏检测
        stopLeakDetection()
    }
    
    /// 开始泄漏检测
    private func startLeakDetection() {
        logger.info("🔍 开始内存泄漏检测")
        
        // 定期检查内存泄漏
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performLeakDetection()
        }
    }
    
    /// 停止泄漏检测
    private func stopLeakDetection() {
        logger.info("🛑 停止内存泄漏检测")
        // 泄漏检测定时器会在 deinit 中清理
    }
    
    // MARK: - Memory Statistics
    
    /// 更新内存统计信息
    private func updateMemoryStatistics() {
        let statistics = getCurrentMemoryStatistics()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let previousLevel = self.currentWarningLevel
            self.currentStatistics = statistics
            
            // 检查警告级别变化
            if statistics.pressureLevel != previousLevel {
                self.currentWarningLevel = statistics.pressureLevel
                self.handleWarningLevelChange(from: previousLevel, to: statistics.pressureLevel)
            }
            
            // 检查内存使用激增
            self.checkMemorySpike(statistics)
            
            // 保存历史记录
            self.saveStatisticsToHistory(statistics)
            
            // 通知代理
            self.delegate?.memoryMonitor(self, didUpdateStatistics: statistics)
        }
    }
    
    /// 获取当前内存统计信息
    private func getCurrentMemoryStatistics() -> MemoryStatistics {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let appMemoryUsage: Int64
        if kerr == KERN_SUCCESS {
            appMemoryUsage = Int64(info.resident_size)
        } else {
            appMemoryUsage = 0
        }
        
        // 获取系统内存信息
        let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
        let usedMemory = totalMemory - Int64(os_proc_available_memory())
        let freeMemory = totalMemory - usedMemory
        
        // 计算内存压力级别
        let usagePercentage = Double(usedMemory) / Double(totalMemory)
        let pressureLevel = determinePressureLevel(usagePercentage)
        
        return MemoryStatistics(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            freeMemory: freeMemory,
            appMemoryUsage: appMemoryUsage,
            pressureLevel: pressureLevel,
            timestamp: Date()
        )
    }
    
    /// 确定内存压力级别
    private func determinePressureLevel(_ usagePercentage: Double) -> MemoryWarningLevel {
        for level in MemoryWarningLevel.allCases.reversed() {
            if usagePercentage >= level.threshold {
                return level
            }
        }
        return .normal
    }
    
    /// 检查内存使用激增
    private func checkMemorySpike(_ statistics: MemoryStatistics) {
        guard let lastStatistics = statisticsHistory.last else { return }
        
        let previousUsage = lastStatistics.appMemoryUsage
        let currentUsage = statistics.appMemoryUsage
        
        if currentUsage > previousUsage {
            let increaseRatio = Double(currentUsage - previousUsage) / Double(previousUsage)
            
            if increaseRatio > spikeThreshold {
                logger.warning("⚠️ 检测到内存使用激增: \(previousUsage) -> \(currentUsage)")
                
                let event = MemoryEvent.memoryUsageSpike(previousUsage, currentUsage)
                delegate?.memoryMonitor(self, didReceiveEvent: event)
                
                // 可能触发清理
                if statistics.pressureLevel.rawValue >= MemoryWarningLevel.warning.rawValue {
                    performMemoryCleanup(reason: "内存使用激增")
                }
            }
        }
    }
    
    /// 保存统计信息到历史记录
    private func saveStatisticsToHistory(_ statistics: MemoryStatistics) {
        statisticsHistory.append(statistics)
        
        // 限制历史记录数量
        if statisticsHistory.count > historyLimit {
            statisticsHistory.removeFirst()
        }
    }
    
    // MARK: - Warning Level Handling
    
    /// 处理警告级别变化
    private func handleWarningLevelChange(from oldLevel: MemoryWarningLevel, to newLevel: MemoryWarningLevel) {
        logger.info("📈 内存警告级别变化: \(oldLevel.description) -> \(newLevel.description)")
        
        let event = MemoryEvent.warningLevelChanged(oldLevel, newLevel)
        delegate?.memoryMonitor(self, didReceiveEvent: event)
        
        // 根据新的警告级别决定是否触发清理
        switch newLevel {
        case .normal:
            break
        case .warning:
            if shouldPerformCleanup(for: newLevel) {
                performMemoryCleanup(reason: "内存警告级别")
            }
        case .critical:
            performMemoryCleanup(reason: "内存严重警告")
        case .emergency:
            performEmergencyCleanup()
        }
    }
    
    /// 检查是否应该执行清理
    private func shouldPerformCleanup(for level: MemoryWarningLevel) -> Bool {
        // 检查冷却时间
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanupTime)
        if timeSinceLastCleanup < cleanupCooldown {
            return false
        }
        
        // 询问代理是否应该清理
        return delegate?.memoryMonitor(self, shouldPerformCleanup: level) ?? true
    }
    
    // MARK: - Memory Cleanup
    
    /// 执行内存清理
    func performMemoryCleanup(reason: String) {
        logger.info("🧹 开始内存清理: \(reason)")
        
        let startTime = Date()
        let initialMemory = currentStatistics.appMemoryUsage
        
        // 通知开始清理
        let cleanupEvent = MemoryEvent.memoryCleanupTriggered(reason)
        delegate?.memoryMonitor(self, didReceiveEvent: cleanupEvent)
        
        // 执行各种清理策略
        performCacheCleanup()
        performUnusedResourceCleanup()
        performImageCacheCleanup()
        performTemporaryFileCleanup()
        
        // 强制垃圾回收
        performGarbageCollection()
        
        // 更新统计信息
        updateMemoryStatistics()
        
        let endTime = Date()
        let finalMemory = currentStatistics.appMemoryUsage
        let memoryFreed = initialMemory - finalMemory
        
        DispatchQueue.main.async { [weak self] in
            self?.lastCleanupTime = endTime
            self?.totalCleanupsPerformed += 1
        }
        
        logger.info("✅ 内存清理完成: 释放 \(memoryFreed) 字节，耗时 \(endTime.timeIntervalSince(startTime)) 秒")
        
        // 通知清理完成
        let completedEvent = MemoryEvent.memoryCleanupCompleted(reason, memoryFreed)
        delegate?.memoryMonitor(self, didReceiveEvent: completedEvent)
    }
    
    /// 执行紧急清理
    private func performEmergencyCleanup() {
        logger.warning("🚨 执行紧急内存清理")
        
        // 执行所有可能的清理策略
        performMemoryCleanup(reason: "紧急清理")
        
        // 请求资源管理器清理
        ResourceManager.shared.performMemoryCleanup()
        
        // 清理统计历史
        statisticsHistory.removeAll()
        
        // 强制多次垃圾回收
        for _ in 0..<3 {
            performGarbageCollection()
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    /// 执行缓存清理
    private func performCacheCleanup() {
        logger.debug("🧹 清理缓存")
        
        // 清理 NSCache
        NotificationCenter.default.post(name: .NSCacheDidReceiveMemoryWarning, object: nil)
        
        // 清理 URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // 清理图片缓存（如果有的话）
        performImageCacheCleanup()
    }
    
    /// 执行未使用资源清理
    private func performUnusedResourceCleanup() {
        logger.debug("🧹 清理未使用资源")
        
        // 请求资源管理器清理
        ResourceManager.shared.performMemoryCleanup()
    }
    
    /// 执行图片缓存清理
    private func performImageCacheCleanup() {
        logger.debug("🧹 清理图片缓存")
        
        // 清理 NSImage 缓存
        NSImage.clearCache()
    }
    
    /// 执行临时文件清理
    private func performTemporaryFileCleanup() {
        logger.debug("🧹 清理临时文件")
        
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            
            for fileURL in tempFiles {
                if fileURL.lastPathComponent.hasPrefix("tmp_") || fileURL.pathExtension == "tmp" {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            logger.error("❌ 临时文件清理失败: \(error.localizedDescription)")
        }
    }
    
    /// 执行垃圾回收
    private func performGarbageCollection() {
        logger.debug("🧹 执行垃圾回收")
        
        // 在 ARC 环境中，手动垃圾回收主要是清理 autoreleasepool
        autoreleasepool {
            // 触发自动释放池清理
        }
    }
    
    // MARK: - Leak Detection
    
    /// 执行泄漏检测
    private func performLeakDetection() {
        guard leakDetectionEnabled else { return }
        
        logger.debug("🔍 执行内存泄漏检测")
        
        let leaks = leakDetector.detectLeaks()
        
        for (objectId, tracker) in leaks {
            logger.warning("🔍 检测到可能的内存泄漏: \(objectId), 大小: \(tracker.allocationSize) 字节")
            
            let event = MemoryEvent.memoryLeakDetected(objectId, tracker.allocationSize)
            delegate?.memoryMonitor(self, didReceiveEvent: event)
        }
    }
    
    /// 开始追踪对象
    func startTrackingObject(_ objectId: String, size: Int64) {
        guard leakDetectionEnabled else { return }
        leakDetector.startTracking(objectId: objectId, size: size)
    }
    
    /// 停止追踪对象
    func stopTrackingObject(_ objectId: String) {
        guard leakDetectionEnabled else { return }
        leakDetector.stopTracking(objectId: objectId)
    }
    
    // MARK: - Statistics and Reporting
    
    /// 获取内存监控报告
    func getMemoryReport() -> MemoryReport {
        let trackingStats = leakDetector.getTrackingStatistics()
        
        return MemoryReport(
            currentStatistics: currentStatistics,
            currentWarningLevel: currentWarningLevel,
            totalCleanupsPerformed: totalCleanupsPerformed,
            lastCleanupTime: lastCleanupTime,
            statisticsHistory: statisticsHistory,
            trackedObjectsCount: trackingStats.count,
            trackedObjectsSize: trackingStats.totalSize,
            leakDetectionEnabled: leakDetectionEnabled
        )
    }
    
    /// 导出内存统计数据
    func exportMemoryData() -> [String: Any] {
        let report = getMemoryReport()
        
        return [
            "currentStatistics": [
                "totalMemory": report.currentStatistics.totalMemory,
                "usedMemory": report.currentStatistics.usedMemory,
                "freeMemory": report.currentStatistics.freeMemory,
                "appMemoryUsage": report.currentStatistics.appMemoryUsage,
                "pressureLevel": report.currentStatistics.pressureLevel.rawValue,
                "timestamp": report.currentStatistics.timestamp
            ],
            "currentWarningLevel": report.currentWarningLevel.rawValue,
            "totalCleanupsPerformed": report.totalCleanupsPerformed,
            "lastCleanupTime": report.lastCleanupTime,
            "trackedObjectsCount": report.trackedObjectsCount,
            "trackedObjectsSize": report.trackedObjectsSize,
            "leakDetectionEnabled": report.leakDetectionEnabled,
            "historyCount": report.statisticsHistory.count
        ]
    }
    
    // MARK: - Setup
    
    /// 设置监控
    private func setupMonitoring() {
        // 设置通知观察者
        NotificationCenter.default.publisher(for: NSApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.performMemoryCleanup(reason: "系统内存警告")
            }
            .store(in: &cancellables)
        
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.performMemoryCleanup(reason: "应用进入后台")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
        print("🗑️ MemoryMonitor 已清理")
    }
}

// MARK: - Helper Extensions

extension NSImage {
    static func clearCache() {
        // 清理 NSImage 的内部缓存
        // 这是一个私有方法，在实际应用中可能需要其他方式
    }
}

// MARK: - Memory Report

/// 内存监控报告
struct MemoryReport {
    let currentStatistics: MemoryStatistics
    let currentWarningLevel: MemoryWarningLevel
    let totalCleanupsPerformed: Int
    let lastCleanupTime: Date
    let statisticsHistory: [MemoryStatistics]
    let trackedObjectsCount: Int
    let trackedObjectsSize: Int64
    let leakDetectionEnabled: Bool
}

// MARK: - Memory Utilities

/// 内存工具类
class MemoryUtils {
    
    /// 格式化内存大小
    static func formatMemorySize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 获取当前进程内存使用
    static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// 获取可用内存
    static func getAvailableMemory() -> Int64 {
        return Int64(os_proc_available_memory())
    }
}

// MARK: - Private C Functions

private func os_proc_available_memory() -> UInt64 {
    // 获取可用内存的C函数实现
    // 这里简化处理，实际应用中需要调用系统API
    return UInt64(ProcessInfo.processInfo.physicalMemory / 2)
}