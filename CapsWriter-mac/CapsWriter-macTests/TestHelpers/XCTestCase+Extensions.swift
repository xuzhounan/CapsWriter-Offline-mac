import XCTest
import Foundation
import Combine
import AVFoundation
@testable import CapsWriter_mac

// MARK: - XCTestCase 扩展

extension XCTestCase {

    // MARK: - 异步测试助手

    /// 等待异步条件满足
    func waitForCondition(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5.0,
        description: String = "条件满足",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: description)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()
        
        if result != .completed {
            XCTFail("等待条件超时: \(description)", file: file, line: line)
        }
    }

    /// 等待多个异步操作完成
    func waitForMultipleOperations(
        operations: [() async throws -> Void],
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for operation in operations {
                    group.addTask {
                        try await operation()
                    }
                }
                
                try await group.waitForAll()
            }
        } catch {
            XCTFail("异步操作失败: \(error)", file: file, line: line)
        }
    }

    /// 等待 Publisher 发出值
    func waitForPublisher<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) -> P.Output? where P.Failure == Never {
        let expectation = XCTestExpectation(description: "Publisher 值等待")
        var result: P.Output?
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink { value in
                result = value
                expectation.fulfill()
            }
        
        let waiterResult = XCTWaiter.wait(for: [expectation], timeout: timeout)
        cancellable?.cancel()
        
        if waiterResult != .completed {
            XCTFail("等待 Publisher 超时", file: file, line: line)
            return nil
        }
        
        return result
    }

    // MARK: - Mock 验证助手

    /// 验证 Mock 对象的调用
    func verifyMockCalls<T: MockService>(
        _ mock: T,
        expectedCalls: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for expectedCall in expectedCalls {
            let found = mock.callHistory.contains { $0.contains(expectedCall) }
            XCTAssertTrue(
                found,
                "期望的调用 '\(expectedCall)' 未找到。实际调用: \(mock.callHistory)",
                file: file,
                line: line
            )
        }
    }

    /// 验证 Mock 对象的调用次数
    func verifyMockCallCount<T: MockService>(
        _ mock: T,
        method: String,
        expectedCount: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let actualCount = mock.callHistory.filter { $0.contains(method) }.count
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "方法 '\(method)' 调用次数不匹配。期望: \(expectedCount), 实际: \(actualCount)",
            file: file,
            line: line
        )
    }

    /// 验证 Mock 对象调用顺序
    func verifyMockCallOrder<T: MockService>(
        _ mock: T,
        expectedOrder: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        var foundIndices: [Int] = []
        
        for expectedCall in expectedOrder {
            if let index = mock.callHistory.firstIndex(where: { $0.contains(expectedCall) }) {
                foundIndices.append(index)
            } else {
                XCTFail("期望的调用 '\(expectedCall)' 未找到", file: file, line: line)
                return
            }
        }
        
        // 验证顺序
        let isSorted = foundIndices == foundIndices.sorted()
        XCTAssertTrue(isSorted, "调用顺序不正确。期望: \(expectedOrder), 实际顺序索引: \(foundIndices)", file: file, line: line)
    }

    // MARK: - 数据生成助手

    /// 生成测试音频数据
    func generateTestAudioData(
        duration: TimeInterval = 1.0,
        sampleRate: Int = 16000,
        channels: Int = 1,
        amplitude: Float = 0.5,
        frequency: Float = 440.0
    ) -> Data {
        let samplesCount = Int(duration * Double(sampleRate) * Double(channels))
        var samples: [Float] = []
        
        // 生成正弦波音频数据
        for i in 0..<samplesCount {
            let time = Float(i) / Float(sampleRate)
            let sample = amplitude * sin(2.0 * Float.pi * frequency * time)
            samples.append(sample)
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }

    /// 生成测试语音数据 (模拟录音格式)
    func generateTestSpeechData(
        words: [String] = ["测试", "语音", "识别"],
        pauseBetweenWords: TimeInterval = 0.2
    ) -> Data {
        var combinedData = Data()
        
        for word in words {
            // 为每个词生成音频数据
            let wordDuration = TimeInterval(word.count) * 0.15 // 每个字符约150ms
            let wordData = generateTestAudioData(
                duration: wordDuration,
                frequency: Float.random(in: 200...800) // 随机频率模拟不同音调
            )
            combinedData.append(wordData)
            
            // 添加停顿
            let pauseData = generateSilentAudioData(duration: pauseBetweenWords)
            combinedData.append(pauseData)
        }
        
        return combinedData
    }

    /// 生成静音音频数据
    func generateSilentAudioData(
        duration: TimeInterval = 0.5,
        sampleRate: Int = 16000,
        channels: Int = 1
    ) -> Data {
        let samplesCount = Int(duration * Double(sampleRate) * Double(channels))
        let samples = [Float](repeating: 0.0, count: samplesCount)
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }

    /// 生成测试文本
    func generateTestText(
        wordCount: Int = 100,
        includeHotWords: Bool = true,
        includePunctuation: Bool = true
    ) -> String {
        let baseWords = ["测试", "文本", "内容", "处理", "功能", "系统", "应用", "程序", "开发", "技术"]
        let hotWords = ["你好", "世界", "识别", "语音", "转录", "实时"]
        let punctuation = ["。", "，", "！", "？", "；", "："]
        
        var words: [String] = []
        
        for i in 0..<wordCount {
            // 决定使用哪种词汇
            let shouldUseHotWord = includeHotWords && Int.random(in: 1...10) <= 3
            let word = shouldUseHotWord 
                ? hotWords.randomElement() ?? "测试"
                : baseWords.randomElement() ?? "测试"
            
            words.append(word)
            
            // 随机添加标点符号
            if includePunctuation && Int.random(in: 1...10) <= 2 {
                if let punct = punctuation.randomElement() {
                    words[words.count - 1] += punct
                }
            }
        }
        
        return words.joined(separator: " ")
    }

    /// 生成测试配置数据
    func generateTestConfiguration() -> (audio: AudioConfiguration, recognition: RecognitionConfiguration) {
        let audio = AudioConfiguration(
            sampleRate: [16000, 22050, 44100, 48000].randomElement() ?? 16000,
            channels: [1, 2].randomElement() ?? 1,
            bufferSize: [512, 1024, 2048, 4096].randomElement() ?? 1024,
            enableNoiseReduction: Bool.random(),
            enableAudioEnhancement: Bool.random()
        )
        
        let recognition = RecognitionConfiguration(
            modelPath: "models/test-model",
            numThreads: Int.random(in: 1...8),
            provider: ["cpu", "gpu"].randomElement() ?? "cpu",
            enableEndpoint: Bool.random(),
            debug: Bool.random(),
            language: ["zh", "en"].randomElement() ?? "zh"
        )
        
        return (audio, recognition)
    }

    // MARK: - 性能测试助手

    /// 测量内存使用
    func measureMemoryUsage<T>(
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> (result: T, memoryDelta: Int64) {
        let startMemory = getMemoryUsage()
        let result = try operation()
        let endMemory = getMemoryUsage()
        
        let memoryDelta = endMemory - startMemory
        print("内存使用变化: \(memoryDelta) bytes", file: file, line: line)
        
        return (result, memoryDelta)
    }

    /// 测量执行时间
    func measureExecutionTime<T>(
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> (result: T, executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        print("执行时间: \(executionTime * 1000) ms", file: file, line: line)
        
        return (result, executionTime)
    }

    /// 获取当前内存使用量
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }

        return 0
    }

    // MARK: - 断言助手

    /// 断言数组包含预期元素（忽略顺序）
    func XCTAssertArrayContains<T: Equatable>(
        _ array: [T],
        _ expectedElements: [T],
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for element in expectedElements {
            XCTAssertTrue(
                array.contains(element),
                "数组不包含预期元素 '\(element)'. \(message)",
                file: file,
                line: line
            )
        }
    }

    /// 断言字典包含预期键值对
    func XCTAssertDictionaryContains<K: Hashable, V: Equatable>(
        _ dictionary: [K: V],
        _ expectedPairs: [K: V],
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for (key, expectedValue) in expectedPairs {
            if let actualValue = dictionary[key] {
                XCTAssertEqual(
                    actualValue,
                    expectedValue,
                    "字典键 '\(key)' 的值不匹配. \(message)",
                    file: file,
                    line: line
                )
            } else {
                XCTFail("字典不包含键 '\(key)'. \(message)", file: file, line: line)
            }
        }
    }

    /// 断言文本包含预期的热词替换结果
    func XCTAssertTextContainsReplacements(
        _ text: String,
        replacements: [String: String],
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for (original, replacement) in replacements {
            XCTAssertFalse(
                text.contains(original),
                "文本仍包含未替换的原词 '\(original)'. \(message)",
                file: file,
                line: line
            )
            XCTAssertTrue(
                text.contains(replacement),
                "文本不包含替换后的词 '\(replacement)'. \(message)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - 文件系统助手

    /// 创建临时测试文件
    func createTemporaryTestFile(
        name: String = UUID().uuidString,
        extension: String = "txt",
        content: String = "test content"
    ) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(name).\(`extension`)")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("创建临时文件失败: \(error)")
        }
        
        return fileURL
    }

    /// 清理临时测试文件
    func cleanupTemporaryFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // 忽略清理错误，可能文件已不存在
            print("清理临时文件失败: \(error)")
        }
    }

    /// 创建测试热词文件
    func createTestHotWordFile(
        type: HotWordType,
        entries: [String: String] = [:]
    ) -> URL {
        let fileName = "test-\(type.rawValue)"
        let content = entries.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        return createTemporaryTestFile(name: fileName, extension: "txt", content: content)
    }

    // MARK: - 并发测试助手

    /// 并发执行多个操作并等待完成
    func performConcurrentOperations(
        operations: [() -> Void],
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "并发操作完成")
        expectation.expectedFulfillmentCount = operations.count
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for operation in operations {
            concurrentQueue.async {
                operation()
                expectation.fulfill()
            }
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("并发操作超时", file: file, line: line)
        }
    }

    /// 测试线程安全性
    func testThreadSafety<T>(
        operations: [(inout T) -> Void],
        initialValue: T,
        iterations: Int = 100,
        file: StaticString = #file,
        line: UInt = #line
    ) -> T {
        var sharedValue = initialValue
        let queue = DispatchQueue(label: "test.thread-safety", attributes: .concurrent)
        let group = DispatchGroup()
        
        for _ in 0..<iterations {
            for operation in operations {
                group.enter()
                queue.async(flags: .barrier) {
                    operation(&sharedValue)
                    group.leave()
                }
            }
        }
        
        let result = group.wait(timeout: .now() + 10)
        if result == .timedOut {
            XCTFail("线程安全测试超时", file: file, line: line)
        }
        
        return sharedValue
    }

    // MARK: - 错误测试助手

    /// 验证特定类型的错误被抛出
    func XCTAssertThrowsSpecificError<T, E: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        expectedError: E,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
            if let specificError = error as? E {
                XCTAssertEqual(specificError, expectedError, message, file: file, line: line)
            } else {
                XCTFail("抛出的错误类型不匹配。期望: \(E.self), 实际: \(type(of: error))", file: file, line: line)
            }
        }
    }
}

// MARK: - 测试环境管理

/// 测试环境管理器
class TestEnvironment {
    static let shared = TestEnvironment()
    
    private var temporaryFiles: [URL] = []
    
    private init() {}
    
    /// 注册临时文件以便自动清理
    func registerTemporaryFile(_ url: URL) {
        temporaryFiles.append(url)
    }
    
    /// 清理所有临时文件
    func cleanupAllTemporaryFiles() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
    }
    
    /// 重置测试环境
    func reset() {
        cleanupAllTemporaryFiles()
        // 重置其他全局状态
    }
}

// MARK: - 测试数据工厂

/// 测试数据工厂
enum TestDataFactory {
    
    /// 创建测试用的音频配置
    static func createAudioConfiguration(
        sampleRate: Double = 16000,
        channels: Int = 1,
        bufferSize: UInt32 = 1024
    ) -> AudioConfiguration {
        return AudioConfiguration(
            sampleRate: sampleRate,
            channels: channels,
            bufferSize: bufferSize,
            enableNoiseReduction: false,
            enableAudioEnhancement: false
        )
    }
    
    /// 创建测试用的识别配置
    static func createRecognitionConfiguration(
        numThreads: Int = 2,
        provider: String = "cpu"
    ) -> RecognitionConfiguration {
        return RecognitionConfiguration(
            modelPath: "models/test-model",
            numThreads: numThreads,
            provider: provider,
            enableEndpoint: true,
            debug: false,
            language: "zh"
        )
    }
    
    /// 创建测试用的热词条目
    static func createHotWordEntries(count: Int = 10) -> [HotWordEntry] {
        let samples = [
            ("测试", "test"),
            ("你好", "hello"),
            ("世界", "world"),
            ("开发", "development"),
            ("应用", "application"),
            ("系统", "system"),
            ("功能", "function"),
            ("语音", "voice"),
            ("识别", "recognition"),
            ("转录", "transcription")
        ]
        
        return Array(samples.prefix(count)).map { original, replacement in
            HotWordEntry(original: original, replacement: replacement, type: .chinese)
        }
    }
}