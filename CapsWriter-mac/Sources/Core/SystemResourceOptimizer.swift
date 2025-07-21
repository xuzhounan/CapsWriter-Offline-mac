import Foundation
import os.log
import Combine
import IOKit
import IOKit.ps

/// 系统资源优化器 - CPU 和系统资源智能管理
/// 
/// 功能特点：
/// - 自适应 CPU 调度优化
/// - 动态线程池管理
/// - 系统负载感知调节
/// - 电源管理优化
/// - 热限制检测和调节
/// - 资源争用避免
class SystemResourceOptimizer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SystemResourceOptimizer()
    
    // MARK: - Published Properties
    @Published var isOptimizationActive = false
    @Published var currentSystemLoad = SystemLoadMetrics()
    @Published var optimizationSettings = OptimizationSettings()
    @Published var performanceMode: PerformanceMode = .balanced
    @Published var systemHealthStatus: SystemHealthStatus = .healthy
    
    // MARK: - Private Properties
    private let monitoringQueue = DispatchQueue(label: "com.capswriter.system-monitor", qos: .utility)
    private let optimizationQueue = DispatchQueue(label: "com.capswriter.resource-optimizer", qos: .background)
    
    // 系统监控
    private var systemMonitorTimer: Timer?
    private var thermalMonitor: ThermalStateMonitor?
    private var powerMonitor: PowerStateMonitor?
    
    // 优化管理
    private var threadPoolManager: ThreadPoolManager?
    private var cpuAffinityManager: CPUAffinityManager?
    private var memoryPressureManager: MemoryPressureManager?
    
    // 配置和阈值
    private let monitoringInterval: TimeInterval = 2.0 // 2秒监控间隔
    private let performanceThresholds = SystemPerformanceThresholds()
    
    // 统计数据
    private var optimizationHistory: [OptimizationAction] = []
    private var systemLoadHistory: [SystemLoadMetrics] = []
    
    // 日志器
    private let logger = os.Logger(subsystem: "com.capswriter", category: "SystemResourceOptimizer")
    
    // MARK: - Initialization
    private init() {
        setupSystemMonitoring()
        setupOptimizationComponents()
        logger.info("⚡ SystemResourceOptimizer 初始化完成")
    }
    
    deinit {
        stopOptimization()
        logger.info("⚡ SystemResourceOptimizer 销毁")
    }
    
    // MARK: - Public Methods
    
    /// 启动系统资源优化
    /// - Parameter mode: 性能模式
    func startOptimization(mode: PerformanceMode = .balanced) {
        guard !isOptimizationActive else {
            logger.warning("⚠️ 系统资源优化已在运行")
            return
        }
        
        logger.info("🚀 启动系统资源优化 - 模式: \(mode)")
        
        performanceMode = mode
        isOptimizationActive = true
        
        // 启动系统监控
        startSystemMonitoring()
        
        // 初始化优化设置
        applyPerformanceMode(mode)
        
        logger.info("✅ 系统资源优化已启动")
    }
    
    /// 停止系统资源优化
    func stopOptimization() {
        guard isOptimizationActive else {
            logger.warning("⚠️ 系统资源优化未在运行")
            return
        }
        
        logger.info("🛑 停止系统资源优化")
        
        stopSystemMonitoring()
        
        // 恢复默认设置
        restoreDefaultSettings()
        
        isOptimizationActive = false
        
        logger.info("✅ 系统资源优化已停止")
    }
    
    /// 切换性能模式
    /// - Parameter mode: 新的性能模式
    func switchPerformanceMode(_ mode: PerformanceMode) {
        guard isOptimizationActive else {
            logger.warning("⚠️ 优化器未启动，无法切换模式")
            return
        }
        
        logger.info("🔄 切换性能模式: \(performanceMode) -> \(mode)")
        
        performanceMode = mode
        applyPerformanceMode(mode)
        
        recordOptimizationAction(.performanceModeSwitch, details: ["newMode": String(describing: mode)])
    }
    
    /// 获取优化建议
    /// - Returns: 系统优化建议列表
    func getOptimizationRecommendations() -> [SystemOptimizationRecommendation] {
        var recommendations: [SystemOptimizationRecommendation] = []
        
        let currentLoad = getCurrentSystemLoad()
        
        // CPU 使用率建议
        if currentLoad.cpuUsage > performanceThresholds.highCPUThreshold {
            recommendations.append(SystemOptimizationRecommendation(
                type: .cpuOptimization,
                priority: .high,
                title: "降低 CPU 使用率",
                description: "当前 CPU 使用率 \(String(format: "%.1f", currentLoad.cpuUsage))% 过高，建议切换到节能模式或减少并发处理",
                expectedImpact: "可降低 CPU 使用率 20-30%"
            ))
        }
        
        // 内存使用建议
        if currentLoad.memoryUsage > performanceThresholds.highMemoryThreshold {
            recommendations.append(SystemOptimizationRecommendation(
                type: .memoryOptimization,
                priority: .medium,
                title: "优化内存使用",
                description: "当前内存使用 \(String(format: "%.1f", currentLoad.memoryUsage))MB 较高，建议清理缓存或减少缓冲区大小",
                expectedImpact: "可释放 50-100MB 内存"
            ))
        }
        
        // 热限制建议
        if systemHealthStatus == .thermalThrottling {
            recommendations.append(SystemOptimizationRecommendation(
                type: .thermalManagement,
                priority: .high,
                title: "应对热限制",
                description: "系统温度过高触发热限制，建议降低处理强度或暂停部分功能",
                expectedImpact: "避免性能严重下降"
            ))
        }
        
        // 电源管理建议
        if currentLoad.isOnBattery && performanceMode == .performance {
            recommendations.append(SystemOptimizationRecommendation(
                type: .powerManagement,
                priority: .medium,
                title: "优化电池使用",
                description: "当前使用电池供电，建议切换到节能模式以延长使用时间",
                expectedImpact: "可延长电池使用时间 30-50%"
            ))
        }
        
        return recommendations
    }
    
    /// 应用自动优化
    func applyAutoOptimization() {
        guard isOptimizationActive else { return }
        
        optimizationQueue.async { [weak self] in
            self?.executeAutoOptimization()
        }
    }
    
    /// 获取系统资源报告
    /// - Returns: 系统资源报告
    func getSystemResourceReport() -> SystemResourceReport {
        return SystemResourceReport(
            currentLoad: currentSystemLoad,
            performanceMode: performanceMode,
            healthStatus: systemHealthStatus,
            optimizationHistory: Array(optimizationHistory.suffix(20)),
            loadHistory: Array(systemLoadHistory.suffix(60)), // 最近2分钟数据
            recommendations: getOptimizationRecommendations(),
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupSystemMonitoring() {
        // 初始化热状态监控
        thermalMonitor = ThermalStateMonitor()
        thermalMonitor?.onThermalStateChanged = { [weak self] state in
            self?.handleThermalStateChange(state)
        }
        
        // 初始化电源状态监控
        powerMonitor = PowerStateMonitor()
        powerMonitor?.onPowerStateChanged = { [weak self] state in
            self?.handlePowerStateChange(state)
        }
    }
    
    private func setupOptimizationComponents() {
        // 初始化线程池管理器
        threadPoolManager = ThreadPoolManager(
            maxThreads: ProcessInfo.processInfo.processorCount * 2
        )
        
        // 初始化 CPU 亲和性管理器
        cpuAffinityManager = CPUAffinityManager()
        
        // 初始化内存压力管理器
        memoryPressureManager = MemoryPressureManager()
        memoryPressureManager?.onMemoryPressure = { [weak self] level in
            self?.handleMemoryPressure(level)
        }
    }
    
    private func startSystemMonitoring() {
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateSystemMetrics()
        }
        
        thermalMonitor?.startMonitoring()
        powerMonitor?.startMonitoring()
        memoryPressureManager?.startMonitoring()
    }
    
    private func stopSystemMonitoring() {
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        
        thermalMonitor?.stopMonitoring()
        powerMonitor?.stopMonitoring()
        memoryPressureManager?.stopMonitoring()
    }
    
    private func updateSystemMetrics() {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newMetrics = self.getCurrentSystemLoad()
            
            DispatchQueue.main.async {
                self.currentSystemLoad = newMetrics
                self.systemLoadHistory.append(newMetrics)
                
                // 保持历史数据在合理范围内
                if self.systemLoadHistory.count > 300 { // 10分钟历史
                    self.systemLoadHistory.removeFirst(self.systemLoadHistory.count - 300)
                }
                
                // 检查是否需要自动优化
                self.checkAutoOptimizationTriggers(newMetrics)
            }
        }
    }
    
    private func getCurrentSystemLoad() -> SystemLoadMetrics {
        var metrics = SystemLoadMetrics()
        
        // 获取 CPU 使用率
        metrics.cpuUsage = getCPUUsage()
        
        // 获取内存使用
        metrics.memoryUsage = getMemoryUsage()
        
        // 获取线程数
        metrics.threadCount = getThreadCount()
        
        // 获取电源状态
        metrics.isOnBattery = isRunningOnBattery()
        
        // 获取系统负载平均值
        metrics.loadAverage = getLoadAverage()
        
        // 获取磁盘 I/O
        metrics.diskIO = getDiskIOUsage()
        
        // 获取网络 I/O
        metrics.networkIO = getNetworkIOUsage()
        
        metrics.timestamp = Date()
        
        return metrics
    }
    
    private func applyPerformanceMode(_ mode: PerformanceMode) {
        switch mode {
        case .performance:
            applyPerformanceSettings()
        case .balanced:
            applyBalancedSettings()
        case .efficiency:
            applyEfficiencySettings()
        }
        
        logger.info("🎯 已应用性能模式: \(mode)")
    }
    
    private func applyPerformanceSettings() {
        optimizationSettings = OptimizationSettings(
            maxThreads: ProcessInfo.processInfo.processorCount * 2,
            threadPoolSize: 8,
            memoryBufferSize: 2048,
            processingQueueQoS: .userInitiated,
            enableCPUAffinity: true,
            enablePredictiveCaching: true,
            aggressiveOptimization: true
        )
        
        threadPoolManager?.updateConfiguration(maxThreads: optimizationSettings.maxThreads)
        cpuAffinityManager?.enableAffinity()
    }
    
    private func applyBalancedSettings() {
        optimizationSettings = OptimizationSettings(
            maxThreads: ProcessInfo.processInfo.processorCount,
            threadPoolSize: 4,
            memoryBufferSize: 1024,
            processingQueueQoS: .default,
            enableCPUAffinity: false,
            enablePredictiveCaching: true,
            aggressiveOptimization: false
        )
        
        threadPoolManager?.updateConfiguration(maxThreads: optimizationSettings.maxThreads)
        cpuAffinityManager?.disableAffinity()
    }
    
    private func applyEfficiencySettings() {
        optimizationSettings = OptimizationSettings(
            maxThreads: max(2, ProcessInfo.processInfo.processorCount / 2),
            threadPoolSize: 2,
            memoryBufferSize: 512,
            processingQueueQoS: .utility,
            enableCPUAffinity: false,
            enablePredictiveCaching: false,
            aggressiveOptimization: false
        )
        
        threadPoolManager?.updateConfiguration(maxThreads: optimizationSettings.maxThreads)
        cpuAffinityManager?.disableAffinity()
    }
    
    private func executeAutoOptimization() {
        let currentLoad = getCurrentSystemLoad()
        
        // 自适应线程数调整
        adjustThreadPoolBasedOnLoad(currentLoad)
        
        // 自适应质量控制
        adjustQualityBasedOnResources(currentLoad)
        
        // 内存压力处理
        handleMemoryPressureOptimization(currentLoad)
        
        // CPU 热限制处理
        handleThermalOptimization(currentLoad)
    }
    
    private func adjustThreadPoolBasedOnLoad(_ load: SystemLoadMetrics) {
        let targetThreads: Int
        
        if load.cpuUsage > 80 {
            // CPU 使用率过高，减少线程
            targetThreads = max(1, optimizationSettings.maxThreads - 2)
        } else if load.cpuUsage < 30 && load.loadAverage < 2.0 {
            // CPU 使用率较低，可以增加线程
            targetThreads = min(ProcessInfo.processInfo.processorCount * 2, optimizationSettings.maxThreads + 1)
        } else {
            return // 无需调整
        }
        
        if targetThreads != optimizationSettings.maxThreads {
            optimizationSettings.maxThreads = targetThreads
            threadPoolManager?.updateConfiguration(maxThreads: targetThreads)
            
            recordOptimizationAction(.threadPoolAdjustment, details: [
                "oldThreads": optimizationSettings.maxThreads,
                "newThreads": targetThreads,
                "cpuUsage": load.cpuUsage
            ])
        }
    }
    
    private func adjustQualityBasedOnResources(_ load: SystemLoadMetrics) {
        // 根据系统负载自动调整处理质量
        if load.cpuUsage > performanceThresholds.highCPUThreshold || systemHealthStatus == .thermalThrottling {
            // 降低质量以减少 CPU 负载
            recordOptimizationAction(.qualityReduction, details: [
                "reason": load.cpuUsage > performanceThresholds.highCPUThreshold ? "highCPU" : "thermal",
                "cpuUsage": load.cpuUsage
            ])
        } else if load.cpuUsage < performanceThresholds.lowCPUThreshold && systemHealthStatus == .healthy {
            // CPU 负载较低，可以提高质量
            recordOptimizationAction(.qualityIncrease, details: [
                "cpuUsage": load.cpuUsage
            ])
        }
    }
    
    private func handleMemoryPressureOptimization(_ load: SystemLoadMetrics) {
        if load.memoryUsage > performanceThresholds.highMemoryThreshold {
            // 触发内存清理
            MemoryManager.shared.performMemoryCleanup(force: true)
            
            recordOptimizationAction(.memoryCleanup, details: [
                "memoryUsage": load.memoryUsage,
                "threshold": performanceThresholds.highMemoryThreshold
            ])
        }
    }
    
    private func handleThermalOptimization(_ load: SystemLoadMetrics) {
        if systemHealthStatus == .thermalThrottling {
            // 热限制激活，降低处理强度
            switchPerformanceMode(.efficiency)
            
            recordOptimizationAction(.thermalThrottling, details: [
                "previousMode": String(describing: performanceMode),
                "cpuUsage": load.cpuUsage
            ])
        }
    }
    
    private func checkAutoOptimizationTriggers(_ metrics: SystemLoadMetrics) {
        // 检查是否需要触发自动优化
        let shouldOptimize = 
            metrics.cpuUsage > performanceThresholds.autoOptimizeCPUThreshold ||
            metrics.memoryUsage > performanceThresholds.autoOptimizeMemoryThreshold ||
            systemHealthStatus != .healthy
        
        if shouldOptimize {
            applyAutoOptimization()
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleThermalStateChange(_ state: ThermalState) {
        logger.info("🌡️ 热状态变化: \(state)")
        
        DispatchQueue.main.async {
            switch state {
            case .normal:
                self.systemHealthStatus = .healthy
            case .fair, .serious:
                self.systemHealthStatus = .thermalPressure
            case .critical:
                self.systemHealthStatus = .thermalThrottling
            }
        }
        
        // 根据热状态调整性能
        if state == .critical || state == .serious {
            switchPerformanceMode(.efficiency)
        } else if state == .normal && performanceMode == .efficiency {
            switchPerformanceMode(.balanced)
        }
    }
    
    private func handlePowerStateChange(_ state: PowerState) {
        logger.info("🔋 电源状态变化: \(state)")
        
        DispatchQueue.main.async {
            self.currentSystemLoad.isOnBattery = (state == .battery)
        }
        
        // 根据电源状态自动调整性能模式
        if state == .battery && performanceMode == .performance {
            switchPerformanceMode(.balanced)
        } else if state == .ac && performanceMode == .efficiency {
            switchPerformanceMode(.balanced)
        }
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) {
        logger.warning("🧠 内存压力: \(level)")
        
        switch level {
        case .normal:
            break
        case .warning:
            MemoryManager.shared.performMemoryCleanup(force: false)
        case .critical:
            MemoryManager.shared.performMemoryCleanup(force: true)
            switchPerformanceMode(.efficiency)
        }
        
        recordOptimizationAction(.memoryPressureResponse, details: [
            "level": String(describing: level)
        ])
    }
    
    // MARK: - System Metrics Collection
    
    private func getCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo))
        }
        
        var totalUsage: Double = 0.0
        
        for i in 0..<Int(numCpus) {
            let cpu_info = info.advanced(by: i * Int(CPU_STATE_MAX)).assumingMemoryBound(to: integer_t.self)
            let user = Double(cpu_info[Int(CPU_STATE_USER)])
            let system = Double(cpu_info[Int(CPU_STATE_SYSTEM)])
            let nice = Double(cpu_info[Int(CPU_STATE_NICE)])
            let idle = Double(cpu_info[Int(CPU_STATE_IDLE)])
            let total = user + system + nice + idle
            
            if total > 0 {
                totalUsage += (user + system + nice) / total * 100.0
            }
        }
        
        return totalUsage / Double(numCpus)
    }
    
    private func getMemoryUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        
        return 0.0
    }
    
    private func getThreadCount() -> Int {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if result == KERN_SUCCESS, let list = threadList {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list), vm_size_t(threadCount))
            return Int(threadCount)
        }
        
        return 0
    }
    
    private func isRunningOnBattery() -> Bool {
        // 检查电源状态
        return powerMonitor?.currentState == .battery
    }
    
    private func getLoadAverage() -> Double {
        var loadavg: [Double] = [0.0, 0.0, 0.0]
        if getloadavg(&loadavg, 3) != -1 {
            return loadavg[0] // 1分钟平均负载
        }
        return 0.0
    }
    
    private func getDiskIOUsage() -> Double {
        // 简化的磁盘 I/O 监控
        return 0.0 // 实际实现需要更复杂的系统调用
    }
    
    private func getNetworkIOUsage() -> Double {
        // 简化的网络 I/O 监控
        return 0.0 // 实际实现需要更复杂的系统调用
    }
    
    private func restoreDefaultSettings() {
        threadPoolManager?.updateConfiguration(maxThreads: ProcessInfo.processInfo.processorCount)
        cpuAffinityManager?.disableAffinity()
    }
    
    private func recordOptimizationAction(_ action: OptimizationActionType, details: [String: Any] = [:]) {
        let optimizationAction = OptimizationAction(
            type: action,
            timestamp: Date(),
            details: details,
            systemLoad: currentSystemLoad
        )
        
        optimizationHistory.append(optimizationAction)
        
        // 限制历史记录数量
        if optimizationHistory.count > 100 {
            optimizationHistory.removeFirst(optimizationHistory.count - 100)
        }
        
        logger.info("🎯 记录优化操作: \(action)")
    }
}

// MARK: - Supporting Components

/// 线程池管理器
class ThreadPoolManager {
    private var maxThreads: Int
    private var currentThreads: Int = 0
    private let queue = DispatchQueue(label: "com.capswriter.threadpool", attributes: .concurrent)
    
    init(maxThreads: Int) {
        self.maxThreads = maxThreads
    }
    
    func updateConfiguration(maxThreads: Int) {
        queue.async(flags: .barrier) {
            self.maxThreads = maxThreads
        }
    }
    
    func acquireThread() -> Bool {
        return queue.sync {
            if currentThreads < maxThreads {
                currentThreads += 1
                return true
            }
            return false
        }
    }
    
    func releaseThread() {
        queue.async(flags: .barrier) {
            self.currentThreads = max(0, self.currentThreads - 1)
        }
    }
}

/// CPU 亲和性管理器
class CPUAffinityManager {
    private var affinityEnabled = false
    
    func enableAffinity() {
        affinityEnabled = true
        // 实际实现需要系统调用来设置 CPU 亲和性
    }
    
    func disableAffinity() {
        affinityEnabled = false
        // 恢复默认 CPU 调度
    }
}

/// 内存压力管理器
class MemoryPressureManager {
    var onMemoryPressure: ((MemoryPressureLevel) -> Void)?
    private var pressureSource: DispatchSourceMemoryPressure?
    
    func startMonitoring() {
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        pressureSource?.setEventHandler { [weak self] in
            let event = self?.pressureSource?.mask ?? []
            if event.contains(.critical) {
                self?.onMemoryPressure?(.critical)
            } else if event.contains(.warning) {
                self?.onMemoryPressure?(.warning)
            }
        }
        
        pressureSource?.resume()
    }
    
    func stopMonitoring() {
        pressureSource?.cancel()
        pressureSource = nil
    }
}

/// 热状态监控器
class ThermalStateMonitor {
    var onThermalStateChanged: ((ThermalState) -> Void)?
    private var notificationCenter: NotificationCenter?
    
    func startMonitoring() {
        notificationCenter = NotificationCenter.default
        // 实际实现需要监听系统热状态通知
    }
    
    func stopMonitoring() {
        // 取消监听
    }
}

/// 电源状态监控器
class PowerStateMonitor {
    var onPowerStateChanged: ((PowerState) -> Void)?
    var currentState: PowerState = .ac
    
    func startMonitoring() {
        // 实际实现需要监听电源状态变化
    }
    
    func stopMonitoring() {
        // 取消监听
    }
}

// MARK: - Data Models and Enums

/// 性能模式
enum PerformanceMode: CaseIterable {
    case performance  // 高性能模式
    case balanced     // 平衡模式
    case efficiency   // 节能模式
}

/// 系统健康状态
enum SystemHealthStatus {
    case healthy
    case thermalPressure
    case thermalThrottling
    case memoryPressure
    case highCPULoad
}

/// 热状态
enum ThermalState {
    case normal
    case fair
    case serious
    case critical
}

/// 电源状态
enum PowerState {
    case ac      // 交流电
    case battery // 电池
}

/// 内存压力级别
enum MemoryPressureLevel {
    case normal
    case warning
    case critical
}

/// 系统负载指标
struct SystemLoadMetrics {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var threadCount: Int = 0
    var isOnBattery: Bool = false
    var loadAverage: Double = 0.0
    var diskIO: Double = 0.0
    var networkIO: Double = 0.0
    var timestamp: Date = Date()
}

/// 优化设置
struct OptimizationSettings {
    var maxThreads: Int = 4
    var threadPoolSize: Int = 4
    var memoryBufferSize: Int = 1024
    var processingQueueQoS: DispatchQoS = .default
    var enableCPUAffinity: Bool = false
    var enablePredictiveCaching: Bool = true
    var aggressiveOptimization: Bool = false
}

/// 系统性能阈值
struct SystemPerformanceThresholds {
    let highCPUThreshold: Double = 80.0
    let lowCPUThreshold: Double = 20.0
    let highMemoryThreshold: Double = 200.0
    let autoOptimizeCPUThreshold: Double = 70.0
    let autoOptimizeMemoryThreshold: Double = 150.0
}

/// 优化操作类型
enum OptimizationActionType {
    case performanceModeSwitch
    case threadPoolAdjustment
    case qualityReduction
    case qualityIncrease
    case memoryCleanup
    case thermalThrottling
    case memoryPressureResponse
}

/// 优化操作记录
struct OptimizationAction {
    let type: OptimizationActionType
    let timestamp: Date
    let details: [String: Any]
    let systemLoad: SystemLoadMetrics
}

/// 系统优化建议
struct SystemOptimizationRecommendation {
    let type: OptimizationType
    let priority: RecommendationPriority
    let title: String
    let description: String
    let expectedImpact: String
}

enum OptimizationType {
    case cpuOptimization
    case memoryOptimization
    case thermalManagement
    case powerManagement
    case threadOptimization
}

enum RecommendationPriority {
    case high
    case medium
    case low
}

/// 系统资源报告
struct SystemResourceReport {
    let currentLoad: SystemLoadMetrics
    let performanceMode: PerformanceMode
    let healthStatus: SystemHealthStatus
    let optimizationHistory: [OptimizationAction]
    let loadHistory: [SystemLoadMetrics]
    let recommendations: [SystemOptimizationRecommendation]
    let generatedAt: Date
}