import Foundation
import Combine
import os.log

/// 资源监控警告级别
enum ResourceMonitoringLevel: Int, CaseIterable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        case .critical:
            return "严重"
        }
    }
    
    var emoji: String {
        switch self {
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .critical:
            return "🚨"
        }
    }
}

/// 资源监控事件
struct ResourceMonitoringEvent {
    let id: String
    let level: ResourceMonitoringLevel
    let resourceId: String
    let resourceType: ResourceType
    let eventType: String
    let message: String
    let timestamp: Date
    let metadata: [String: Any]
    
    init(level: ResourceMonitoringLevel, resourceId: String, resourceType: ResourceType, 
         eventType: String, message: String, metadata: [String: Any] = [:]) {
        self.id = UUID().uuidString
        self.level = level
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.eventType = eventType
        self.message = message
        self.timestamp = Date()
        self.metadata = metadata
    }
}

/// 资源性能指标
struct ResourcePerformanceMetrics {
    let resourceId: String
    let resourceType: ResourceType
    let memoryUsage: Int64
    let cpuUsage: Double
    let diskUsage: Int64
    let networkUsage: Int64
    let responseTime: TimeInterval
    let errorRate: Double
    let throughput: Double
    let timestamp: Date
    
    init(resourceId: String, resourceType: ResourceType, memoryUsage: Int64 = 0, 
         cpuUsage: Double = 0.0, diskUsage: Int64 = 0, networkUsage: Int64 = 0,
         responseTime: TimeInterval = 0.0, errorRate: Double = 0.0, throughput: Double = 0.0) {
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.diskUsage = diskUsage
        self.networkUsage = networkUsage
        self.responseTime = responseTime
        self.errorRate = errorRate
        self.throughput = throughput
        self.timestamp = Date()
    }
}

/// 资源使用趋势
struct ResourceUsageTrend {
    let resourceId: String
    let timeRange: TimeInterval
    let memoryTrend: Double      // 内存使用趋势 (增长率)
    let cpuTrend: Double         // CPU使用趋势
    let errorTrend: Double       // 错误率趋势
    let performanceTrend: Double // 性能趋势
    let predictions: [String: Double] // 预测值
    let timestamp: Date
}

/// 资源诊断报告
struct ResourceDiagnosticReport {
    let resourceId: String
    let resourceType: ResourceType
    let healthScore: Double      // 健康得分 0.0 - 1.0
    let performanceScore: Double // 性能得分 0.0 - 1.0
    let recommendations: [String] // 优化建议
    let issues: [ResourceIssue]  // 发现的问题
    let metrics: ResourcePerformanceMetrics
    let trend: ResourceUsageTrend?
    let timestamp: Date
}

/// 资源问题
struct ResourceIssue {
    let id: String
    let level: ResourceMonitoringLevel
    let category: String
    let description: String
    let recommendation: String
    let impact: String
    let timestamp: Date
    
    init(level: ResourceMonitoringLevel, category: String, description: String, 
         recommendation: String, impact: String) {
        self.id = UUID().uuidString
        self.level = level
        self.category = category
        self.description = description
        self.recommendation = recommendation
        self.impact = impact
        self.timestamp = Date()
    }
}

/// 资源监控代理协议
protocol ResourceMonitoringDelegate: AnyObject {
    func resourceMonitor(_ monitor: ResourceMonitoringService, didReceiveEvent event: ResourceMonitoringEvent)
    func resourceMonitor(_ monitor: ResourceMonitoringService, didUpdateMetrics metrics: ResourcePerformanceMetrics)
    func resourceMonitor(_ monitor: ResourceMonitoringService, didDetectIssue issue: ResourceIssue)
}

/// 资源使用监控和诊断服务 - 任务3.4
/// 提供资源使用监控、性能分析、问题诊断和优化建议功能
class ResourceMonitoringService: ObservableObject, ServiceLifecycle {
    
    // MARK: - Singleton
    
    static let shared = ResourceMonitoringService()
    
    private init() {
        setupMonitoring()
        print("📊 ResourceMonitoringService 已初始化")
    }
    
    // MARK: - Published Properties
    
    @Published var isMonitoringEnabled: Bool = true
    @Published var monitoringEvents: [ResourceMonitoringEvent] = []
    @Published var performanceMetrics: [String: ResourcePerformanceMetrics] = [:]
    @Published var diagnosticReports: [String: ResourceDiagnosticReport] = [:]
    @Published var overallHealthScore: Double = 1.0
    @Published var criticalIssuesCount: Int = 0
    
    // MARK: - Delegate
    
    weak var delegate: ResourceMonitoringDelegate?
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var metricsHistory: [String: [ResourcePerformanceMetrics]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // 配置参数
    private let monitoringInterval: TimeInterval = 10.0     // 10秒监控间隔
    private let metricsHistoryLimit: Int = 100              // 保留100个历史记录
    private let eventHistoryLimit: Int = 1000               // 保留1000个事件记录
    private let healthScoreThreshold: Double = 0.7          // 健康得分警告阈值
    private let performanceScoreThreshold: Double = 0.6     // 性能得分警告阈值
    
    // 资源管理器引用
    private let resourceManager = ResourceManager.shared
    private let memoryMonitor = MemoryMonitor.shared
    
    // 日志记录
    private let logger = Logger(subsystem: "com.capswriter.resource-monitoring", category: "ResourceMonitoringService")
    
    // MARK: - Setup
    
    /// 设置监控
    private func setupMonitoring() {
        logger.info("📊 设置资源监控")
        
        // 设置定时监控
        setupPeriodicMonitoring()
        
        // 设置事件监听
        setupEventListening()
        
        // 设置内存监控代理
        setupMemoryMonitoringDelegate()
    }
    
    /// 设置定时监控
    private func setupPeriodicMonitoring() {
        logger.debug("⏰ 设置定时监控")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isMonitoringEnabled {
                Task {
                    await self.performMonitoringCycle()
                }
            }
        }
    }
    
    /// 设置事件监听
    private func setupEventListening() {
        logger.debug("📡 设置事件监听")
        
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.recordEvent(.info, resourceId: "System", resourceType: .system, 
                                eventType: "ApplicationState", message: "应用已激活")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.recordEvent(.info, resourceId: "System", resourceType: .system, 
                                eventType: "ApplicationState", message: "应用已失活")
            }
            .store(in: &cancellables)
        
        // 监听内存警告
        NotificationCenter.default.publisher(for: NSApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.recordEvent(.warning, resourceId: "System", resourceType: .memory, 
                                eventType: "MemoryWarning", message: "收到系统内存警告")
            }
            .store(in: &cancellables)
    }
    
    /// 设置内存监控代理
    private func setupMemoryMonitoringDelegate() {
        logger.debug("🧠 设置内存监控代理")
        
        memoryMonitor.delegate = self
    }
    
    // MARK: - Monitoring Operations
    
    /// 开始监控
    func startMonitoring() {
        logger.info("🔍 开始资源监控")
        
        guard !isMonitoringEnabled else { return }
        
        isMonitoringEnabled = true
        
        // 启动定时监控
        setupPeriodicMonitoring()
        
        // 启动内存监控
        memoryMonitor.startMonitoring()
        
        // 记录启动事件
        recordEvent(.info, resourceId: "ResourceMonitoringService", resourceType: .system, 
                   eventType: "ServiceControl", message: "资源监控服务已启动")
    }
    
    /// 停止监控
    func stopMonitoring() {
        logger.info("🛑 停止资源监控")
        
        guard isMonitoringEnabled else { return }
        
        isMonitoringEnabled = false
        
        // 停止定时监控
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 停止内存监控
        memoryMonitor.stopMonitoring()
        
        // 记录停止事件
        recordEvent(.info, resourceId: "ResourceMonitoringService", resourceType: .system, 
                   eventType: "ServiceControl", message: "资源监控服务已停止")
    }
    
    /// 执行监控周期
    private func performMonitoringCycle() async {
        logger.debug("🔄 执行监控周期")
        
        // 收集资源信息
        let allResources = resourceManager.getAllResourceInfo()
        
        // 为每个资源收集性能指标
        for resourceInfo in allResources {
            let metrics = await collectResourceMetrics(resourceInfo)
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMetrics(metrics)
            }
        }
        
        // 执行诊断分析
        await performDiagnosticAnalysis()
        
        // 更新整体健康得分
        await updateOverallHealthScore()
    }
    
    /// 收集资源性能指标
    private func collectResourceMetrics(_ resourceInfo: ResourceInfo) async -> ResourcePerformanceMetrics {
        logger.debug("📊 收集资源性能指标: \(resourceInfo.id)")
        
        let memoryUsage = resourceInfo.memoryUsage
        let cpuUsage = await estimateCPUUsage(for: resourceInfo)
        let diskUsage = await estimateDiskUsage(for: resourceInfo)
        let networkUsage = await estimateNetworkUsage(for: resourceInfo)
        let responseTime = await measureResponseTime(for: resourceInfo)
        let errorRate = await calculateErrorRate(for: resourceInfo)
        let throughput = await calculateThroughput(for: resourceInfo)
        
        return ResourcePerformanceMetrics(
            resourceId: resourceInfo.id,
            resourceType: resourceInfo.type,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            diskUsage: diskUsage,
            networkUsage: networkUsage,
            responseTime: responseTime,
            errorRate: errorRate,
            throughput: throughput
        )
    }
    
    /// 估算CPU使用率
    private func estimateCPUUsage(for resourceInfo: ResourceInfo) async -> Double {
        // 这里简化处理，实际应用中需要系统调用获取真实CPU使用率
        switch resourceInfo.type {
        case .recognition:
            return 0.3  // 识别服务CPU使用率较高
        case .audio:
            return 0.2  // 音频处理有一定CPU使用
        case .system:
            return 0.1  // 系统服务CPU使用率较低
        default:
            return 0.05 // 其他服务CPU使用率很低
        }
    }
    
    /// 估算磁盘使用
    private func estimateDiskUsage(for resourceInfo: ResourceInfo) async -> Int64 {
        switch resourceInfo.type {
        case .file:
            return resourceInfo.memoryUsage * 2  // 文件服务磁盘使用是内存的2倍
        case .recognition:
            return 50 * 1024 * 1024  // 识别服务约50MB磁盘使用
        default:
            return 0
        }
    }
    
    /// 估算网络使用
    private func estimateNetworkUsage(for resourceInfo: ResourceInfo) async -> Int64 {
        switch resourceInfo.type {
        case .network:
            return 1024 * 1024  // 网络服务约1MB网络使用
        default:
            return 0
        }
    }
    
    /// 测量响应时间
    private func measureResponseTime(for resourceInfo: ResourceInfo) async -> TimeInterval {
        // 模拟测量响应时间
        let startTime = Date()
        
        // 模拟操作延迟
        try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...10_000_000)) // 1-10ms
        
        let endTime = Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    /// 计算错误率
    private func calculateErrorRate(for resourceInfo: ResourceInfo) async -> Double {
        // 根据资源状态计算错误率
        switch resourceInfo.state {
        case .error:
            return 1.0  // 错误状态
        case .disposing, .disposed:
            return 0.5  // 处理中状态
        case .active, .ready:
            return 0.0  // 正常状态
        default:
            return 0.1  // 其他状态
        }
    }
    
    /// 计算吞吐量
    private func calculateThroughput(for resourceInfo: ResourceInfo) async -> Double {
        // 根据资源类型估算吞吐量
        switch resourceInfo.type {
        case .audio:
            return 16000.0  // 音频采样率
        case .recognition:
            return 100.0    // 识别速度
        case .network:
            return 1000.0   // 网络吞吐量
        default:
            return 10.0     // 默认吞吐量
        }
    }
    
    // MARK: - Diagnostic Analysis
    
    /// 执行诊断分析
    private func performDiagnosticAnalysis() async {
        logger.debug("🔍 执行诊断分析")
        
        let allResources = resourceManager.getAllResourceInfo()
        
        for resourceInfo in allResources {
            if let metrics = performanceMetrics[resourceInfo.id] {
                let report = await generateDiagnosticReport(for: resourceInfo, metrics: metrics)
                
                DispatchQueue.main.async { [weak self] in
                    self?.diagnosticReports[resourceInfo.id] = report
                    
                    // 检查严重问题
                    let criticalIssues = report.issues.filter { $0.level == .critical }
                    if !criticalIssues.isEmpty {
                        for issue in criticalIssues {
                            self?.delegate?.resourceMonitor(self!, didDetectIssue: issue)
                        }
                    }
                }
            }
        }
    }
    
    /// 生成诊断报告
    private func generateDiagnosticReport(for resourceInfo: ResourceInfo, metrics: ResourcePerformanceMetrics) async -> ResourceDiagnosticReport {
        logger.debug("📋 生成诊断报告: \(resourceInfo.id)")
        
        // 计算健康得分
        let healthScore = calculateHealthScore(for: resourceInfo, metrics: metrics)
        
        // 计算性能得分
        let performanceScore = calculatePerformanceScore(for: metrics)
        
        // 检测问题
        let issues = await detectIssues(for: resourceInfo, metrics: metrics)
        
        // 生成建议
        let recommendations = generateRecommendations(for: resourceInfo, metrics: metrics, issues: issues)
        
        // 计算使用趋势
        let trend = calculateUsageTrend(for: resourceInfo.id)
        
        return ResourceDiagnosticReport(
            resourceId: resourceInfo.id,
            resourceType: resourceInfo.type,
            healthScore: healthScore,
            performanceScore: performanceScore,
            recommendations: recommendations,
            issues: issues,
            metrics: metrics,
            trend: trend,
            timestamp: Date()
        )
    }
    
    /// 计算健康得分
    private func calculateHealthScore(for resourceInfo: ResourceInfo, metrics: ResourcePerformanceMetrics) -> Double {
        var score = 1.0
        
        // 根据资源状态扣分
        switch resourceInfo.state {
        case .active, .ready:
            score -= 0.0  // 正常状态不扣分
        case .error:
            score -= 0.5  // 错误状态扣50%
        case .disposing, .disposed:
            score -= 0.3  // 处理中状态扣30%
        case .uninitialized:
            score -= 0.2  // 未初始化状态扣20%
        default:
            score -= 0.1  // 其他状态扣10%
        }
        
        // 根据错误率扣分
        score -= metrics.errorRate * 0.3
        
        // 根据响应时间扣分
        if metrics.responseTime > 0.1 {  // 响应时间超过100ms
            score -= 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// 计算性能得分
    private func calculatePerformanceScore(for metrics: ResourcePerformanceMetrics) -> Double {
        var score = 1.0
        
        // 根据CPU使用率扣分
        if metrics.cpuUsage > 0.8 {
            score -= 0.3
        } else if metrics.cpuUsage > 0.6 {
            score -= 0.2
        } else if metrics.cpuUsage > 0.4 {
            score -= 0.1
        }
        
        // 根据内存使用扣分
        let memoryUsageRatio = Double(metrics.memoryUsage) / Double(100 * 1024 * 1024)  // 相对于100MB
        if memoryUsageRatio > 1.0 {
            score -= 0.3
        } else if memoryUsageRatio > 0.5 {
            score -= 0.2
        }
        
        // 根据响应时间扣分
        if metrics.responseTime > 0.5 {
            score -= 0.3
        } else if metrics.responseTime > 0.1 {
            score -= 0.2
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// 检测问题
    private func detectIssues(for resourceInfo: ResourceInfo, metrics: ResourcePerformanceMetrics) async -> [ResourceIssue] {
        var issues: [ResourceIssue] = []
        
        // 检查资源状态问题
        if resourceInfo.state == .error {
            issues.append(ResourceIssue(
                level: .critical,
                category: "资源状态",
                description: "资源处于错误状态",
                recommendation: "检查资源配置和依赖关系，尝试重新初始化",
                impact: "资源无法正常工作"
            ))
        }
        
        // 检查内存使用问题
        if metrics.memoryUsage > 50 * 1024 * 1024 {  // 超过50MB
            issues.append(ResourceIssue(
                level: .warning,
                category: "内存使用",
                description: "内存使用过高: \(MemoryUtils.formatMemorySize(metrics.memoryUsage))",
                recommendation: "考虑清理缓存或优化内存使用",
                impact: "可能影响系统性能"
            ))
        }
        
        // 检查CPU使用问题
        if metrics.cpuUsage > 0.8 {
            issues.append(ResourceIssue(
                level: .warning,
                category: "CPU使用",
                description: "CPU使用率过高: \(Int(metrics.cpuUsage * 100))%",
                recommendation: "优化算法或减少处理频率",
                impact: "可能影响系统响应速度"
            ))
        }
        
        // 检查响应时间问题
        if metrics.responseTime > 0.5 {
            issues.append(ResourceIssue(
                level: .warning,
                category: "响应时间",
                description: "响应时间过长: \(Int(metrics.responseTime * 1000))ms",
                recommendation: "优化处理逻辑或增加缓存",
                impact: "用户体验可能受影响"
            ))
        }
        
        // 检查错误率问题
        if metrics.errorRate > 0.1 {
            issues.append(ResourceIssue(
                level: .error,
                category: "错误率",
                description: "错误率过高: \(Int(metrics.errorRate * 100))%",
                recommendation: "检查错误日志，修复相关问题",
                impact: "功能可能不稳定"
            ))
        }
        
        return issues
    }
    
    /// 生成优化建议
    private func generateRecommendations(for resourceInfo: ResourceInfo, metrics: ResourcePerformanceMetrics, issues: [ResourceIssue]) -> [String] {
        var recommendations: [String] = []
        
        // 基于资源类型的建议
        switch resourceInfo.type {
        case .memory:
            recommendations.append("定期清理内存缓存")
            recommendations.append("使用弱引用避免循环引用")
        case .audio:
            recommendations.append("优化音频缓冲区大小")
            recommendations.append("使用音频压缩减少内存使用")
        case .recognition:
            recommendations.append("优化模型加载和缓存策略")
            recommendations.append("使用批量处理提高效率")
        case .file:
            recommendations.append("定期清理临时文件")
            recommendations.append("使用文件流避免大文件全部加载")
        case .network:
            recommendations.append("启用网络请求缓存")
            recommendations.append("使用连接池优化网络连接")
        default:
            recommendations.append("定期检查资源状态")
        }
        
        // 基于性能指标的建议
        if metrics.memoryUsage > 20 * 1024 * 1024 {  // 超过20MB
            recommendations.append("考虑实现内存分页或惰性加载")
        }
        
        if metrics.cpuUsage > 0.5 {
            recommendations.append("优化算法复杂度或使用多线程")
        }
        
        if metrics.responseTime > 0.1 {
            recommendations.append("添加缓存层或优化数据结构")
        }
        
        // 基于问题的建议
        for issue in issues {
            if !recommendations.contains(issue.recommendation) {
                recommendations.append(issue.recommendation)
            }
        }
        
        return recommendations
    }
    
    /// 计算使用趋势
    private func calculateUsageTrend(for resourceId: String) -> ResourceUsageTrend? {
        guard let history = metricsHistory[resourceId],
              history.count >= 2 else { return nil }
        
        let recentMetrics = Array(history.suffix(10))  // 最近10个数据点
        
        // 计算内存使用趋势
        let memoryValues = recentMetrics.map { Double($0.memoryUsage) }
        let memoryTrend = calculateTrend(values: memoryValues)
        
        // 计算CPU使用趋势
        let cpuValues = recentMetrics.map { $0.cpuUsage }
        let cpuTrend = calculateTrend(values: cpuValues)
        
        // 计算错误率趋势
        let errorValues = recentMetrics.map { $0.errorRate }
        let errorTrend = calculateTrend(values: errorValues)
        
        // 计算性能趋势（基于响应时间）
        let performanceValues = recentMetrics.map { 1.0 / (1.0 + $0.responseTime) }
        let performanceTrend = calculateTrend(values: performanceValues)
        
        // 生成预测
        let predictions = generatePredictions(from: recentMetrics)
        
        return ResourceUsageTrend(
            resourceId: resourceId,
            timeRange: TimeInterval(recentMetrics.count * Int(monitoringInterval)),
            memoryTrend: memoryTrend,
            cpuTrend: cpuTrend,
            errorTrend: errorTrend,
            performanceTrend: performanceTrend,
            predictions: predictions,
            timestamp: Date()
        )
    }
    
    /// 计算趋势
    private func calculateTrend(values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        let n = Double(values.count)
        let sumX = (0..<values.count).reduce(0.0) { $0 + Double($1) }
        let sumY = values.reduce(0.0, +)
        let sumXY = zip(0..<values.count, values).reduce(0.0) { $0 + Double($1.0) * $1.1 }
        let sumXX = (0..<values.count).reduce(0.0) { $0 + Double($1) * Double($1) }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    /// 生成预测
    private func generatePredictions(from metrics: [ResourcePerformanceMetrics]) -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // 预测下一个时间点的内存使用
        let memoryValues = metrics.map { Double($0.memoryUsage) }
        if let lastMemory = memoryValues.last {
            let memoryTrend = calculateTrend(values: memoryValues)
            predictions["nextMemoryUsage"] = lastMemory + memoryTrend
        }
        
        // 预测下一个时间点的CPU使用
        let cpuValues = metrics.map { $0.cpuUsage }
        if let lastCpu = cpuValues.last {
            let cpuTrend = calculateTrend(values: cpuValues)
            predictions["nextCpuUsage"] = max(0.0, min(1.0, lastCpu + cpuTrend))
        }
        
        return predictions
    }
    
    // MARK: - Metrics Management
    
    /// 更新性能指标
    private func updateMetrics(_ metrics: ResourcePerformanceMetrics) {
        performanceMetrics[metrics.resourceId] = metrics
        
        // 更新历史记录
        if metricsHistory[metrics.resourceId] == nil {
            metricsHistory[metrics.resourceId] = []
        }
        
        metricsHistory[metrics.resourceId]?.append(metrics)
        
        // 限制历史记录数量
        if let history = metricsHistory[metrics.resourceId],
           history.count > metricsHistoryLimit {
            metricsHistory[metrics.resourceId] = Array(history.suffix(metricsHistoryLimit))
        }
        
        // 通知代理
        delegate?.resourceMonitor(self, didUpdateMetrics: metrics)
    }
    
    /// 更新整体健康得分
    private func updateOverallHealthScore() async {
        let allReports = diagnosticReports.values
        
        if allReports.isEmpty {
            overallHealthScore = 1.0
            return
        }
        
        let totalScore = allReports.reduce(0.0) { $0 + $1.healthScore }
        let averageScore = totalScore / Double(allReports.count)
        
        // 计算严重问题数量
        let criticalIssues = allReports.flatMap { $0.issues }.filter { $0.level == .critical }
        
        DispatchQueue.main.async { [weak self] in
            self?.overallHealthScore = averageScore
            self?.criticalIssuesCount = criticalIssues.count
        }
    }
    
    // MARK: - Event Management
    
    /// 记录事件
    private func recordEvent(_ level: ResourceMonitoringLevel, resourceId: String, 
                           resourceType: ResourceType, eventType: String, 
                           message: String, metadata: [String: Any] = [:]) {
        let event = ResourceMonitoringEvent(
            level: level,
            resourceId: resourceId,
            resourceType: resourceType,
            eventType: eventType,
            message: message,
            metadata: metadata
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.monitoringEvents.append(event)
            
            // 限制事件历史数量
            if self.monitoringEvents.count > self.eventHistoryLimit {
                self.monitoringEvents.removeFirst(self.monitoringEvents.count - self.eventHistoryLimit)
            }
            
            // 通知代理
            self.delegate?.resourceMonitor(self, didReceiveEvent: event)
        }
        
        logger.info("\(level.emoji) [\(eventType)] \(resourceId): \(message)")
    }
    
    // MARK: - ServiceLifecycle
    
    func onAppLaunched() {
        logger.info("🚀 应用启动 - 启动资源监控服务")
        startMonitoring()
    }
    
    func onAppWillEnterForeground() {
        logger.info("📱 应用进入前台 - 恢复资源监控")
        if !isMonitoringEnabled {
            startMonitoring()
        }
    }
    
    func onAppDidEnterBackground() {
        logger.info("🔙 应用进入后台 - 继续监控")
        // 后台继续监控但降低频率
    }
    
    func onAppWillTerminate() {
        logger.info("🛑 应用即将终止 - 停止资源监控")
        stopMonitoring()
    }
    
    func onLowMemoryWarning() {
        logger.warning("⚠️ 内存警告 - 执行紧急监控")
        
        recordEvent(.warning, resourceId: "System", resourceType: .memory, 
                   eventType: "MemoryWarning", message: "收到低内存警告")
        
        // 立即执行一次监控周期
        Task {
            await performMonitoringCycle()
        }
    }
    
    func onSystemSleep() {
        logger.info("😴 系统休眠 - 暂停资源监控")
        stopMonitoring()
    }
    
    func onSystemWake() {
        logger.info("⏰ 系统唤醒 - 恢复资源监控")
        startMonitoring()
    }
    
    // MARK: - Public API
    
    /// 获取监控统计信息
    func getMonitoringStatistics() -> MonitoringStatistics {
        let events = monitoringEvents
        let eventsByLevel = Dictionary(grouping: events) { $0.level }
        let eventCounts = eventsByLevel.mapValues { $0.count }
        
        return MonitoringStatistics(
            totalEvents: events.count,
            eventsByLevel: eventCounts,
            monitoredResourcesCount: performanceMetrics.count,
            overallHealthScore: overallHealthScore,
            criticalIssuesCount: criticalIssuesCount,
            isMonitoringEnabled: isMonitoringEnabled,
            lastUpdateTime: Date()
        )
    }
    
    /// 导出监控数据
    func exportMonitoringData() -> [String: Any] {
        let statistics = getMonitoringStatistics()
        
        return [
            "statistics": [
                "totalEvents": statistics.totalEvents,
                "eventsByLevel": statistics.eventsByLevel.mapKeys { $0.rawValue },
                "monitoredResourcesCount": statistics.monitoredResourcesCount,
                "overallHealthScore": statistics.overallHealthScore,
                "criticalIssuesCount": statistics.criticalIssuesCount,
                "isMonitoringEnabled": statistics.isMonitoringEnabled,
                "lastUpdateTime": statistics.lastUpdateTime
            ],
            "recentEvents": monitoringEvents.suffix(10).map { event in
                [
                    "level": event.level.rawValue,
                    "resourceId": event.resourceId,
                    "eventType": event.eventType,
                    "message": event.message,
                    "timestamp": event.timestamp
                ]
            },
            "diagnosticReports": diagnosticReports.mapValues { report in
                [
                    "healthScore": report.healthScore,
                    "performanceScore": report.performanceScore,
                    "issuesCount": report.issues.count,
                    "recommendationsCount": report.recommendations.count,
                    "timestamp": report.timestamp
                ]
            }
        ]
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
        print("🗑️ ResourceMonitoringService 已清理")
    }
}

// MARK: - MemoryMonitorDelegate

extension ResourceMonitoringService: MemoryMonitorDelegate {
    
    func memoryMonitor(_ monitor: MemoryMonitor, didReceiveEvent event: MemoryEvent) {
        var level: ResourceMonitoringLevel
        var message: String
        
        switch event {
        case .warningLevelChanged(let from, let to):
            level = to.rawValue >= MemoryWarningLevel.critical.rawValue ? .critical : .warning
            message = "内存警告级别变化: \(from.description) -> \(to.description)"
        case .memoryLeakDetected(let objectId, let size):
            level = .error
            message = "检测到内存泄漏: \(objectId) - \(MemoryUtils.formatMemorySize(size))"
        case .memoryCleanupTriggered(let reason):
            level = .info
            message = "内存清理触发: \(reason)"
        case .memoryCleanupCompleted(let reason, let freedBytes):
            level = .info
            message = "内存清理完成: \(reason) - 释放 \(MemoryUtils.formatMemorySize(freedBytes))"
        case .memoryAllocationFailed(let objectId, let size):
            level = .critical
            message = "内存分配失败: \(objectId) - \(MemoryUtils.formatMemorySize(size))"
        case .memoryUsageSpike(let from, let to):
            level = .warning
            message = "内存使用激增: \(MemoryUtils.formatMemorySize(from)) -> \(MemoryUtils.formatMemorySize(to))"
        }
        
        recordEvent(level, resourceId: "MemoryMonitor", resourceType: .memory, 
                   eventType: "MemoryEvent", message: message)
    }
    
    func memoryMonitor(_ monitor: MemoryMonitor, didUpdateStatistics statistics: MemoryStatistics) {
        // 更新系统内存使用指标
        let memoryMetrics = ResourcePerformanceMetrics(
            resourceId: "SystemMemory",
            resourceType: .memory,
            memoryUsage: statistics.usedMemory,
            throughput: Double(statistics.totalMemory - statistics.usedMemory) // 可用内存作为吞吐量
        )
        
        updateMetrics(memoryMetrics)
    }
    
    func memoryMonitor(_ monitor: MemoryMonitor, shouldPerformCleanup level: MemoryWarningLevel) -> Bool {
        // 根据监控策略决定是否执行清理
        return level.rawValue >= MemoryWarningLevel.warning.rawValue
    }
}

// MARK: - Supporting Types

/// 监控统计信息
struct MonitoringStatistics {
    let totalEvents: Int
    let eventsByLevel: [ResourceMonitoringLevel: Int]
    let monitoredResourcesCount: Int
    let overallHealthScore: Double
    let criticalIssuesCount: Int
    let isMonitoringEnabled: Bool
    let lastUpdateTime: Date
}

// MARK: - Extensions

extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
}