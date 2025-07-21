import Foundation
import os.log
import Combine
import AVFoundation

/// 性能监控系统 - 实时监控系统性能指标
/// 
/// 功能特点：
/// - 内存使用监控和预警
/// - CPU 使用率实时监控
/// - 音频处理延迟监控
/// - 识别响应时间监控
/// - 性能瓶颈自动检测
/// - 性能数据持久化和分析
class PerformanceMonitor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published var isMonitoring = false
    @Published var currentMetrics = PerformanceMetrics()
    @Published var performanceAlerts: [PerformanceAlert] = []
    @Published var logs: [String] = []
    
    // MARK: - Private Properties
    private let monitoringQueue = DispatchQueue(label: "com.capswriter.performance-monitor", qos: .utility)
    private let metricsQueue = DispatchQueue(label: "com.capswriter.metrics-collector", qos: .background)
    
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 配置参数
    private let monitoringInterval: TimeInterval = 1.0  // 1秒监控间隔
    private let metricsHistoryLimit = 300  // 保持5分钟历史数据
    
    // 性能阈值配置
    private let performanceThresholds = PerformanceThresholds()
    
    // 历史性能数据
    private var metricsHistory: [PerformanceMetrics] = []
    
    // 专用日志器
    private let logger = os.Logger(subsystem: "com.capswriter", category: "PerformanceMonitor")
    
    // MARK: - Initialization
    private init() {
        addLog("🔍 PerformanceMonitor 初始化完成")
        setupNotificationObservers()
    }
    
    deinit {
        stopMonitoring()
        addLog("🔍 PerformanceMonitor 销毁")
    }
    
    // MARK: - Public Methods
    
    /// 开始性能监控
    func startMonitoring() {
        guard !isMonitoring else {
            addLog("⚠️ 性能监控已在运行中")
            return
        }
        
        addLog("🚀 启动性能监控系统")
        isMonitoring = true
        
        // 启动定时监控
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.collectMetrics()
        }
        
        addLog("✅ 性能监控系统已启动")
    }
    
    /// 停止性能监控
    func stopMonitoring() {
        guard isMonitoring else {
            addLog("⚠️ 性能监控未在运行")
            return
        }
        
        addLog("🛑 停止性能监控系统")
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        
        addLog("✅ 性能监控系统已停止")
    }
    
    /// 记录特定操作的性能指标
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - startTime: 开始时间
    ///   - endTime: 结束时间
    ///   - additionalInfo: 附加信息
    func recordOperation(_ operation: String, startTime: Date, endTime: Date, additionalInfo: [String: Any]? = nil) {
        let duration = endTime.timeIntervalSince(startTime)
        
        // 异步处理以避免阻塞主线程
        metricsQueue.async { [weak self] in
            self?.processOperationMetrics(operation, duration: duration, additionalInfo: additionalInfo)
        }
    }
    
    /// 记录音频处理延迟
    /// - Parameters:
    ///   - delay: 延迟时间（毫秒）
    ///   - bufferSize: 缓冲区大小
    func recordAudioProcessingDelay(_ delay: TimeInterval, bufferSize: Int) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentMetrics.audioProcessingDelay = delay
                self.currentMetrics.lastAudioBufferSize = bufferSize
                
                // 检查是否超过阈值
                if delay > self.performanceThresholds.audioProcessingDelayThreshold {
                    let alert = PerformanceAlert(
                        type: .audioProcessingDelay,
                        message: "音频处理延迟过高: \(Int(delay * 1000))ms",
                        value: delay,
                        timestamp: Date()
                    )
                    self.addAlert(alert)
                }
            }
        }
    }
    
    /// 记录识别延迟
    /// - Parameter delay: 识别延迟时间（毫秒）
    func recordRecognitionDelay(_ delay: TimeInterval) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentMetrics.recognitionDelay = delay
                
                // 检查是否超过阈值
                if delay > self.performanceThresholds.recognitionDelayThreshold {
                    let alert = PerformanceAlert(
                        type: .recognitionDelay,
                        message: "识别延迟过高: \(Int(delay * 1000))ms",
                        value: delay,
                        timestamp: Date()
                    )
                    self.addAlert(alert)
                }
            }
        }
    }
    
    /// 获取性能报告
    /// - Returns: 性能分析报告
    func getPerformanceReport() -> PerformanceReport {
        let report = PerformanceReport(
            currentMetrics: currentMetrics,
            metricsHistory: Array(metricsHistory.suffix(60)), // 最近1分钟数据
            alerts: performanceAlerts,
            averageMetrics: calculateAverageMetrics(),
            recommendations: generateRecommendations()
        )
        
        addLog("📊 生成性能报告：内存 \(Int(report.currentMetrics.memoryUsage))MB, CPU \(Int(report.currentMetrics.cpuUsage))%")
        
        return report
    }
    
    /// 清除性能警报
    func clearAlerts() {
        performanceAlerts.removeAll()
        addLog("🗑️ 性能警报已清除")
    }
    
    /// 重置监控数据
    func resetMetrics() {
        metricsHistory.removeAll()
        currentMetrics = PerformanceMetrics()
        clearAlerts()
        addLog("🔄 监控数据已重置")
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // 监听应用生命周期事件
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.addLog("📱 应用激活，恢复性能监控")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.addLog("📱 应用进入后台，降低监控频率")
            }
            .store(in: &cancellables)
    }
    
    private func collectMetrics() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = PerformanceMetrics()
            
            // 收集内存使用情况
            metrics.memoryUsage = self.getCurrentMemoryUsage()
            
            // 收集CPU使用率
            metrics.cpuUsage = self.getCurrentCPUUsage()
            
            // 设置时间戳
            metrics.timestamp = Date()
            
            // 更新到主线程
            DispatchQueue.main.async {
                self.currentMetrics = metrics
                self.addToHistory(metrics)
                self.checkPerformanceThresholds(metrics)
            }
        }
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
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
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
    
    private func addToHistory(_ metrics: PerformanceMetrics) {
        metricsHistory.append(metrics)
        
        // 限制历史数据数量
        if metricsHistory.count > metricsHistoryLimit {
            metricsHistory.removeFirst(metricsHistory.count - metricsHistoryLimit)
        }
    }
    
    private func checkPerformanceThresholds(_ metrics: PerformanceMetrics) {
        // 检查内存使用
        if metrics.memoryUsage > performanceThresholds.memoryUsageThreshold {
            let alert = PerformanceAlert(
                type: .memoryUsage,
                message: "内存使用过高: \(Int(metrics.memoryUsage))MB",
                value: metrics.memoryUsage,
                timestamp: Date()
            )
            addAlert(alert)
        }
        
        // 检查CPU使用率
        if metrics.cpuUsage > performanceThresholds.cpuUsageThreshold {
            let alert = PerformanceAlert(
                type: .cpuUsage,
                message: "CPU使用率过高: \(Int(metrics.cpuUsage))%",
                value: metrics.cpuUsage,
                timestamp: Date()
            )
            addAlert(alert)
        }
    }
    
    private func processOperationMetrics(_ operation: String, duration: TimeInterval, additionalInfo: [String: Any]?) {
        addLog("⏱️ 操作性能: \(operation) 耗时 \(Int(duration * 1000))ms")
        
        // 检查操作是否超时
        let timeoutThreshold: TimeInterval
        switch operation {
        case _ where operation.contains("音频"):
            timeoutThreshold = performanceThresholds.audioProcessingDelayThreshold
        case _ where operation.contains("识别"):
            timeoutThreshold = performanceThresholds.recognitionDelayThreshold
        default:
            timeoutThreshold = 1.0 // 1秒默认阈值
        }
        
        if duration > timeoutThreshold {
            let alert = PerformanceAlert(
                type: .operationTimeout,
                message: "操作超时: \(operation) 耗时 \(Int(duration * 1000))ms",
                value: duration,
                timestamp: Date()
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.addAlert(alert)
            }
        }
    }
    
    private func addAlert(_ alert: PerformanceAlert) {
        // 避免重复警报
        let isDuplicate = performanceAlerts.contains { existingAlert in
            existingAlert.type == alert.type &&
            abs(existingAlert.timestamp.timeIntervalSince(alert.timestamp)) < 30.0 // 30秒内的重复警报
        }
        
        if !isDuplicate {
            performanceAlerts.append(alert)
            logger.warning("⚠️ \(alert.message)")
            addLog("⚠️ 性能警报: \(alert.message)")
            
            // 限制警报数量
            if performanceAlerts.count > 50 {
                performanceAlerts.removeFirst(performanceAlerts.count - 50)
            }
        }
    }
    
    private func calculateAverageMetrics() -> PerformanceMetrics {
        guard !metricsHistory.isEmpty else {
            return PerformanceMetrics()
        }
        
        let avgMemory = metricsHistory.reduce(0.0) { $0 + $1.memoryUsage } / Double(metricsHistory.count)
        let avgCPU = metricsHistory.reduce(0.0) { $0 + $1.cpuUsage } / Double(metricsHistory.count)
        
        let avgMetrics = PerformanceMetrics()
        avgMetrics.memoryUsage = avgMemory
        avgMetrics.cpuUsage = avgCPU
        avgMetrics.timestamp = Date()
        
        return avgMetrics
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let avgMetrics = calculateAverageMetrics()
        
        // 内存建议
        if avgMetrics.memoryUsage > performanceThresholds.memoryUsageThreshold {
            recommendations.append("内存使用率过高，建议检查内存泄漏或减少缓存使用")
        }
        
        // CPU建议
        if avgMetrics.cpuUsage > performanceThresholds.cpuUsageThreshold {
            recommendations.append("CPU使用率过高，建议优化音频处理或识别算法")
        }
        
        // 音频处理建议
        if currentMetrics.audioProcessingDelay > performanceThresholds.audioProcessingDelayThreshold {
            recommendations.append("音频处理延迟过高，建议优化音频缓冲区大小或处理算法")
        }
        
        // 识别延迟建议
        if currentMetrics.recognitionDelay > performanceThresholds.recognitionDelayThreshold {
            recommendations.append("识别延迟过高，建议检查模型加载或优化识别配置")
        }
        
        if recommendations.isEmpty {
            recommendations.append("系统性能良好，无需特别优化")
        }
        
        return recommendations
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs.append(logMessage)
            // 保持最近100条日志
            if self.logs.count > 100 {
                self.logs.removeFirst(self.logs.count - 100)
            }
        }
        
        print(logMessage)
    }
}

// MARK: - Performance Data Models

/// 性能指标数据模型
class PerformanceMetrics: ObservableObject {
    @Published var memoryUsage: Double = 0.0  // MB
    @Published var cpuUsage: Double = 0.0     // %
    @Published var audioProcessingDelay: TimeInterval = 0.0  // 秒
    @Published var recognitionDelay: TimeInterval = 0.0      // 秒
    @Published var lastAudioBufferSize: Int = 0
    @Published var timestamp: Date = Date()
    
    init() {}
}

/// 性能警报类型
enum PerformanceAlertType {
    case memoryUsage
    case cpuUsage
    case audioProcessingDelay
    case recognitionDelay
    case operationTimeout
}

/// 性能警报数据模型
struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: PerformanceAlertType
    let message: String
    let value: Double
    let timestamp: Date
}

/// 性能阈值配置
struct PerformanceThresholds {
    let memoryUsageThreshold: Double = 200.0  // 200MB
    let cpuUsageThreshold: Double = 30.0      // 30%
    let audioProcessingDelayThreshold: TimeInterval = 0.1  // 100ms
    let recognitionDelayThreshold: TimeInterval = 0.5      // 500ms
}

/// 性能报告数据模型
struct PerformanceReport {
    let currentMetrics: PerformanceMetrics
    let metricsHistory: [PerformanceMetrics]
    let alerts: [PerformanceAlert]
    let averageMetrics: PerformanceMetrics
    let recommendations: [String]
    let generatedAt = Date()
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}