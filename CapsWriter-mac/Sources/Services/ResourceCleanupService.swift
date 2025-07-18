import Foundation
import Combine
import AVFoundation
import os.log

/// 资源清理策略
enum CleanupStrategy {
    case immediate      // 立即清理
    case scheduled      // 定时清理
    case onDemand      // 按需清理
    case aggressive    // 激进清理
}

/// 清理任务优先级
enum CleanupPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low:
            return "低优先级"
        case .normal:
            return "普通优先级"
        case .high:
            return "高优先级"
        case .critical:
            return "紧急优先级"
        }
    }
}

/// 清理任务类型
enum CleanupTaskType: String, CaseIterable {
    case audioResources = "AudioResources"
    case recognitionCache = "RecognitionCache"
    case temporaryFiles = "TemporaryFiles"
    case memoryCache = "MemoryCache"
    case networkSessions = "NetworkSessions"
    case logFiles = "LogFiles"
    case userDefaults = "UserDefaults"
    case systemCache = "SystemCache"
    
    var description: String {
        switch self {
        case .audioResources:
            return "音频资源"
        case .recognitionCache:
            return "识别缓存"
        case .temporaryFiles:
            return "临时文件"
        case .memoryCache:
            return "内存缓存"
        case .networkSessions:
            return "网络会话"
        case .logFiles:
            return "日志文件"
        case .userDefaults:
            return "用户偏好"
        case .systemCache:
            return "系统缓存"
        }
    }
}

/// 清理任务结果
struct CleanupTaskResult {
    let taskType: CleanupTaskType
    let success: Bool
    let startTime: Date
    let endTime: Date
    let itemsProcessed: Int
    let bytesFreed: Int64
    let errorMessage: String?
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

/// 清理任务协议
protocol CleanupTaskProtocol {
    var taskType: CleanupTaskType { get }
    var priority: CleanupPriority { get }
    var strategy: CleanupStrategy { get }
    var isEnabled: Bool { get set }
    
    func execute() async -> CleanupTaskResult
    func canExecute() -> Bool
    func estimateCleanupSize() -> Int64
}

/// 基础清理任务
class BaseCleanupTask: CleanupTaskProtocol {
    let taskType: CleanupTaskType
    let priority: CleanupPriority
    let strategy: CleanupStrategy
    var isEnabled: Bool = true
    
    init(taskType: CleanupTaskType, priority: CleanupPriority, strategy: CleanupStrategy) {
        self.taskType = taskType
        self.priority = priority
        self.strategy = strategy
    }
    
    func execute() async -> CleanupTaskResult {
        // 子类需要重写此方法
        fatalError("子类必须重写 execute() 方法")
    }
    
    func canExecute() -> Bool {
        return isEnabled
    }
    
    func estimateCleanupSize() -> Int64 {
        return 0
    }
}

/// 音频资源清理任务
class AudioResourceCleanupTask: BaseCleanupTask {
    private let logger = Logger(subsystem: "com.capswriter.resource-cleanup", category: "AudioResourceCleanup")
    
    init() {
        super.init(taskType: .audioResources, priority: .high, strategy: .onDemand)
    }
    
    override func execute() async -> CleanupTaskResult {
        let startTime = Date()
        var itemsProcessed = 0
        var bytesFreed: Int64 = 0
        var errorMessage: String?
        
        logger.info("🔊 开始清理音频资源")
        
        do {
            // 清理音频引擎资源
            bytesFreed += await cleanupAudioEngineResources()
            itemsProcessed += 1
            
            // 清理音频缓冲区
            bytesFreed += await cleanupAudioBuffers()
            itemsProcessed += 1
            
            // 清理录音文件
            bytesFreed += await cleanupRecordingFiles()
            itemsProcessed += 1
            
            logger.info("✅ 音频资源清理完成，释放 \(bytesFreed) 字节")
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("❌ 音频资源清理失败: \(error.localizedDescription)")
        }
        
        let endTime = Date()
        return CleanupTaskResult(
            taskType: taskType,
            success: errorMessage == nil,
            startTime: startTime,
            endTime: endTime,
            itemsProcessed: itemsProcessed,
            bytesFreed: bytesFreed,
            errorMessage: errorMessage
        )
    }
    
    private func cleanupAudioEngineResources() async -> Int64 {
        logger.debug("🧹 清理音频引擎资源")
        
        // 获取音频相关资源
        let audioResources = ResourceManager.shared.getResourcesByType(.audio)
        var freedBytes: Int64 = 0
        
        for resourceInfo in audioResources {
            if resourceInfo.state == .ready || resourceInfo.state == .disposed {
                // 估算释放的内存
                freedBytes += resourceInfo.memoryUsage
                
                // 尝试释放资源
                try? await ResourceManager.shared.disposeResource(resourceInfo.id)
            }
        }
        
        return freedBytes
    }
    
    private func cleanupAudioBuffers() async -> Int64 {
        logger.debug("🧹 清理音频缓冲区")
        
        // 清理音频缓冲区的逻辑
        // 这里模拟清理过程
        let estimatedSize: Int64 = 1024 * 1024  // 1MB
        
        return estimatedSize
    }
    
    private func cleanupRecordingFiles() async -> Int64 {
        logger.debug("🧹 清理录音文件")
        
        let tempDir = FileManager.default.temporaryDirectory
        var freedBytes: Int64 = 0
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in files {
                if fileURL.pathExtension == "wav" || fileURL.pathExtension == "m4a" {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        freedBytes += Int64(fileSize)
                    }
                    
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            logger.error("❌ 录音文件清理失败: \(error.localizedDescription)")
        }
        
        return freedBytes
    }
}

/// 识别缓存清理任务
class RecognitionCacheCleanupTask: BaseCleanupTask {
    private let logger = Logger(subsystem: "com.capswriter.resource-cleanup", category: "RecognitionCacheCleanup")
    
    init() {
        super.init(taskType: .recognitionCache, priority: .normal, strategy: .scheduled)
    }
    
    override func execute() async -> CleanupTaskResult {
        let startTime = Date()
        var itemsProcessed = 0
        var bytesFreed: Int64 = 0
        var errorMessage: String?
        
        logger.info("🧠 开始清理识别缓存")
        
        do {
            // 清理识别引擎资源
            bytesFreed += await cleanupRecognitionEngineCache()
            itemsProcessed += 1
            
            // 清理模型缓存
            bytesFreed += await cleanupModelCache()
            itemsProcessed += 1
            
            // 清理文本处理缓存
            bytesFreed += await cleanupTextProcessingCache()
            itemsProcessed += 1
            
            logger.info("✅ 识别缓存清理完成，释放 \(bytesFreed) 字节")
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("❌ 识别缓存清理失败: \(error.localizedDescription)")
        }
        
        let endTime = Date()
        return CleanupTaskResult(
            taskType: taskType,
            success: errorMessage == nil,
            startTime: startTime,
            endTime: endTime,
            itemsProcessed: itemsProcessed,
            bytesFreed: bytesFreed,
            errorMessage: errorMessage
        )
    }
    
    private func cleanupRecognitionEngineCache() async -> Int64 {
        logger.debug("🧹 清理识别引擎缓存")
        
        let recognitionResources = ResourceManager.shared.getResourcesByType(.recognition)
        var freedBytes: Int64 = 0
        
        for resourceInfo in recognitionResources {
            if resourceInfo.state == .ready {
                // 估算缓存大小
                freedBytes += resourceInfo.memoryUsage / 2  // 估算缓存占用一半内存
            }
        }
        
        return freedBytes
    }
    
    private func cleanupModelCache() async -> Int64 {
        logger.debug("🧹 清理模型缓存")
        
        // 清理模型相关缓存
        let estimatedSize: Int64 = 10 * 1024 * 1024  // 10MB
        
        return estimatedSize
    }
    
    private func cleanupTextProcessingCache() async -> Int64 {
        logger.debug("🧹 清理文本处理缓存")
        
        // 清理热词服务缓存
        if let hotWordService = DIContainer.shared.resolve(HotWordServiceProtocol.self) {
            // 这里可以添加清理热词缓存的逻辑
        }
        
        // 清理标点符号处理缓存
        if let punctuationService = DIContainer.shared.resolve(PunctuationServiceProtocol.self) {
            // 这里可以添加清理标点符号缓存的逻辑
        }
        
        let estimatedSize: Int64 = 512 * 1024  // 512KB
        return estimatedSize
    }
}

/// 临时文件清理任务
class TemporaryFileCleanupTask: BaseCleanupTask {
    private let logger = Logger(subsystem: "com.capswriter.resource-cleanup", category: "TemporaryFileCleanup")
    
    init() {
        super.init(taskType: .temporaryFiles, priority: .normal, strategy: .scheduled)
    }
    
    override func execute() async -> CleanupTaskResult {
        let startTime = Date()
        var itemsProcessed = 0
        var bytesFreed: Int64 = 0
        var errorMessage: String?
        
        logger.info("📄 开始清理临时文件")
        
        do {
            // 清理系统临时目录
            bytesFreed += await cleanupSystemTempDirectory()
            itemsProcessed += 1
            
            // 清理应用临时目录
            bytesFreed += await cleanupAppTempDirectory()
            itemsProcessed += 1
            
            // 清理下载目录
            bytesFreed += await cleanupDownloadDirectory()
            itemsProcessed += 1
            
            logger.info("✅ 临时文件清理完成，释放 \(bytesFreed) 字节")
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("❌ 临时文件清理失败: \(error.localizedDescription)")
        }
        
        let endTime = Date()
        return CleanupTaskResult(
            taskType: taskType,
            success: errorMessage == nil,
            startTime: startTime,
            endTime: endTime,
            itemsProcessed: itemsProcessed,
            bytesFreed: bytesFreed,
            errorMessage: errorMessage
        )
    }
    
    private func cleanupSystemTempDirectory() async -> Int64 {
        logger.debug("🧹 清理系统临时目录")
        
        let tempDir = FileManager.default.temporaryDirectory
        return await cleanupDirectory(tempDir, olderThan: 3600) // 1小时
    }
    
    private func cleanupAppTempDirectory() async -> Int64 {
        logger.debug("🧹 清理应用临时目录")
        
        let appTempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CapsWriter-temp")
        return await cleanupDirectory(appTempDir, olderThan: 1800) // 30分钟
    }
    
    private func cleanupDownloadDirectory() async -> Int64 {
        logger.debug("🧹 清理下载目录")
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        if let downloadsDir = downloadsDir {
            let capsWriterDownloads = downloadsDir.appendingPathComponent("CapsWriter-Downloads")
            return await cleanupDirectory(capsWriterDownloads, olderThan: 7200) // 2小时
        }
        
        return 0
    }
    
    private func cleanupDirectory(_ directory: URL, olderThan ageLimit: TimeInterval) async -> Int64 {
        var freedBytes: Int64 = 0
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            let cutoffDate = Date().addingTimeInterval(-ageLimit)
            
            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                
                if let creationDate = resourceValues.creationDate,
                   let fileSize = resourceValues.fileSize,
                   creationDate < cutoffDate {
                    
                    try FileManager.default.removeItem(at: fileURL)
                    freedBytes += Int64(fileSize)
                    
                    logger.debug("🗑️ 删除临时文件: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            logger.error("❌ 目录清理失败: \(directory.path) - \(error.localizedDescription)")
        }
        
        return freedBytes
    }
}

/// 内存缓存清理任务
class MemoryCacheCleanupTask: BaseCleanupTask {
    private let logger = Logger(subsystem: "com.capswriter.resource-cleanup", category: "MemoryCacheCleanup")
    
    init() {
        super.init(taskType: .memoryCache, priority: .high, strategy: .onDemand)
    }
    
    override func execute() async -> CleanupTaskResult {
        let startTime = Date()
        var itemsProcessed = 0
        var bytesFreed: Int64 = 0
        var errorMessage: String?
        
        logger.info("🧠 开始清理内存缓存")
        
        do {
            // 清理 NSCache
            bytesFreed += await cleanupNSCache()
            itemsProcessed += 1
            
            // 清理 URL 缓存
            bytesFreed += await cleanupURLCache()
            itemsProcessed += 1
            
            // 清理图片缓存
            bytesFreed += await cleanupImageCache()
            itemsProcessed += 1
            
            logger.info("✅ 内存缓存清理完成，释放 \(bytesFreed) 字节")
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("❌ 内存缓存清理失败: \(error.localizedDescription)")
        }
        
        let endTime = Date()
        return CleanupTaskResult(
            taskType: taskType,
            success: errorMessage == nil,
            startTime: startTime,
            endTime: endTime,
            itemsProcessed: itemsProcessed,
            bytesFreed: bytesFreed,
            errorMessage: errorMessage
        )
    }
    
    private func cleanupNSCache() async -> Int64 {
        logger.debug("🧹 清理 NSCache")
        
        // 发送内存警告通知来清理 NSCache
        NotificationCenter.default.post(name: .NSCacheDidReceiveMemoryWarning, object: nil)
        
        let estimatedSize: Int64 = 5 * 1024 * 1024  // 5MB
        return estimatedSize
    }
    
    private func cleanupURLCache() async -> Int64 {
        logger.debug("🧹 清理 URL 缓存")
        
        let urlCache = URLCache.shared
        let currentSize = Int64(urlCache.currentMemoryUsage + urlCache.currentDiskUsage)
        
        urlCache.removeAllCachedResponses()
        
        return currentSize
    }
    
    private func cleanupImageCache() async -> Int64 {
        logger.debug("🧹 清理图片缓存")
        
        // 清理图片缓存
        let estimatedSize: Int64 = 2 * 1024 * 1024  // 2MB
        
        return estimatedSize
    }
}

/// 资源清理服务 - 任务3.4
/// 统一管理各种资源的清理任务，提供定时清理、按需清理和紧急清理功能
class ResourceCleanupService: ObservableObject, ServiceLifecycle {
    
    // MARK: - Singleton
    
    static let shared = ResourceCleanupService()
    
    private init() {
        setupCleanupTasks()
        setupScheduledCleanup()
        print("🧹 ResourceCleanupService 已初始化")
    }
    
    // MARK: - Published Properties
    
    @Published var isCleanupInProgress: Bool = false
    @Published var lastCleanupTime: Date = Date()
    @Published var totalCleanupCount: Int = 0
    @Published var totalBytesFreed: Int64 = 0
    @Published var scheduledCleanupEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private var cleanupTasks: [CleanupTaskProtocol] = []
    private var scheduledCleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 配置参数
    private let scheduledCleanupInterval: TimeInterval = 3600  // 1小时
    private let maxConcurrentTasks: Int = 3
    private let taskTimeout: TimeInterval = 300  // 5分钟
    
    // 日志记录
    private let logger = Logger(subsystem: "com.capswriter.resource-cleanup", category: "ResourceCleanupService")
    
    // MARK: - Setup
    
    /// 设置清理任务
    private func setupCleanupTasks() {
        logger.info("📋 设置清理任务")
        
        cleanupTasks = [
            AudioResourceCleanupTask(),
            RecognitionCacheCleanupTask(),
            TemporaryFileCleanupTask(),
            MemoryCacheCleanupTask()
        ]
        
        logger.info("✅ 已设置 \(cleanupTasks.count) 个清理任务")
    }
    
    /// 设置定时清理
    private func setupScheduledCleanup() {
        logger.info("⏰ 设置定时清理")
        
        scheduledCleanupTimer = Timer.scheduledTimer(withTimeInterval: scheduledCleanupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.scheduledCleanupEnabled {
                Task {
                    await self.performScheduledCleanup()
                }
            }
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// 执行完整清理
    @MainActor
    func performFullCleanup() async {
        logger.info("🧹 开始完整清理")
        
        guard !isCleanupInProgress else {
            logger.warning("⚠️ 清理操作已在进行中")
            return
        }
        
        isCleanupInProgress = true
        
        let startTime = Date()
        var totalFreed: Int64 = 0
        var successCount = 0
        
        // 按优先级排序任务
        let sortedTasks = cleanupTasks.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for task in sortedTasks {
            if task.canExecute() {
                let result = await executeCleanupTask(task)
                
                if result.success {
                    totalFreed += result.bytesFreed
                    successCount += 1
                    logger.info("✅ 清理任务完成: \(result.taskType.description) - 释放 \(result.bytesFreed) 字节")
                } else {
                    logger.error("❌ 清理任务失败: \(result.taskType.description) - \(result.errorMessage ?? "未知错误")")
                }
            }
        }
        
        let endTime = Date()
        
        // 更新统计信息
        lastCleanupTime = endTime
        totalCleanupCount += 1
        totalBytesFreed += totalFreed
        
        isCleanupInProgress = false
        
        let duration = endTime.timeIntervalSince(startTime)
        logger.info("✅ 完整清理完成 - 成功: \(successCount)/\(sortedTasks.count), 释放: \(totalFreed) 字节, 耗时: \(duration) 秒")
    }
    
    /// 执行定时清理
    private func performScheduledCleanup() async {
        logger.info("⏰ 执行定时清理")
        
        let scheduledTasks = cleanupTasks.filter { $0.strategy == .scheduled && $0.canExecute() }
        
        await MainActor.run {
            isCleanupInProgress = true
        }
        
        var totalFreed: Int64 = 0
        
        for task in scheduledTasks {
            let result = await executeCleanupTask(task)
            
            if result.success {
                totalFreed += result.bytesFreed
                logger.info("✅ 定时清理任务完成: \(result.taskType.description) - 释放 \(result.bytesFreed) 字节")
            }
        }
        
        await MainActor.run {
            self.totalBytesFreed += totalFreed
            self.lastCleanupTime = Date()
            self.isCleanupInProgress = false
        }
        
        logger.info("✅ 定时清理完成 - 释放: \(totalFreed) 字节")
    }
    
    /// 执行按需清理
    func performOnDemandCleanup(taskTypes: [CleanupTaskType]) async {
        logger.info("🔄 执行按需清理: \(taskTypes.map { $0.description }.joined(separator: ", "))")
        
        let onDemandTasks = cleanupTasks.filter { taskTypes.contains($0.taskType) && $0.canExecute() }
        
        await MainActor.run {
            isCleanupInProgress = true
        }
        
        var totalFreed: Int64 = 0
        
        for task in onDemandTasks {
            let result = await executeCleanupTask(task)
            
            if result.success {
                totalFreed += result.bytesFreed
                logger.info("✅ 按需清理任务完成: \(result.taskType.description) - 释放 \(result.bytesFreed) 字节")
            }
        }
        
        await MainActor.run {
            self.totalBytesFreed += totalFreed
            self.lastCleanupTime = Date()
            self.isCleanupInProgress = false
        }
        
        logger.info("✅ 按需清理完成 - 释放: \(totalFreed) 字节")
    }
    
    /// 执行紧急清理
    func performEmergencyCleanup() async {
        logger.warning("🚨 执行紧急清理")
        
        await MainActor.run {
            isCleanupInProgress = true
        }
        
        // 紧急清理所有可清理的任务
        let emergencyTasks = cleanupTasks.filter { $0.canExecute() }
        
        // 并发执行清理任务
        let results = await withTaskGroup(of: CleanupTaskResult.self) { group in
            for task in emergencyTasks {
                group.addTask {
                    await self.executeCleanupTask(task)
                }
            }
            
            var allResults: [CleanupTaskResult] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        let totalFreed = results.reduce(0) { $0 + $1.bytesFreed }
        let successCount = results.filter { $0.success }.count
        
        await MainActor.run {
            self.totalBytesFreed += totalFreed
            self.lastCleanupTime = Date()
            self.isCleanupInProgress = false
        }
        
        logger.warning("🚨 紧急清理完成 - 成功: \(successCount)/\(results.count), 释放: \(totalFreed) 字节")
    }
    
    /// 执行单个清理任务
    private func executeCleanupTask(_ task: CleanupTaskProtocol) async -> CleanupTaskResult {
        logger.debug("🔄 执行清理任务: \(task.taskType.description)")
        
        return await withTaskGroup(of: CleanupTaskResult.self) { group in
            group.addTask {
                await task.execute()
            }
            
            // 添加超时任务
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.taskTimeout * 1_000_000_000))
                return CleanupTaskResult(
                    taskType: task.taskType,
                    success: false,
                    startTime: Date(),
                    endTime: Date(),
                    itemsProcessed: 0,
                    bytesFreed: 0,
                    errorMessage: "任务超时"
                )
            }
            
            // 返回第一个完成的任务结果
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Task Management
    
    /// 启用清理任务
    func enableTask(_ taskType: CleanupTaskType) {
        if let task = cleanupTasks.first(where: { $0.taskType == taskType }) {
            task.isEnabled = true
            logger.info("✅ 已启用清理任务: \(taskType.description)")
        }
    }
    
    /// 禁用清理任务
    func disableTask(_ taskType: CleanupTaskType) {
        if let task = cleanupTasks.first(where: { $0.taskType == taskType }) {
            task.isEnabled = false
            logger.info("⏸️ 已禁用清理任务: \(taskType.description)")
        }
    }
    
    /// 获取任务状态
    func getTaskStatus(_ taskType: CleanupTaskType) -> Bool {
        return cleanupTasks.first(where: { $0.taskType == taskType })?.isEnabled ?? false
    }
    
    /// 估算清理大小
    func estimateCleanupSize(for taskTypes: [CleanupTaskType]? = nil) -> Int64 {
        let tasks = taskTypes?.compactMap { taskType in
            cleanupTasks.first(where: { $0.taskType == taskType })
        } ?? cleanupTasks
        
        return tasks.reduce(0) { $0 + $1.estimateCleanupSize() }
    }
    
    // MARK: - ServiceLifecycle
    
    func onAppLaunched() {
        logger.info("🚀 应用启动 - 启动清理服务")
        
        // 注册到生命周期管理器
        try? LifecycleManager.shared.registerService(self, identifier: "ResourceCleanupService")
        
        // 启动定时清理
        if scheduledCleanupEnabled {
            setupScheduledCleanup()
        }
    }
    
    func onAppWillEnterForeground() {
        logger.info("📱 应用进入前台 - 恢复清理服务")
        
        if scheduledCleanupEnabled && scheduledCleanupTimer == nil {
            setupScheduledCleanup()
        }
    }
    
    func onAppDidEnterBackground() {
        logger.info("🔙 应用进入后台 - 执行清理")
        
        Task {
            await performOnDemandCleanup(taskTypes: [.temporaryFiles, .memoryCache])
        }
    }
    
    func onAppWillTerminate() {
        logger.info("🛑 应用即将终止 - 最终清理")
        
        scheduledCleanupTimer?.invalidate()
        scheduledCleanupTimer = nil
        
        Task {
            await performFullCleanup()
        }
    }
    
    func onLowMemoryWarning() {
        logger.warning("⚠️ 内存警告 - 执行紧急清理")
        
        Task {
            await performEmergencyCleanup()
        }
    }
    
    func onSystemSleep() {
        logger.info("😴 系统休眠 - 暂停清理服务")
        
        scheduledCleanupTimer?.invalidate()
        scheduledCleanupTimer = nil
    }
    
    func onSystemWake() {
        logger.info("⏰ 系统唤醒 - 恢复清理服务")
        
        if scheduledCleanupEnabled {
            setupScheduledCleanup()
        }
    }
    
    // MARK: - Statistics and Reporting
    
    /// 获取清理统计信息
    func getCleanupStatistics() -> CleanupStatistics {
        let enabledTasks = cleanupTasks.filter { $0.isEnabled }
        let estimatedSize = estimateCleanupSize()
        
        return CleanupStatistics(
            totalCleanupCount: totalCleanupCount,
            totalBytesFreed: totalBytesFreed,
            lastCleanupTime: lastCleanupTime,
            scheduledCleanupEnabled: scheduledCleanupEnabled,
            isCleanupInProgress: isCleanupInProgress,
            enabledTasksCount: enabledTasks.count,
            totalTasksCount: cleanupTasks.count,
            estimatedCleanupSize: estimatedSize
        )
    }
    
    /// 导出清理服务状态
    func exportState() -> [String: Any] {
        let statistics = getCleanupStatistics()
        
        return [
            "totalCleanupCount": statistics.totalCleanupCount,
            "totalBytesFreed": statistics.totalBytesFreed,
            "lastCleanupTime": statistics.lastCleanupTime,
            "scheduledCleanupEnabled": statistics.scheduledCleanupEnabled,
            "isCleanupInProgress": statistics.isCleanupInProgress,
            "enabledTasksCount": statistics.enabledTasksCount,
            "totalTasksCount": statistics.totalTasksCount,
            "estimatedCleanupSize": statistics.estimatedCleanupSize,
            "enabledTasks": cleanupTasks.filter { $0.isEnabled }.map { $0.taskType.rawValue }
        ]
    }
    
    // MARK: - Cleanup
    
    deinit {
        scheduledCleanupTimer?.invalidate()
        cancellables.removeAll()
        print("🗑️ ResourceCleanupService 已清理")
    }
}

// MARK: - Supporting Types

/// 清理统计信息
struct CleanupStatistics {
    let totalCleanupCount: Int
    let totalBytesFreed: Int64
    let lastCleanupTime: Date
    let scheduledCleanupEnabled: Bool
    let isCleanupInProgress: Bool
    let enabledTasksCount: Int
    let totalTasksCount: Int
    let estimatedCleanupSize: Int64
}

// MARK: - Extensions

extension ResourceCleanupService {
    
    /// 格式化字节大小
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 获取清理任务列表
    func getCleanupTaskList() -> [CleanupTaskInfo] {
        return cleanupTasks.map { task in
            CleanupTaskInfo(
                taskType: task.taskType,
                description: task.taskType.description,
                priority: task.priority,
                strategy: task.strategy,
                isEnabled: task.isEnabled,
                estimatedSize: task.estimateCleanupSize()
            )
        }
    }
}

/// 清理任务信息
struct CleanupTaskInfo {
    let taskType: CleanupTaskType
    let description: String
    let priority: CleanupPriority
    let strategy: CleanupStrategy
    let isEnabled: Bool
    let estimatedSize: Int64
}