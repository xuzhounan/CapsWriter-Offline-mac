#!/usr/bin/env swift

import Foundation
import Combine
import os.log

// MARK: - Performance Test Configuration

struct PerformanceTestConfig {
    static let testDuration: TimeInterval = 60.0       // 1分钟测试
    static let operationCount: Int = 1000              // 操作次数
    static let memoryThreshold: Int64 = 100 * 1024 * 1024  // 100MB内存阈值
    static let leakDetectionInterval: TimeInterval = 10.0   // 泄漏检测间隔
}

// MARK: - Test Results

struct PerformanceTestResult {
    let testName: String
    let duration: TimeInterval
    let operationCount: Int
    let throughput: Double
    let avgResponseTime: TimeInterval
    let memoryUsageBefore: Int64
    let memoryUsageAfter: Int64
    let memoryLeak: Int64
    let peakMemoryUsage: Int64
    let errors: [String]
    let timestamp: Date
    
    var isSuccess: Bool {
        return errors.isEmpty && memoryLeak < PerformanceTestConfig.memoryThreshold / 10
    }
    
    var memoryLeakFormatted: String {
        return ByteCountFormatter().string(fromByteCount: memoryLeak)
    }
}

// MARK: - Memory Leak Detector

class TestMemoryLeakDetector {
    var initialMemory: Int64 = 0
    private var peakMemory: Int64 = 0
    private var samples: [Int64] = []
    
    func startMonitoring() {
        initialMemory = getCurrentMemoryUsage()
        peakMemory = initialMemory
        samples = [initialMemory]
        print("🔍 开始内存监控 - 初始内存: \(ByteCountFormatter().string(fromByteCount: initialMemory))")
    }
    
    func recordSample() {
        let current = getCurrentMemoryUsage()
        samples.append(current)
        if current > peakMemory {
            peakMemory = current
        }
    }
    
    func stopMonitoring() -> (leak: Int64, peak: Int64) {
        let final = getCurrentMemoryUsage()
        let leak = final - initialMemory
        
        print("🔍 内存监控结束")
        print("   初始内存: \(ByteCountFormatter().string(fromByteCount: initialMemory))")
        print("   最终内存: \(ByteCountFormatter().string(fromByteCount: final))")
        print("   峰值内存: \(ByteCountFormatter().string(fromByteCount: peakMemory))")
        print("   内存泄漏: \(ByteCountFormatter().string(fromByteCount: leak))")
        
        return (leak, peakMemory)
    }
    
    func getCurrentMemoryUsage() -> Int64 {
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
}

// MARK: - Resource Manager Performance Tests

class ResourceManagerPerformanceTests {
    
    private let logger = Logger(subsystem: "com.capswriter.performance-test", category: "ResourceManagerTests")
    
    // MARK: - Test Cases
    
    func runAllTests() async {
        print("🚀 开始资源管理器性能测试")
        print("=" * 60)
        
        var results: [PerformanceTestResult] = []
        
        // 测试1: 资源注册和解析性能
        results.append(testResourceRegistrationPerformance())
        
        // 测试2: 资源生命周期管理性能
        results.append(await testResourceLifecyclePerformance())
        
        // 测试3: 内存监控器性能
        results.append(testMemoryMonitorPerformance())
        
        // 测试4: 资源清理服务性能
        results.append(await testResourceCleanupPerformance())
        
        // 测试5: 并发访问性能
        results.append(testConcurrentAccessPerformance())
        
        // 测试6: 长期运行内存泄漏测试
        results.append(await testLongRunningMemoryLeaks())
        
        // 生成测试报告
        generateTestReport(results)
    }
    
    // MARK: - Test 1: Resource Registration Performance
    
    func testResourceRegistrationPerformance() -> PerformanceTestResult {
        print("\n📋 测试1: 资源注册和解析性能")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        // 模拟资源管理器
        let resourceManager = MockResourceManager()
        
        // 注册大量资源
        for i in 0..<PerformanceTestConfig.operationCount {
            do {
                let resource = MockResource(id: "TestResource_\(i)")
                try resourceManager.register(resource)
                
                // 解析资源
                let _ = resourceManager.resolve(resource.resourceId)
                
                if i % 100 == 0 {
                    leakDetector.recordSample()
                }
            } catch {
                errors.append("注册资源失败: \(i) - \(error)")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "资源注册和解析性能",
            duration: duration,
            operationCount: PerformanceTestConfig.operationCount,
            throughput: Double(PerformanceTestConfig.operationCount) / duration,
            avgResponseTime: duration / Double(PerformanceTestConfig.operationCount),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test 2: Resource Lifecycle Performance
    
    func testResourceLifecyclePerformance() async -> PerformanceTestResult {
        print("\n🔄 测试2: 资源生命周期管理性能")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        let resourceManager = MockResourceManager()
        
        // 创建、初始化、激活、停用、释放资源
        for i in 0..<PerformanceTestConfig.operationCount / 10 {
            do {
                let resource = MockResource(id: "LifecycleResource_\(i)")
                
                // 注册
                try resourceManager.register(resource)
                
                // 初始化
                try await resourceManager.initialize(resource.resourceId)
                
                // 激活
                try resourceManager.activate(resource.resourceId)
                
                // 停用
                try resourceManager.deactivate(resource.resourceId)
                
                // 释放
                try await resourceManager.dispose(resource.resourceId)
                
                if i % 10 == 0 {
                    leakDetector.recordSample()
                }
            } catch {
                errors.append("生命周期测试失败: \(i) - \(error)")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "资源生命周期管理性能",
            duration: duration,
            operationCount: PerformanceTestConfig.operationCount / 10,
            throughput: Double(PerformanceTestConfig.operationCount / 10) / duration,
            avgResponseTime: duration / Double(PerformanceTestConfig.operationCount / 10),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test 3: Memory Monitor Performance
    
    func testMemoryMonitorPerformance() -> PerformanceTestResult {
        print("\n🧠 测试3: 内存监控器性能")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        let memoryMonitor = MockMemoryMonitor()
        
        // 开始监控
        memoryMonitor.startMonitoring()
        
        // 模拟内存使用
        var memoryBlocks: [Data] = []
        
        for i in 0..<PerformanceTestConfig.operationCount / 100 {
            // 分配内存
            let blockSize = 1024 * 1024  // 1MB
            let block = Data(count: blockSize)
            memoryBlocks.append(block)
            
            // 触发内存监控
            memoryMonitor.checkMemoryUsage()
            
            // 定期释放内存
            if i % 10 == 0 {
                memoryBlocks.removeFirst(min(5, memoryBlocks.count))
                leakDetector.recordSample()
            }
        }
        
        // 清理内存
        memoryBlocks.removeAll()
        memoryMonitor.performMemoryCleanup()
        memoryMonitor.stopMonitoring()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "内存监控器性能",
            duration: duration,
            operationCount: PerformanceTestConfig.operationCount / 100,
            throughput: Double(PerformanceTestConfig.operationCount / 100) / duration,
            avgResponseTime: duration / Double(PerformanceTestConfig.operationCount / 100),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test 4: Resource Cleanup Performance
    
    func testResourceCleanupPerformance() async -> PerformanceTestResult {
        print("\n🧹 测试4: 资源清理服务性能")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        let cleanupService = MockResourceCleanupService()
        
        // 创建需要清理的资源
        var tempFiles: [URL] = []
        var memoryBlocks: [Data] = []
        
        for i in 0..<PerformanceTestConfig.operationCount / 50 {
            do {
                // 创建临时文件
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent("test_\(i).tmp")
                try "Test data".write(to: tempFile, atomically: true, encoding: .utf8)
                tempFiles.append(tempFile)
                
                // 分配内存
                let block = Data(count: 1024 * 100)  // 100KB
                memoryBlocks.append(block)
                
                if i % 10 == 0 {
                    // 执行清理
                    try await cleanupService.performCleanup()
                    leakDetector.recordSample()
                }
            } catch {
                errors.append("资源清理测试失败: \(i) - \(error)")
            }
        }
        
        // 最终清理
        do {
            try await cleanupService.performFullCleanup()
        } catch {
            errors.append("资源清理失败: \(error)")
        }
        
        // 清理测试资源
        for file in tempFiles {
            try? FileManager.default.removeItem(at: file)
        }
        memoryBlocks.removeAll()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "资源清理服务性能",
            duration: duration,
            operationCount: PerformanceTestConfig.operationCount / 50,
            throughput: Double(PerformanceTestConfig.operationCount / 50) / duration,
            avgResponseTime: duration / Double(PerformanceTestConfig.operationCount / 50),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test 5: Concurrent Access Performance
    
    func testConcurrentAccessPerformance() -> PerformanceTestResult {
        print("\n🔄 测试5: 并发访问性能")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        let resourceManager = MockResourceManager()
        
        // 预先注册一些资源
        for i in 0..<100 {
            let resource = MockResource(id: "ConcurrentResource_\(i)")
            try? resourceManager.register(resource)
        }
        
        // 并发访问测试
        let concurrentQueue = DispatchQueue(label: "concurrent-test", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<PerformanceTestConfig.operationCount / 10 {
            group.enter()
            concurrentQueue.async {
                // 随机访问资源
                let resourceId = "ConcurrentResource_\(i % 100)"
                let _ = resourceManager.resolve(resourceId)
                
                if i % 50 == 0 {
                    leakDetector.recordSample()
                }
                group.leave()
            }
        }
        
        group.wait()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "并发访问性能",
            duration: duration,
            operationCount: PerformanceTestConfig.operationCount / 10,
            throughput: Double(PerformanceTestConfig.operationCount / 10) / duration,
            avgResponseTime: duration / Double(PerformanceTestConfig.operationCount / 10),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test 6: Long Running Memory Leak Test
    
    func testLongRunningMemoryLeaks() async -> PerformanceTestResult {
        print("\n⏱️ 测试6: 长期运行内存泄漏测试")
        
        let leakDetector = TestMemoryLeakDetector()
        leakDetector.startMonitoring()
        
        let startTime = Date()
        var errors: [String] = []
        
        let resourceManager = MockResourceManager()
        let memoryMonitor = MockMemoryMonitor()
        let cleanupService = MockResourceCleanupService()
        
        memoryMonitor.startMonitoring()
        
        // 长期运行测试
        let testEndTime = startTime.addingTimeInterval(PerformanceTestConfig.testDuration)
        var operationCount = 0
        
        while Date() < testEndTime {
            do {
                // 模拟典型的资源使用模式
                let resource = MockResource(id: "LongRunningResource_\(operationCount)")
                try resourceManager.register(resource)
                try await resourceManager.initialize(resource.resourceId)
                try resourceManager.activate(resource.resourceId)
                
                // 模拟一些处理
                usleep(1000)  // 1ms
                
                try resourceManager.deactivate(resource.resourceId)
                try await resourceManager.dispose(resource.resourceId)
                
                operationCount += 1
                
                // 定期检查内存和执行清理
                if operationCount % 100 == 0 {
                    memoryMonitor.checkMemoryUsage()
                    leakDetector.recordSample()
                }
                
                if operationCount % 500 == 0 {
                    try await cleanupService.performCleanup()
                }
                
            } catch {
                errors.append("长期运行测试失败: \(operationCount) - \(error)")
            }
        }
        
        memoryMonitor.stopMonitoring()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let (memoryLeak, peakMemory) = leakDetector.stopMonitoring()
        
        let result = PerformanceTestResult(
            testName: "长期运行内存泄漏测试",
            duration: duration,
            operationCount: operationCount,
            throughput: Double(operationCount) / duration,
            avgResponseTime: duration / Double(operationCount),
            memoryUsageBefore: leakDetector.initialMemory,
            memoryUsageAfter: leakDetector.getCurrentMemoryUsage(),
            memoryLeak: memoryLeak,
            peakMemoryUsage: peakMemory,
            errors: errors,
            timestamp: Date()
        )
        
        printTestResult(result)
        return result
    }
    
    // MARK: - Test Result Printing
    
    private func printTestResult(_ result: PerformanceTestResult) {
        print("\n📊 测试结果: \(result.testName)")
        print("   状态: \(result.isSuccess ? "✅ 成功" : "❌ 失败")")
        print("   持续时间: \(String(format: "%.2f", result.duration))s")
        print("   操作次数: \(result.operationCount)")
        print("   吞吐量: \(String(format: "%.2f", result.throughput)) ops/s")
        print("   平均响应时间: \(String(format: "%.4f", result.avgResponseTime * 1000))ms")
        print("   内存使用: \(result.memoryLeakFormatted)")
        print("   峰值内存: \(ByteCountFormatter().string(fromByteCount: result.peakMemoryUsage))")
        
        if !result.errors.isEmpty {
            print("   错误数量: \(result.errors.count)")
            for error in result.errors.prefix(3) {
                print("     - \(error)")
            }
            if result.errors.count > 3 {
                print("     ... 还有 \(result.errors.count - 3) 个错误")
            }
        }
    }
    
    // MARK: - Test Report Generation
    
    private func generateTestReport(_ results: [PerformanceTestResult]) {
        print("\n" + "=" * 80)
        print("📋 资源管理器性能测试报告")
        print("=" * 80)
        
        let successCount = results.filter { $0.isSuccess }.count
        let totalTests = results.count
        
        print("📊 总体统计:")
        print("   测试总数: \(totalTests)")
        print("   成功数量: \(successCount)")
        print("   失败数量: \(totalTests - successCount)")
        print("   成功率: \(String(format: "%.1f", Double(successCount) / Double(totalTests) * 100))%")
        
        let totalOperations = results.reduce(0) { $0 + $1.operationCount }
        let totalDuration = results.reduce(0) { $0 + $1.duration }
        let avgThroughput = Double(totalOperations) / totalDuration
        
        print("   总操作数: \(totalOperations)")
        print("   总耗时: \(String(format: "%.2f", totalDuration))s")
        print("   平均吞吐量: \(String(format: "%.2f", avgThroughput)) ops/s")
        
        let totalMemoryLeak = results.reduce(0) { $0 + $1.memoryLeak }
        print("   总内存泄漏: \(ByteCountFormatter().string(fromByteCount: totalMemoryLeak))")
        
        let maxPeakMemory = results.max { $0.peakMemoryUsage < $1.peakMemoryUsage }?.peakMemoryUsage ?? 0
        print("   峰值内存使用: \(ByteCountFormatter().string(fromByteCount: maxPeakMemory))")
        
        print("\n🎯 性能评估:")
        evaluatePerformance(results)
        
        print("\n💡 优化建议:")
        generateOptimizationRecommendations(results)
        
        // 保存报告到文件
        saveTestReport(results)
    }
    
    private func evaluatePerformance(_ results: [PerformanceTestResult]) {
        let avgThroughput = results.reduce(0) { $0 + $1.throughput } / Double(results.count)
        let avgResponseTime = results.reduce(0) { $0 + $1.avgResponseTime } / Double(results.count)
        let totalMemoryLeak = results.reduce(0) { $0 + $1.memoryLeak }
        
        // 吞吐量评估
        if avgThroughput > 1000 {
            print("   吞吐量: ✅ 优秀 (\(String(format: "%.0f", avgThroughput)) ops/s)")
        } else if avgThroughput > 500 {
            print("   吞吐量: ✅ 良好 (\(String(format: "%.0f", avgThroughput)) ops/s)")
        } else if avgThroughput > 100 {
            print("   吞吐量: ⚠️ 一般 (\(String(format: "%.0f", avgThroughput)) ops/s)")
        } else {
            print("   吞吐量: ❌ 较差 (\(String(format: "%.0f", avgThroughput)) ops/s)")
        }
        
        // 响应时间评估
        if avgResponseTime < 0.001 {
            print("   响应时间: ✅ 优秀 (\(String(format: "%.2f", avgResponseTime * 1000))ms)")
        } else if avgResponseTime < 0.01 {
            print("   响应时间: ✅ 良好 (\(String(format: "%.2f", avgResponseTime * 1000))ms)")
        } else if avgResponseTime < 0.1 {
            print("   响应时间: ⚠️ 一般 (\(String(format: "%.2f", avgResponseTime * 1000))ms)")
        } else {
            print("   响应时间: ❌ 较差 (\(String(format: "%.2f", avgResponseTime * 1000))ms)")
        }
        
        // 内存泄漏评估
        if totalMemoryLeak < 1024 * 1024 {  // 1MB
            print("   内存泄漏: ✅ 优秀 (\(ByteCountFormatter().string(fromByteCount: totalMemoryLeak)))")
        } else if totalMemoryLeak < 10 * 1024 * 1024 {  // 10MB
            print("   内存泄漏: ⚠️ 一般 (\(ByteCountFormatter().string(fromByteCount: totalMemoryLeak)))")
        } else {
            print("   内存泄漏: ❌ 严重 (\(ByteCountFormatter().string(fromByteCount: totalMemoryLeak)))")
        }
    }
    
    private func generateOptimizationRecommendations(_ results: [PerformanceTestResult]) {
        let failedTests = results.filter { !$0.isSuccess }
        let highMemoryTests = results.filter { $0.memoryLeak > 10 * 1024 * 1024 }
        let slowTests = results.filter { $0.avgResponseTime > 0.01 }
        
        if !failedTests.isEmpty {
            print("   🔧 修复失败的测试用例")
            print("   🔍 检查错误日志并解决相关问题")
        }
        
        if !highMemoryTests.isEmpty {
            print("   🧠 优化内存使用")
            print("   📦 实现更积极的内存清理策略")
            print("   🔄 检查并修复潜在的内存泄漏")
        }
        
        if !slowTests.isEmpty {
            print("   ⚡ 优化响应时间")
            print("   🗃️ 考虑添加缓存机制")
            print("   🔧 优化资源管理算法")
        }
        
        print("   📊 考虑实现更细粒度的性能监控")
        print("   🎯 设置性能基准和自动化测试")
        print("   🔄 定期执行性能回归测试")
    }
    
    private func saveTestReport(_ results: [PerformanceTestResult]) {
        let reportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("resource_performance_report_\(Date().timeIntervalSince1970).json")
        
        do {
            let reportData = try JSONEncoder().encode(results)
            try reportData.write(to: reportPath)
            print("\n📁 测试报告已保存到: \(reportPath.path)")
        } catch {
            print("\n❌ 保存测试报告失败: \(error)")
        }
    }
}

// MARK: - Mock Classes for Testing

class MockResourceManager: @unchecked Sendable {
    private var resources: [String: MockResource] = [:]
    private let queue = DispatchQueue(label: "mock-resource-manager", attributes: .concurrent)
    
    func register(_ resource: MockResource) throws {
        queue.async(flags: .barrier) {
            self.resources[resource.resourceId] = resource
        }
    }
    
    func resolve(_ resourceId: String) -> MockResource? {
        return queue.sync {
            return resources[resourceId]
        }
    }
    
    func initialize(_ resourceId: String) async throws {
        guard let resource = resolve(resourceId) else {
            throw NSError(domain: "MockResourceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource not found"])
        }
        try await resource.initialize()
    }
    
    func activate(_ resourceId: String) throws {
        guard let resource = resolve(resourceId) else {
            throw NSError(domain: "MockResourceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource not found"])
        }
        try resource.activate()
    }
    
    func deactivate(_ resourceId: String) throws {
        guard let resource = resolve(resourceId) else {
            throw NSError(domain: "MockResourceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource not found"])
        }
        try resource.deactivate()
    }
    
    func dispose(_ resourceId: String) async throws {
        guard let resource = resolve(resourceId) else {
            throw NSError(domain: "MockResourceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource not found"])
        }
        await resource.dispose()
        
        queue.async(flags: .barrier) {
            self.resources.removeValue(forKey: resourceId)
        }
    }
}

class MockResource {
    let resourceId: String
    private var state: String = "uninitialized"
    
    init(id: String) {
        self.resourceId = id
    }
    
    func initialize() async throws {
        try await Task.sleep(nanoseconds: 100_000)  // 0.1ms
        state = "ready"
    }
    
    func activate() throws {
        state = "active"
    }
    
    func deactivate() throws {
        state = "ready"
    }
    
    func dispose() async {
        try? await Task.sleep(nanoseconds: 50_000)  // 0.05ms
        state = "disposed"
    }
}

class MockMemoryMonitor {
    private var monitoring = false
    
    func startMonitoring() {
        monitoring = true
    }
    
    func stopMonitoring() {
        monitoring = false
    }
    
    func checkMemoryUsage() {
        // 模拟内存检查
        usleep(100)  // 0.1ms
    }
    
    func performMemoryCleanup() {
        // 模拟内存清理
        usleep(1000)  // 1ms
    }
}

class MockResourceCleanupService {
    func performCleanup() async throws {
        // 模拟清理操作
        try await Task.sleep(nanoseconds: 1_000_000)  // 1ms
    }
    
    func performFullCleanup() async throws {
        // 模拟完整清理
        try await Task.sleep(nanoseconds: 5_000_000)  // 5ms
    }
}

// MARK: - String Extension for Repetition

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - Make PerformanceTestResult Codable

extension PerformanceTestResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case testName, duration, operationCount, throughput, avgResponseTime
        case memoryUsageBefore, memoryUsageAfter, memoryLeak, peakMemoryUsage
        case errors, timestamp
    }
}

// MARK: - Main Execution

Task {
    print("🚀 CapsWriter 资源管理器性能测试")
    print("测试配置:")
    print("  - 测试持续时间: \(PerformanceTestConfig.testDuration)s")
    print("  - 操作次数: \(PerformanceTestConfig.operationCount)")
    print("  - 内存阈值: \(ByteCountFormatter().string(fromByteCount: PerformanceTestConfig.memoryThreshold))")

    let performanceTests = ResourceManagerPerformanceTests()
    await performanceTests.runAllTests()

    print("\n🎉 所有测试完成！")
}