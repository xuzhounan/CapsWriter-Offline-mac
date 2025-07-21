import Foundation
import os.log
import Combine
import QuartzCore
import Darwin

/// 性能分析工具集 - 深度性能分析和诊断
/// 
/// 功能特点：
/// - 函数调用性能分析
/// - 内存分配追踪
/// - 线程执行分析
/// - 热点代码识别
/// - 性能瓶颈自动诊断
/// - 性能数据可视化支持
class ProfilerTools: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ProfilerTools()
    
    // MARK: - Published Properties
    @Published var isProfilingActive = false
    @Published var currentSession: ProfilingSession?
    @Published var completedSessions: [ProfilingSession] = []
    @Published var hotspots: [PerformanceHotspot] = []
    @Published var profilingStats = ProfilingStatistics()
    
    // MARK: - Private Properties
    private let profilingQueue = DispatchQueue(label: "com.capswriter.profiling", qos: .utility)
    private let analysisQueue = DispatchQueue(label: "com.capswriter.analysis", qos: .background)
    
    // 函数调用追踪
    private var functionCallTracker = FunctionCallTracker()
    private var memoryAllocationTracker = MemoryAllocationTracker()
    private var threadExecutionTracker = ThreadExecutionTracker()
    
    // 性能采样
    private var performanceSampler: Timer?
    private let samplingInterval: TimeInterval = 0.1 // 100ms 采样间隔
    
    // 数据存储
    private var profilingSamples: [ProfilingSample] = []
    private var functionCallSamples: [FunctionCallSample] = []
    private var memoryAllocationSamples: [MemoryAllocationSample] = []
    
    // 日志器
    private let logger = os.Logger(subsystem: "com.capswriter", category: "ProfilerTools")
    
    // 统计数据
    private var totalSamplesCollected: UInt64 = 0
    private var hotspotDetectionThreshold: Double = 0.05 // 5% 时间消耗阈值
    
    // MARK: - Initialization
    private init() {
        setupSignalHandlers()
        logger.info("🔬 ProfilerTools 初始化完成")
    }
    
    deinit {
        stopProfiling()
        logger.info("🔬 ProfilerTools 销毁")
    }
    
    // MARK: - Public Methods
    
    /// 开始性能分析
    /// - Parameter sessionName: 分析会话名称
    func startProfiling(sessionName: String = "Default Session") {
        guard !isProfilingActive else {
            logger.warning("⚠️ 性能分析已在进行中")
            return
        }
        
        logger.info("🚀 开始性能分析会话: \(sessionName)")
        
        profilingQueue.async { [weak self] in
            self?.initializeProfilingSession(sessionName: sessionName)
        }
    }
    
    /// 停止性能分析
    func stopProfiling() {
        guard isProfilingActive else {
            logger.warning("⚠️ 性能分析未在进行中")
            return
        }
        
        logger.info("🛑 停止性能分析")
        
        profilingQueue.async { [weak self] in
            self?.finalizeProfilingSession()
        }
    }
    
    /// 记录函数调用
    /// - Parameters:
    ///   - functionName: 函数名
    ///   - className: 类名
    ///   - startTime: 开始时间
    ///   - endTime: 结束时间
    func recordFunctionCall(functionName: String, className: String, startTime: Date, endTime: Date) {
        guard isProfilingActive else { return }
        
        let sample = FunctionCallSample(
            functionName: functionName,
            className: className,
            startTime: startTime,
            endTime: endTime,
            duration: endTime.timeIntervalSince(startTime),
            threadId: Thread.current.description
        )
        
        profilingQueue.async { [weak self] in
            self?.functionCallSamples.append(sample)
            self?.functionCallTracker.recordCall(sample)
        }
    }
    
    /// 记录内存分配
    /// - Parameters:
    ///   - size: 分配大小
    ///   - type: 分配类型
    ///   - location: 分配位置
    func recordMemoryAllocation(size: Int, type: String, location: String) {
        guard isProfilingActive else { return }
        
        let sample = MemoryAllocationSample(
            size: size,
            type: type,
            location: location,
            timestamp: Date(),
            threadId: Thread.current.description
        )
        
        profilingQueue.async { [weak self] in
            self?.memoryAllocationSamples.append(sample)
            self?.memoryAllocationTracker.recordAllocation(sample)
        }
    }
    
    /// 分析性能瓶颈
    /// - Returns: 性能分析报告
    func analyzePerformanceBottlenecks() -> PerformanceAnalysisReport {
        logger.info("🔍 开始性能瓶颈分析")
        
        let report = PerformanceAnalysisReport()
        
        analysisQueue.sync {
            // 分析函数调用热点
            report.functionHotspots = analyzeFunctionHotspots()
            
            // 分析内存分配模式
            report.memoryAllocationPatterns = analyzeMemoryAllocationPatterns()
            
            // 分析线程执行情况
            report.threadExecutionAnalysis = analyzeThreadExecution()
            
            // 生成优化建议
            report.optimizationRecommendations = generateOptimizationRecommendations(report)
            
            // 计算总体性能评分
            report.performanceScore = calculatePerformanceScore(report)
        }
        
        logger.info("✅ 性能瓶颈分析完成，评分: \(Int(report.performanceScore))")
        
        return report
    }
    
    /// 导出性能分析数据
    /// - Parameter format: 导出格式
    /// - Returns: 导出的数据
    func exportProfilingData(format: ProfilingDataFormat) -> Data? {
        switch format {
        case .json:
            return exportAsJSON()
        case .csv:
            return exportAsCSV()
        case .instruments:
            return exportForInstruments()
        }
    }
    
    /// 清除分析数据
    func clearProfilingData() {
        profilingQueue.async { [weak self] in
            self?.profilingSamples.removeAll()
            self?.functionCallSamples.removeAll()
            self?.memoryAllocationSamples.removeAll()
            
            self?.functionCallTracker.reset()
            self?.memoryAllocationTracker.reset()
            self?.threadExecutionTracker.reset()
            
            DispatchQueue.main.async {
                self?.completedSessions.removeAll()
                self?.hotspots.removeAll()
                self?.currentSession = nil
            }
        }
        
        logger.info("🗑️ 性能分析数据已清除")
    }
    
    // MARK: - Private Methods
    
    private func setupSignalHandlers() {
        // 设置信号处理器以捕获性能相关事件
        signal(SIGPROF, SIG_IGN) // 忽略SIGPROF信号，避免干扰
    }
    
    private func initializeProfilingSession(sessionName: String) {
        let session = ProfilingSession(
            name: sessionName,
            startTime: Date(),
            endTime: nil
        )
        
        DispatchQueue.main.async {
            self.currentSession = session
            self.isProfilingActive = true
        }
        
        // 开始数据收集
        startDataCollection()
        
        logger.info("✅ 性能分析会话已初始化: \(sessionName)")
    }
    
    private func finalizeProfilingSession() {
        stopDataCollection()
        
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        session.sampleCount = profilingSamples.count
        session.functionCallCount = functionCallSamples.count
        session.memoryAllocationCount = memoryAllocationSamples.count
        
        DispatchQueue.main.async {
            self.completedSessions.append(session)
            self.currentSession = nil
            self.isProfilingActive = false
        }
        
        // 执行分析
        analysisQueue.async { [weak self] in
            self?.performPostSessionAnalysis()
        }
        
        logger.info("✅ 性能分析会话已完成")
    }
    
    private func startDataCollection() {
        // 重置数据收集
        profilingSamples.removeAll()
        functionCallSamples.removeAll()
        memoryAllocationSamples.removeAll()
        
        // 启动性能采样定时器
        performanceSampler = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            self?.collectPerformanceSample()
        }
        
        logger.debug("🔄 数据收集已开始")
    }
    
    private func stopDataCollection() {
        performanceSampler?.invalidate()
        performanceSampler = nil
        
        logger.debug("⏹️ 数据收集已停止")
    }
    
    private func collectPerformanceSample() {
        let sample = ProfilingSample(
            timestamp: Date(),
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            threadCount: getCurrentThreadCount()
        )
        
        profilingQueue.async { [weak self] in
            self?.profilingSamples.append(sample)
            self?.totalSamplesCollected += 1
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // 获取当前CPU使用率
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
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        
        return 0.0
    }
    
    private func getCurrentThreadCount() -> Int {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if result == KERN_SUCCESS, let list = threadList {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list), vm_size_t(threadCount))
            return Int(threadCount)
        }
        
        return 0
    }
    
    private func performPostSessionAnalysis() {
        logger.info("🔬 执行会话后分析")
        
        // 检测热点
        let detectedHotspots = detectPerformanceHotspots()
        
        DispatchQueue.main.async {
            self.hotspots = detectedHotspots
            
            // 更新统计信息
            self.profilingStats = ProfilingStatistics(
                totalSessions: self.completedSessions.count,
                totalSamples: self.totalSamplesCollected,
                totalFunctionCalls: UInt64(self.functionCallSamples.count),
                totalMemoryAllocations: UInt64(self.memoryAllocationSamples.count),
                averageCPUUsage: self.calculateAverageCPUUsage(),
                averageMemoryUsage: self.calculateAverageMemoryUsage()
            )
        }
        
        logger.info("✅ 会话后分析完成")
    }
    
    private func detectPerformanceHotspots() -> [PerformanceHotspot] {
        var hotspots: [PerformanceHotspot] = []
        
        // 分析函数调用热点
        let functionStats = functionCallTracker.getStatistics()
        for (functionName, stats) in functionStats {
            let totalTime = stats.totalDuration
            let callCount = stats.callCount
            let avgTime = totalTime / Double(callCount)
            
            if totalTime > hotspotDetectionThreshold {
                let hotspot = PerformanceHotspot(
                    type: .function,
                    location: functionName,
                    impact: totalTime,
                    frequency: callCount,
                    averageTime: avgTime,
                    description: "函数 \(functionName) 消耗了 \(String(format: "%.2f", totalTime * 1000))ms"
                )
                hotspots.append(hotspot)
            }
        }
        
        // 分析内存分配热点
        let memoryStats = memoryAllocationTracker.getStatistics()
        for (allocationType, stats) in memoryStats {
            if stats.totalSize > 1024 * 1024 { // 1MB threshold
                let hotspot = PerformanceHotspot(
                    type: .memory,
                    location: allocationType,
                    impact: Double(stats.totalSize),
                    frequency: stats.allocationCount,
                    averageTime: 0,
                    description: "内存分配类型 \(allocationType) 分配了 \(stats.totalSize / 1024 / 1024)MB"
                )
                hotspots.append(hotspot)
            }
        }
        
        return hotspots.sorted { $0.impact > $1.impact }
    }
    
    private func analyzeFunctionHotspots() -> [FunctionHotspot] {
        let functionStats = functionCallTracker.getStatistics()
        
        return functionStats.map { (functionName, stats) in
            FunctionHotspot(
                functionName: functionName,
                totalTime: stats.totalDuration,
                callCount: stats.callCount,
                averageTime: stats.totalDuration / Double(stats.callCount),
                maxTime: stats.maxDuration,
                minTime: stats.minDuration
            )
        }.sorted { $0.totalTime > $1.totalTime }
    }
    
    private func analyzeMemoryAllocationPatterns() -> [MemoryAllocationPattern] {
        let memoryStats = memoryAllocationTracker.getStatistics()
        
        return memoryStats.map { (allocationType, stats) in
            MemoryAllocationPattern(
                type: allocationType,
                totalSize: stats.totalSize,
                allocationCount: stats.allocationCount,
                averageSize: stats.totalSize / stats.allocationCount,
                peakSize: stats.peakSize
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }
    
    private func analyzeThreadExecution() -> ThreadExecutionAnalysis {
        // 分析线程执行模式
        let threadStats = threadExecutionTracker.getStatistics()
        
        return ThreadExecutionAnalysis(
            totalThreads: threadStats.count,
            averageConcurrency: calculateAverageConcurrency(),
            threadUtilization: calculateThreadUtilization(),
            deadlockRisk: assessDeadlockRisk()
        )
    }
    
    private func generateOptimizationRecommendations(_ report: PerformanceAnalysisReport) -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // 基于函数热点的建议
        for hotspot in report.functionHotspots.prefix(3) {
            if hotspot.totalTime > 0.1 { // 100ms threshold
                recommendations.append(OptimizationRecommendation(
                    type: .performance,
                    priority: .high,
                    title: "优化热点函数",
                    description: "函数 \(hotspot.functionName) 消耗时间过长，建议优化算法或使用缓存",
                    expectedImprovement: "可提升 \(String(format: "%.0f", hotspot.totalTime * 100))% 性能"
                ))
            }
        }
        
        // 基于内存分配的建议
        for pattern in report.memoryAllocationPatterns.prefix(2) {
            if pattern.totalSize > 10 * 1024 * 1024 { // 10MB threshold
                recommendations.append(OptimizationRecommendation(
                    type: .memory,
                    priority: .medium,
                    title: "优化内存使用",
                    description: "类型 \(pattern.type) 分配内存过多，建议使用对象池或减少分配频率",
                    expectedImprovement: "可减少 \(pattern.totalSize / 1024 / 1024)MB 内存使用"
                ))
            }
        }
        
        return recommendations
    }
    
    private func calculatePerformanceScore(_ report: PerformanceAnalysisReport) -> Double {
        var score: Double = 100.0
        
        // 基于函数热点扣分
        let totalFunctionTime = report.functionHotspots.reduce(0) { $0 + $1.totalTime }
        score -= min(totalFunctionTime * 100, 30) // 最多扣30分
        
        // 基于内存使用扣分
        let totalMemoryUsage = report.memoryAllocationPatterns.reduce(0) { $0 + $1.totalSize }
        let memoryScore = min(Double(totalMemoryUsage) / (100 * 1024 * 1024) * 20, 20) // 最多扣20分
        score -= memoryScore
        
        // 基于线程使用扣分
        if report.threadExecutionAnalysis.deadlockRisk > 0.5 {
            score -= 10
        }
        
        return max(score, 0)
    }
    
    private func calculateAverageCPUUsage() -> Double {
        guard !profilingSamples.isEmpty else { return 0.0 }
        
        let totalCPU = profilingSamples.reduce(0.0) { $0 + $1.cpuUsage }
        return totalCPU / Double(profilingSamples.count)
    }
    
    private func calculateAverageMemoryUsage() -> Double {
        guard !profilingSamples.isEmpty else { return 0.0 }
        
        let totalMemory = profilingSamples.reduce(0.0) { $0 + $1.memoryUsage }
        return totalMemory / Double(profilingSamples.count)
    }
    
    private func calculateAverageConcurrency() -> Double {
        guard !profilingSamples.isEmpty else { return 0.0 }
        
        let totalThreads = profilingSamples.reduce(0.0) { $0 + Double($1.threadCount) }
        return totalThreads / Double(profilingSamples.count)
    }
    
    private func calculateThreadUtilization() -> Double {
        // 简化的线程利用率计算
        return calculateAverageConcurrency() / Double(ProcessInfo.processInfo.processorCount)
    }
    
    private func assessDeadlockRisk() -> Double {
        // 简化的死锁风险评估
        let concurrency = calculateAverageConcurrency()
        let utilization = calculateThreadUtilization()
        
        if concurrency > 10 && utilization > 0.8 {
            return 0.7
        } else if concurrency > 5 && utilization > 0.6 {
            return 0.4
        } else {
            return 0.1
        }
    }
    
    // MARK: - Export Methods
    
    private func exportAsJSON() -> Data? {
        let exportData = ProfilingExportData(
            sessions: completedSessions,
            samples: profilingSamples,
            functionCalls: functionCallSamples,
            memoryAllocations: memoryAllocationSamples,
            hotspots: hotspots
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    private func exportAsCSV() -> Data? {
        var csvContent = "Timestamp,CPU Usage,Memory Usage,Thread Count\n"
        
        for sample in profilingSamples {
            csvContent += "\(sample.timestamp),\(sample.cpuUsage),\(sample.memoryUsage),\(sample.threadCount)\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    private func exportForInstruments() -> Data? {
        // 导出为 Instruments 可识别的格式
        // 这里简化实现，实际可能需要更复杂的格式转换
        return exportAsJSON()
    }
}

// MARK: - Supporting Types and Classes

/// 函数调用追踪器
class FunctionCallTracker {
    private var functionStats: [String: FunctionCallStats] = [:]
    private let queue = DispatchQueue(label: "com.capswriter.function-tracker", attributes: .concurrent)
    
    func recordCall(_ sample: FunctionCallSample) {
        queue.async(flags: .barrier) {
            let key = "\(sample.className).\(sample.functionName)"
            
            if var stats = self.functionStats[key] {
                stats.callCount += 1
                stats.totalDuration += sample.duration
                stats.maxDuration = max(stats.maxDuration, sample.duration)
                stats.minDuration = min(stats.minDuration, sample.duration)
                self.functionStats[key] = stats
            } else {
                self.functionStats[key] = FunctionCallStats(
                    callCount: 1,
                    totalDuration: sample.duration,
                    maxDuration: sample.duration,
                    minDuration: sample.duration
                )
            }
        }
    }
    
    func getStatistics() -> [String: FunctionCallStats] {
        return queue.sync { functionStats }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.functionStats.removeAll()
        }
    }
}

/// 内存分配追踪器
class MemoryAllocationTracker {
    private var allocationStats: [String: MemoryAllocationStats] = [:]
    private let queue = DispatchQueue(label: "com.capswriter.memory-tracker", attributes: .concurrent)
    
    func recordAllocation(_ sample: MemoryAllocationSample) {
        queue.async(flags: .barrier) {
            if var stats = self.allocationStats[sample.type] {
                stats.allocationCount += 1
                stats.totalSize += sample.size
                stats.peakSize = max(stats.peakSize, sample.size)
                self.allocationStats[sample.type] = stats
            } else {
                self.allocationStats[sample.type] = MemoryAllocationStats(
                    allocationCount: 1,
                    totalSize: sample.size,
                    peakSize: sample.size
                )
            }
        }
    }
    
    func getStatistics() -> [String: MemoryAllocationStats] {
        return queue.sync { allocationStats }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.allocationStats.removeAll()
        }
    }
}

/// 线程执行追踪器
class ThreadExecutionTracker {
    private var threadStats: [String: ThreadStats] = [:]
    private let queue = DispatchQueue(label: "com.capswriter.thread-tracker", attributes: .concurrent)
    
    func getStatistics() -> [String: ThreadStats] {
        return queue.sync { threadStats }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.threadStats.removeAll()
        }
    }
}

// MARK: - Data Models

/// 性能分析会话
struct ProfilingSession: Identifiable, Codable {
    let id = UUID()
    let name: String
    let startTime: Date
    var endTime: Date?
    var sampleCount: Int = 0
    var functionCallCount: Int = 0
    var memoryAllocationCount: Int = 0
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

/// 性能采样数据
struct ProfilingSample: Codable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let threadCount: Int
}

/// 函数调用采样
struct FunctionCallSample: Codable {
    let functionName: String
    let className: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let threadId: String
}

/// 内存分配采样
struct MemoryAllocationSample: Codable {
    let size: Int
    let type: String
    let location: String
    let timestamp: Date
    let threadId: String
}

/// 性能热点
struct PerformanceHotspot: Identifiable {
    let id = UUID()
    let type: HotspotType
    let location: String
    let impact: Double
    let frequency: Int
    let averageTime: Double
    let description: String
}

enum HotspotType {
    case function
    case memory
    case thread
}

/// 分析统计
struct ProfilingStatistics {
    var totalSessions: Int = 0
    var totalSamples: UInt64 = 0
    var totalFunctionCalls: UInt64 = 0
    var totalMemoryAllocations: UInt64 = 0
    var averageCPUUsage: Double = 0.0
    var averageMemoryUsage: Double = 0.0
}

/// 函数调用统计
struct FunctionCallStats {
    var callCount: Int
    var totalDuration: TimeInterval
    var maxDuration: TimeInterval
    var minDuration: TimeInterval
}

/// 内存分配统计
struct MemoryAllocationStats {
    var allocationCount: Int
    var totalSize: Int
    var peakSize: Int
}

/// 线程统计
struct ThreadStats {
    var executionTime: TimeInterval = 0
    var blockedTime: TimeInterval = 0
    var contextSwitches: Int = 0
}

/// 性能分析报告
struct PerformanceAnalysisReport {
    var functionHotspots: [FunctionHotspot] = []
    var memoryAllocationPatterns: [MemoryAllocationPattern] = []
    var threadExecutionAnalysis: ThreadExecutionAnalysis = ThreadExecutionAnalysis()
    var optimizationRecommendations: [OptimizationRecommendation] = []
    var performanceScore: Double = 0.0
    var generatedAt: Date = Date()
}

/// 函数热点
struct FunctionHotspot {
    let functionName: String
    let totalTime: TimeInterval
    let callCount: Int
    let averageTime: TimeInterval
    let maxTime: TimeInterval
    let minTime: TimeInterval
}

/// 内存分配模式
struct MemoryAllocationPattern {
    let type: String
    let totalSize: Int
    let allocationCount: Int
    let averageSize: Int
    let peakSize: Int
}

/// 线程执行分析
struct ThreadExecutionAnalysis {
    var totalThreads: Int = 0
    var averageConcurrency: Double = 0.0
    var threadUtilization: Double = 0.0
    var deadlockRisk: Double = 0.0
}

/// 优化建议
struct OptimizationRecommendation {
    let type: RecommendationType
    let priority: RecommendationPriority
    let title: String
    let description: String
    let expectedImprovement: String
}

enum RecommendationType {
    case performance
    case memory
    case thread
    case architecture
}

enum RecommendationPriority {
    case high
    case medium
    case low
}

/// 导出数据格式
enum ProfilingDataFormat {
    case json
    case csv
    case instruments
}

/// 导出数据结构
struct ProfilingExportData: Codable {
    let sessions: [ProfilingSession]
    let samples: [ProfilingSample]
    let functionCalls: [FunctionCallSample]
    let memoryAllocations: [MemoryAllocationSample]
    let hotspots: [PerformanceHotspot]
}

// MARK: - Convenience Extensions

extension PerformanceHotspot: Codable {
    enum CodingKeys: String, CodingKey {
        case type, location, impact, frequency, averageTime, description
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(describing: type), forKey: .type)
        try container.encode(location, forKey: .location)
        try container.encode(impact, forKey: .impact)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(averageTime, forKey: .averageTime)
        try container.encode(description, forKey: .description)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        
        switch typeString {
        case "function": type = .function
        case "memory": type = .memory
        case "thread": type = .thread
        default: type = .function
        }
        
        location = try container.decode(String.self, forKey: .location)
        impact = try container.decode(Double.self, forKey: .impact)
        frequency = try container.decode(Int.self, forKey: .frequency)
        averageTime = try container.decode(Double.self, forKey: .averageTime)
        description = try container.decode(String.self, forKey: .description)
    }
}