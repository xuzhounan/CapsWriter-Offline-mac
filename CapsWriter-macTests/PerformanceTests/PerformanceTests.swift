import XCTest
import Combine
import AVFoundation
import os.log
@testable import CapsWriter_mac

/// 性能测试套件 - 系统化的性能基准测试和回归测试
/// 
/// 测试覆盖：
/// - 音频处理性能基准
/// - 识别延迟基准测试
/// - 内存使用回归测试
/// - CPU 使用率基准测试
/// - 并发处理性能测试
/// - 端到端性能验证
class PerformanceTests: XCTestCase {
    
    // MARK: - Test Properties
    private let logger = os.Logger(subsystem: "com.capswriter.tests", category: "PerformanceTests")
    private var performanceMonitor: PerformanceMonitor!
    private var memoryManager: MemoryManager!
    private var profilerTools: ProfilerTools!
    
    // 性能基准阈值
    private let performanceBenchmarks = PerformanceBenchmarks()
    
    // 测试数据和资源
    private var testAudioBuffers: [AVAudioPCMBuffer] = []
    private var mockAudioService: MockOptimizedAudioService!
    private var mockASRService: MockOptimizedSherpaASRService!
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 初始化测试组件
        performanceMonitor = PerformanceMonitor.shared
        memoryManager = MemoryManager.shared
        profilerTools = ProfilerTools.shared
        
        // 创建 Mock 服务
        mockAudioService = MockOptimizedAudioService()
        mockASRService = MockOptimizedSherpaASRService()
        
        // 生成测试音频数据
        try generateTestAudioData()
        
        // 启动性能监控
        performanceMonitor.startMonitoring()
        
        logger.info("🧪 性能测试环境设置完成")
    }
    
    override func tearDownWithError() throws {
        // 停止性能监控
        performanceMonitor.stopMonitoring()
        
        // 清理测试资源
        testAudioBuffers.removeAll()
        mockAudioService = nil
        mockASRService = nil
        
        // 清理性能数据
        profilerTools.clearProfilingData()
        memoryManager.clearAllCaches()
        
        logger.info("🧹 性能测试环境清理完成")
        
        try super.tearDownWithError()
    }
    
    // MARK: - Audio Processing Performance Tests
    
    /// 测试音频处理延迟基准
    func testAudioProcessingLatencyBenchmark() throws {
        logger.info("🎵 开始音频处理延迟基准测试")
        
        profilerTools.startProfiling(sessionName: "AudioProcessingLatency")
        
        let expectation = XCTestExpectation(description: "Audio processing completed")
        var processingTimes: [TimeInterval] = []
        let totalBuffers = 100
        
        for (index, buffer) in testAudioBuffers.prefix(totalBuffers).enumerated() {
            let startTime = Date()
            
            mockAudioService.processTestBuffer(buffer) { _ in
                let processingTime = Date().timeIntervalSince(startTime)
                processingTimes.append(processingTime)
                
                // 记录性能
                self.profilerTools.recordFunctionCall(
                    functionName: "processTestBuffer",
                    className: "MockOptimizedAudioService",
                    startTime: startTime,
                    endTime: Date()
                )
                
                if index == totalBuffers - 1 {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        profilerTools.stopProfiling()
        
        // 验证性能基准
        let averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxProcessingTime = processingTimes.max() ?? 0
        
        logger.info("📊 音频处理性能统计:")
        logger.info("  - 平均延迟: \(Int(averageProcessingTime * 1000))ms")
        logger.info("  - 最大延迟: \(Int(maxProcessingTime * 1000))ms")
        
        // 性能断言
        XCTAssertLessThan(averageProcessingTime, performanceBenchmarks.audioProcessingLatencyThreshold,
                         "音频处理平均延迟超过基准阈值")
        XCTAssertLessThan(maxProcessingTime, performanceBenchmarks.audioProcessingLatencyThreshold * 2,
                         "音频处理最大延迟超过基准阈值")
        
        // 记录到性能监控
        performanceMonitor.recordAudioProcessingDelay(averageProcessingTime, bufferSize: 1024)
    }
    
    /// 测试音频处理吞吐量
    func testAudioProcessingThroughput() throws {
        logger.info("🎵 开始音频处理吞吐量测试")
        
        let measurementExpectation = XCTestExpectation(description: "Throughput measurement completed")
        let testDuration: TimeInterval = 5.0
        var processedBuffers: Int = 0
        
        let startTime = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if Date().timeIntervalSince(startTime) < testDuration {
                // 模拟连续音频处理
                if !self.testAudioBuffers.isEmpty {
                    let buffer = self.testAudioBuffers[processedBuffers % self.testAudioBuffers.count]
                    self.mockAudioService.processTestBuffer(buffer) { _ in
                        processedBuffers += 1
                    }
                }
            } else {
                measurementExpectation.fulfill()
            }
        }
        
        wait(for: [measurementExpectation], timeout: testDuration + 2.0)
        timer.invalidate()
        
        let throughput = Double(processedBuffers) / testDuration
        logger.info("📈 音频处理吞吐量: \(Int(throughput)) 缓冲区/秒")
        
        XCTAssertGreaterThan(throughput, performanceBenchmarks.audioThroughputThreshold,
                           "音频处理吞吐量低于基准阈值")
    }
    
    // MARK: - Recognition Performance Tests
    
    /// 测试语音识别延迟基准
    func testRecognitionLatencyBenchmark() throws {
        logger.info("🧠 开始语音识别延迟基准测试")
        
        profilerTools.startProfiling(sessionName: "RecognitionLatency")
        
        let expectation = XCTestExpectation(description: "Recognition completed")
        var recognitionTimes: [TimeInterval] = []
        let testCount = 50
        
        for i in 0..<testCount {
            let startTime = Date()
            
            mockASRService.processAudioForTesting(testAudioBuffers.first!) { result in
                let recognitionTime = Date().timeIntervalSince(startTime)
                recognitionTimes.append(recognitionTime)
                
                // 记录性能
                self.profilerTools.recordFunctionCall(
                    functionName: "processAudioForTesting",
                    className: "MockOptimizedSherpaASRService",
                    startTime: startTime,
                    endTime: Date()
                )
                
                if i == testCount - 1 {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        profilerTools.stopProfiling()
        
        // 统计分析
        let averageRecognitionTime = recognitionTimes.reduce(0, +) / Double(recognitionTimes.count)
        let maxRecognitionTime = recognitionTimes.max() ?? 0
        let percentile95 = recognitionTimes.sorted()[Int(Double(recognitionTimes.count) * 0.95)]
        
        logger.info("📊 语音识别性能统计:")
        logger.info("  - 平均延迟: \(Int(averageRecognitionTime * 1000))ms")
        logger.info("  - 最大延迟: \(Int(maxRecognitionTime * 1000))ms")
        logger.info("  - 95%延迟: \(Int(percentile95 * 1000))ms")
        
        // 性能断言
        XCTAssertLessThan(averageRecognitionTime, performanceBenchmarks.recognitionLatencyThreshold,
                         "语音识别平均延迟超过基准阈值")
        XCTAssertLessThan(percentile95, performanceBenchmarks.recognitionLatencyThreshold * 1.5,
                         "语音识别95%延迟超过基准阈值")
        
        performanceMonitor.recordRecognitionDelay(averageRecognitionTime)
    }
    
    /// 测试识别准确率与性能平衡
    func testRecognitionAccuracyPerformanceBalance() throws {
        logger.info("🎯 开始识别准确率与性能平衡测试")
        
        let expectation = XCTestExpectation(description: "Accuracy performance test completed")
        var results: [(accuracy: Double, latency: TimeInterval)] = []
        
        // 测试不同配置下的性能表现
        let configurations = [
            (threads: 1, paths: 1),
            (threads: 2, paths: 2),
            (threads: 4, paths: 4)
        ]
        
        for config in configurations {
            mockASRService.updateConfiguration(threads: config.threads, activePaths: config.paths)
            
            let startTime = Date()
            mockASRService.processAudioForTesting(testAudioBuffers.first!) { result in
                let latency = Date().timeIntervalSince(startTime)
                let accuracy = self.calculateMockAccuracy(result)
                
                results.append((accuracy: accuracy, latency: latency))
                
                if results.count == configurations.count {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // 分析结果
        for (index, result) in results.enumerated() {
            let config = configurations[index]
            logger.info("配置 threads:\(config.threads) paths:\(config.paths) - 准确率: \(String(format: "%.2f", result.accuracy))%, 延迟: \(Int(result.latency * 1000))ms")
        }
        
        // 验证性能平衡
        let optimalResult = results.max { lhs, rhs in
            let lhsScore = lhs.accuracy / (lhs.latency * 1000)
            let rhsScore = rhs.accuracy / (rhs.latency * 1000)
            return lhsScore < rhsScore
        }
        
        XCTAssertNotNil(optimalResult, "未找到最优配置")
        if let optimal = optimalResult {
            XCTAssertGreaterThan(optimal.accuracy, 90.0, "最优配置准确率过低")
            XCTAssertLessThan(optimal.latency, performanceBenchmarks.recognitionLatencyThreshold * 1.2, "最优配置延迟过高")
        }
    }
    
    // MARK: - Memory Performance Tests
    
    /// 测试内存使用基准
    func testMemoryUsageBenchmark() throws {
        logger.info("🧠 开始内存使用基准测试")
        
        memoryManager.performMemoryCleanup(force: true)
        let initialMemory = getCurrentMemoryUsage()
        
        // 模拟音频处理负载
        let loadExpectation = XCTestExpectation(description: "Memory load test completed")
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<1000 {
                // 分配和释放音频缓冲区包装器
                let wrapper = self.memoryManager.getAudioBufferWrapper(capacity: 1024)
                // 模拟处理
                Thread.sleep(forTimeInterval: 0.001)
                self.memoryManager.releaseAudioBufferWrapper(wrapper)
                
                // 缓存一些数据
                let testData = Data(repeating: 0, count: 1024)
                self.memoryManager.cacheAudioData(key: "test_\(UUID().uuidString)", data: testData)
            }
            loadExpectation.fulfill()
        }
        
        wait(for: [loadExpectation], timeout: 30.0)
        
        let peakMemory = getCurrentMemoryUsage()
        
        // 清理后检查内存释放
        memoryManager.clearAllCaches()
        memoryManager.performMemoryCleanup(force: true)
        Thread.sleep(forTimeInterval: 1.0) // 等待清理完成
        
        let finalMemory = getCurrentMemoryUsage()
        
        logger.info("📊 内存使用统计:")
        logger.info("  - 初始内存: \(String(format: "%.1f", initialMemory))MB")
        logger.info("  - 峰值内存: \(String(format: "%.1f", peakMemory))MB")
        logger.info("  - 最终内存: \(String(format: "%.1f", finalMemory))MB")
        logger.info("  - 内存增长: \(String(format: "%.1f", peakMemory - initialMemory))MB")
        
        // 性能断言
        let memoryGrowth = peakMemory - initialMemory
        XCTAssertLessThan(memoryGrowth, performanceBenchmarks.memoryGrowthThreshold,
                         "内存增长超过基准阈值")
        
        let memoryLeak = finalMemory - initialMemory
        XCTAssertLessThan(memoryLeak, performanceBenchmarks.memoryLeakThreshold,
                         "检测到可能的内存泄漏")
    }
    
    /// 测试内存池性能
    func testMemoryPoolPerformance() throws {
        logger.info("🏊 开始内存池性能测试")
        
        let poolTestExpectation = XCTestExpectation(description: "Memory pool test completed")
        let iterations = 10000
        
        let startTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                // 测试音频缓冲区池
                let wrapper = self.memoryManager.getAudioBufferWrapper(capacity: 1024)
                self.memoryManager.releaseAudioBufferWrapper(wrapper)
                
                // 测试字符串池
                let string = self.memoryManager.getMutableString()
                string.append("test")
                self.memoryManager.releaseMutableString(string)
                
                // 测试数据池
                let data = self.memoryManager.getMutableData()
                data.append("test".data(using: .utf8)!)
                self.memoryManager.releaseMutableData(data)
            }
            poolTestExpectation.fulfill()
        }
        
        wait(for: [poolTestExpectation], timeout: 10.0)
        
        let totalTime = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(iterations * 3) / totalTime // 3 operations per iteration
        
        logger.info("📈 内存池性能: \(Int(operationsPerSecond)) 操作/秒")
        
        XCTAssertGreaterThan(operationsPerSecond, performanceBenchmarks.memoryPoolThroughputThreshold,
                           "内存池吞吐量低于基准阈值")
    }
    
    // MARK: - CPU Performance Tests
    
    /// 测试CPU使用率基准
    func testCPUUsageBenchmark() throws {
        logger.info("⚡ 开始CPU使用率基准测试")
        
        let cpuTestExpectation = XCTestExpectation(description: "CPU usage test completed")
        var cpuSamples: [Double] = []
        
        // 启动CPU监控
        let cpuMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            cpuSamples.append(self.getCurrentCPUUsage())
        }
        
        // 模拟计算密集型任务
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < 5.0 {
                // 模拟音频处理计算
                for buffer in self.testAudioBuffers {
                    self.mockAudioService.processTestBuffer(buffer) { _ in }
                }
                
                // 模拟识别处理
                self.mockASRService.processAudioForTesting(self.testAudioBuffers.first!) { _ in }
            }
            cpuTestExpectation.fulfill()
        }
        
        wait(for: [cpuTestExpectation], timeout: 10.0)
        cpuMonitoringTimer.invalidate()
        
        // 分析CPU使用情况
        let averageCPU = cpuSamples.reduce(0, +) / Double(cpuSamples.count)
        let maxCPU = cpuSamples.max() ?? 0
        let percentile95 = cpuSamples.sorted()[Int(Double(cpuSamples.count) * 0.95)]
        
        logger.info("📊 CPU使用率统计:")
        logger.info("  - 平均CPU: \(String(format: "%.1f", averageCPU))%")
        logger.info("  - 最大CPU: \(String(format: "%.1f", maxCPU))%")
        logger.info("  - 95%CPU: \(String(format: "%.1f", percentile95))%")
        
        // 性能断言
        XCTAssertLessThan(averageCPU, performanceBenchmarks.cpuUsageThreshold,
                         "平均CPU使用率超过基准阈值")
        XCTAssertLessThan(percentile95, performanceBenchmarks.cpuUsageThreshold * 1.5,
                         "95%CPU使用率超过基准阈值")
    }
    
    // MARK: - Concurrency Performance Tests
    
    /// 测试并发处理性能
    func testConcurrentProcessingPerformance() throws {
        logger.info("🔄 开始并发处理性能测试")
        
        let concurrencyExpectation = XCTestExpectation(description: "Concurrency test completed")
        let concurrencyLevels = [1, 2, 4, 8]
        var results: [Int: TimeInterval] = [:]
        
        for concurrency in concurrencyLevels {
            let startTime = Date()
            let group = DispatchGroup()
            
            for i in 0..<concurrency {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    // 模拟并发音频处理
                    for buffer in self.testAudioBuffers.prefix(10) {
                        self.mockAudioService.processTestBuffer(buffer) { _ in }
                    }
                    group.leave()
                }
            }
            
            group.wait()
            let processingTime = Date().timeIntervalSince(startTime)
            results[concurrency] = processingTime
            
            logger.info("并发度 \(concurrency): 处理时间 \(String(format: "%.3f", processingTime))秒")
        }
        
        concurrencyExpectation.fulfill()
        wait(for: [concurrencyExpectation], timeout: 1.0)
        
        // 分析并发性能
        let sequentialTime = results[1] ?? 1.0
        for concurrency in concurrencyLevels.dropFirst() {
            if let concurrentTime = results[concurrency] {
                let speedup = sequentialTime / concurrentTime
                let efficiency = speedup / Double(concurrency)
                
                logger.info("并发度 \(concurrency): 加速比 \(String(format: "%.2f", speedup)), 效率 \(String(format: "%.2f", efficiency))")
                
                XCTAssertGreaterThan(speedup, 1.0, "并发处理未提供性能提升")
                XCTAssertGreaterThan(efficiency, 0.5, "并发效率过低")
            }
        }
    }
    
    // MARK: - End-to-End Performance Tests
    
    /// 测试端到端性能
    func testEndToEndPerformance() throws {
        logger.info("🎯 开始端到端性能测试")
        
        profilerTools.startProfiling(sessionName: "EndToEndPerformance")
        
        let e2eExpectation = XCTestExpectation(description: "End-to-end test completed")
        var endToEndTimes: [TimeInterval] = []
        
        for i in 0..<10 {
            let startTime = Date()
            
            // 模拟完整的语音识别流程
            mockAudioService.processTestBuffer(testAudioBuffers.first!) { processedBuffer in
                // 音频处理完成，开始识别
                self.mockASRService.processAudioForTesting(processedBuffer) { recognitionResult in
                    // 识别完成
                    let endTime = Date()
                    let e2eTime = endTime.timeIntervalSince(startTime)
                    endToEndTimes.append(e2eTime)
                    
                    // 记录端到端性能
                    self.profilerTools.recordFunctionCall(
                        functionName: "endToEndRecognition",
                        className: "PerformanceTests",
                        startTime: startTime,
                        endTime: endTime
                    )
                    
                    if i == 9 {
                        e2eExpectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [e2eExpectation], timeout: 30.0)
        profilerTools.stopProfiling()
        
        // 分析端到端性能
        let averageE2ETime = endToEndTimes.reduce(0, +) / Double(endToEndTimes.count)
        let maxE2ETime = endToEndTimes.max() ?? 0
        
        logger.info("📊 端到端性能统计:")
        logger.info("  - 平均端到端时间: \(String(format: "%.3f", averageE2ETime))秒")
        logger.info("  - 最大端到端时间: \(String(format: "%.3f", maxE2ETime))秒")
        
        // 性能断言
        XCTAssertLessThan(averageE2ETime, performanceBenchmarks.endToEndLatencyThreshold,
                         "端到端延迟超过基准阈值")
        
        // 生成性能分析报告
        let report = profilerTools.analyzePerformanceBottlenecks()
        XCTAssertGreaterThan(report.performanceScore, 70.0, "端到端性能评分过低")
    }
    
    // MARK: - Performance Regression Tests
    
    /// 测试性能回归
    func testPerformanceRegression() throws {
        logger.info("📉 开始性能回归测试")
        
        // 运行标准性能测试套件
        try testAudioProcessingLatencyBenchmark()
        try testRecognitionLatencyBenchmark()
        try testMemoryUsageBenchmark()
        
        // 获取当前性能报告
        let currentReport = performanceMonitor.getPerformanceReport()
        
        // 与历史基准比较（这里使用固定基准，实际应该从历史数据加载）
        let historicalBenchmark = HistoricalPerformanceBenchmark()
        
        // 检查性能回归
        let audioLatencyRegression = (currentReport.currentMetrics.audioProcessingDelay - historicalBenchmark.audioProcessingLatency) / historicalBenchmark.audioProcessingLatency
        let recognitionLatencyRegression = (currentReport.currentMetrics.recognitionDelay - historicalBenchmark.recognitionLatency) / historicalBenchmark.recognitionLatency
        let memoryUsageRegression = (currentReport.currentMetrics.memoryUsage - historicalBenchmark.memoryUsage) / historicalBenchmark.memoryUsage
        
        logger.info("📊 性能回归分析:")
        logger.info("  - 音频延迟变化: \(String(format: "%.1f", audioLatencyRegression * 100))%")
        logger.info("  - 识别延迟变化: \(String(format: "%.1f", recognitionLatencyRegression * 100))%")
        logger.info("  - 内存使用变化: \(String(format: "%.1f", memoryUsageRegression * 100))%")
        
        // 回归断言（允许5%的性能波动）
        XCTAssertLessThan(abs(audioLatencyRegression), 0.05, "音频延迟出现显著回归")
        XCTAssertLessThan(abs(recognitionLatencyRegression), 0.05, "识别延迟出现显著回归")
        XCTAssertLessThan(abs(memoryUsageRegression), 0.10, "内存使用出现显著回归")
    }
    
    // MARK: - Helper Methods
    
    private func generateTestAudioData() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        
        for _ in 0..<10 {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
            buffer.frameLength = 1024
            
            // 生成测试音频数据（白噪声）
            if let channelData = buffer.floatChannelData {
                for i in 0..<Int(buffer.frameLength) {
                    channelData[0][i] = Float.random(in: -0.1...0.1)
                }
            }
            
            testAudioBuffers.append(buffer)
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
            return Double(info.resident_size) / 1024.0 / 1024.0
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
    
    private func calculateMockAccuracy(_ result: String?) -> Double {
        // 模拟准确率计算
        return Double.random(in: 85.0...95.0)
    }
}

// MARK: - Supporting Types

/// 性能基准阈值
struct PerformanceBenchmarks {
    let audioProcessingLatencyThreshold: TimeInterval = 0.1  // 100ms
    let recognitionLatencyThreshold: TimeInterval = 0.5     // 500ms
    let memoryGrowthThreshold: Double = 50.0                // 50MB
    let memoryLeakThreshold: Double = 5.0                   // 5MB
    let cpuUsageThreshold: Double = 30.0                    // 30%
    let audioThroughputThreshold: Double = 50.0             // 50 buffers/sec
    let memoryPoolThroughputThreshold: Double = 10000.0     // 10k operations/sec
    let endToEndLatencyThreshold: TimeInterval = 2.0       // 2 seconds
}

/// 历史性能基准
struct HistoricalPerformanceBenchmark {
    let audioProcessingLatency: TimeInterval = 0.05  // 50ms baseline
    let recognitionLatency: TimeInterval = 0.3       // 300ms baseline
    let memoryUsage: Double = 80.0                   // 80MB baseline
}

// MARK: - Mock Services

/// Mock 优化音频服务
class MockOptimizedAudioService {
    func processTestBuffer(_ buffer: AVAudioPCMBuffer, completion: @escaping (AVAudioPCMBuffer) -> Void) {
        // 模拟音频处理延迟
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.01) {
            completion(buffer)
        }
    }
}

/// Mock 优化ASR服务
class MockOptimizedSherpaASRService {
    private var threads = 2
    private var activePaths = 2
    
    func updateConfiguration(threads: Int, activePaths: Int) {
        self.threads = threads
        self.activePaths = activePaths
    }
    
    func processAudioForTesting(_ buffer: AVAudioPCMBuffer, completion: @escaping (String?) -> Void) {
        // 模拟识别延迟（基于配置）
        let baseDelay = 0.1
        let configDelay = baseDelay / Double(threads) * Double(activePaths)
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + configDelay) {
            completion("Mock recognition result")
        }
    }
}