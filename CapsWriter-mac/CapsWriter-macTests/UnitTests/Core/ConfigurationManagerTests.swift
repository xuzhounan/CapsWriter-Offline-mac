import XCTest
import Combine
@testable import CapsWriter_mac

class ConfigurationManagerTests: XCTestCase {

    var configManager: ConfigurationManager!
    var cancellables: Set<AnyCancellable>!
    private let testUserDefaults = UserDefaults(suiteName: "CapsWriterTests")!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // 清理测试环境
        testUserDefaults.removePersistentDomain(forName: "CapsWriterTests")
        
        // 创建使用测试 UserDefaults 的配置管理器
        configManager = ConfigurationManager(userDefaults: testUserDefaults)
    }

    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        testUserDefaults.removePersistentDomain(forName: "CapsWriterTests")
        configManager = nil
        super.tearDown()
    }

    // MARK: - 基础配置测试

    func testDefaultConfiguration() {
        // Given - 新建的配置管理器

        // When
        configManager.load()

        // Then - 验证默认配置值
        XCTAssertEqual(configManager.audio.sampleRate, 16000, "默认采样率应该是 16kHz")
        XCTAssertEqual(configManager.audio.channels, 1, "默认应该是单声道")
        XCTAssertEqual(configManager.audio.bufferSize, 1024, "默认缓冲区大小应该是 1024")
        XCTAssertFalse(configManager.audio.enableNoiseReduction, "默认不启用噪声消除")

        XCTAssertEqual(configManager.recognition.numThreads, 2, "默认线程数应该是 2")
        XCTAssertEqual(configManager.recognition.provider, "cpu", "默认提供者应该是 CPU")
        XCTAssertTrue(configManager.recognition.enableEndpoint, "默认应该启用端点检测")

        XCTAssertTrue(configManager.general.enableStartup, "默认启用开机启动")
        XCTAssertFalse(configManager.general.enableDebug, "默认关闭调试模式")
    }

    func testConfigurationValidation() {
        // Given
        configManager.load()

        // When & Then - 测试音频配置验证
        XCTAssertTrue(configManager.audio.isValid(), "默认音频配置应该有效")

        // 测试无效配置
        configManager.audio.sampleRate = -1
        XCTAssertFalse(configManager.audio.isValid(), "无效采样率应该验证失败")

        configManager.audio.channels = 0
        XCTAssertFalse(configManager.audio.isValid(), "零声道应该验证失败")

        // When & Then - 测试识别配置验证
        configManager.recognition.numThreads = -1
        XCTAssertFalse(configManager.recognition.isValid(), "负线程数应该验证失败")

        configManager.recognition.maxActivePaths = 0
        XCTAssertFalse(configManager.recognition.isValid(), "零路径数应该验证失败")
    }

    // MARK: - 配置保存和加载测试

    func testSaveAndLoadConfiguration() throws {
        // Given - 修改配置
        configManager.load()
        configManager.audio.sampleRate = 22050
        configManager.audio.enableNoiseReduction = true
        configManager.recognition.numThreads = 4
        configManager.recognition.enableEndpoint = false
        configManager.general.enableDebug = true
        configManager.general.language = "en"

        // When - 保存配置
        try configManager.save()

        // Create new manager to verify persistence
        let newConfigManager = ConfigurationManager(userDefaults: testUserDefaults)
        newConfigManager.load()

        // Then - 验证加载的配置
        XCTAssertEqual(newConfigManager.audio.sampleRate, 22050, "采样率应该持久化")
        XCTAssertTrue(newConfigManager.audio.enableNoiseReduction, "噪声消除设置应该持久化")
        XCTAssertEqual(newConfigManager.recognition.numThreads, 4, "线程数应该持久化")
        XCTAssertFalse(newConfigManager.recognition.enableEndpoint, "端点检测设置应该持久化")
        XCTAssertTrue(newConfigManager.general.enableDebug, "调试模式应该持久化")
        XCTAssertEqual(newConfigManager.general.language, "en", "语言设置应该持久化")
    }

    func testSaveErrorHandling() {
        // Given - 模拟保存错误的场景
        configManager.load()
        
        // 设置无效配置
        configManager.audio.sampleRate = -1

        // When & Then
        XCTAssertThrowsError(try configManager.save()) { error in
            XCTAssertTrue(error is ConfigurationError, "应该抛出配置错误")
        }
    }

    // MARK: - 响应式配置更新测试

    func testConfigurationPublishing() {
        // Given
        configManager.load()
        let expectation = XCTestExpectation(description: "配置更新通知")
        var receivedUpdates = 0

        // 订阅配置变化
        configManager.$audio
            .dropFirst() // 跳过初始值
            .sink { _ in
                receivedUpdates += 1
                if receivedUpdates == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When - 更新配置
        configManager.audio.sampleRate = 48000

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUpdates, 1, "应该收到一次配置更新通知")
    }

    func testMultipleConfigurationPublishing() {
        // Given
        configManager.load()
        let audioExpectation = XCTestExpectation(description: "音频配置更新")
        let recognitionExpectation = XCTestExpectation(description: "识别配置更新")

        var audioUpdates = 0
        var recognitionUpdates = 0

        configManager.$audio
            .dropFirst()
            .sink { _ in
                audioUpdates += 1
                if audioUpdates == 2 {
                    audioExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        configManager.$recognition
            .dropFirst()
            .sink { _ in
                recognitionUpdates += 1
                if recognitionUpdates == 1 {
                    recognitionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When - 更新多个配置
        configManager.audio.sampleRate = 32000
        configManager.audio.channels = 2
        configManager.recognition.numThreads = 8

        // Then
        wait(for: [audioExpectation, recognitionExpectation], timeout: 2.0)
        XCTAssertEqual(audioUpdates, 2, "应该收到两次音频配置更新")
        XCTAssertEqual(recognitionUpdates, 1, "应该收到一次识别配置更新")
    }

    // MARK: - 配置重置测试

    func testResetConfiguration() throws {
        // Given - 修改配置
        configManager.load()
        configManager.audio.sampleRate = 48000
        configManager.recognition.numThreads = 8
        configManager.general.enableDebug = true
        try configManager.save()

        // When - 重置配置
        configManager.reset()

        // Then - 验证重置为默认值
        XCTAssertEqual(configManager.audio.sampleRate, 16000, "音频配置应该重置为默认值")
        XCTAssertEqual(configManager.recognition.numThreads, 2, "识别配置应该重置为默认值")
        XCTAssertFalse(configManager.general.enableDebug, "通用配置应该重置为默认值")
    }

    // MARK: - 热词配置测试

    func testHotwordConfiguration() throws {
        // Given
        configManager.load()
        
        // When - 配置热词设置
        configManager.hotwords.enableChineseHotwords = true
        configManager.hotwords.enableEnglishHotwords = false
        configManager.hotwords.enableRuleReplacement = true
        configManager.hotwords.hotwordFiles = ["custom-hot-zh.txt", "custom-hot-en.txt"]

        try configManager.save()

        // Then - 验证热词配置
        let newManager = ConfigurationManager(userDefaults: testUserDefaults)
        newManager.load()

        XCTAssertTrue(newManager.hotwords.enableChineseHotwords, "中文热词应该启用")
        XCTAssertFalse(newManager.hotwords.enableEnglishHotwords, "英文热词应该关闭")
        XCTAssertTrue(newManager.hotwords.enableRuleReplacement, "规则替换应该启用")
        XCTAssertEqual(newManager.hotwords.hotwordFiles.count, 2, "应该有两个热词文件")
    }

    // MARK: - 快捷键配置测试

    func testShortcutConfiguration() throws {
        // Given
        configManager.load()

        // When - 配置快捷键
        configManager.shortcuts.recordingShortcut = "cmd+shift+r"
        configManager.shortcuts.enableGlobalShortcuts = false
        configManager.shortcuts.shortcutTriggerCount = 5

        try configManager.save()

        // Then - 验证快捷键配置
        let newManager = ConfigurationManager(userDefaults: testUserDefaults)
        newManager.load()

        XCTAssertEqual(newManager.shortcuts.recordingShortcut, "cmd+shift+r", "录音快捷键应该保存")
        XCTAssertFalse(newManager.shortcuts.enableGlobalShortcuts, "全局快捷键应该关闭")
        XCTAssertEqual(newManager.shortcuts.shortcutTriggerCount, 5, "触发次数应该保存")
    }

    // MARK: - UI 配置测试

    func testUIConfiguration() throws {
        // Given
        configManager.load()

        // When - 配置 UI 设置
        configManager.ui.enableFloatingWindow = false
        configManager.ui.windowOpacity = 0.8
        configManager.ui.enableAnimations = true
        configManager.ui.theme = "dark"

        try configManager.save()

        // Then - 验证 UI 配置
        let newManager = ConfigurationManager(userDefaults: testUserDefaults)
        newManager.load()

        XCTAssertFalse(newManager.ui.enableFloatingWindow, "浮动窗口应该关闭")
        XCTAssertEqual(newManager.ui.windowOpacity, 0.8, accuracy: 0.01, "窗口透明度应该保存")
        XCTAssertTrue(newManager.ui.enableAnimations, "动画应该启用")
        XCTAssertEqual(newManager.ui.theme, "dark", "主题应该保存")
    }

    // MARK: - 配置验证测试

    func testInvalidConfigurationPrevention() throws {
        // Given
        configManager.load()

        // When & Then - 测试无效音频配置
        configManager.audio.sampleRate = -1000
        XCTAssertThrowsError(try configManager.save(), "负采样率应该阻止保存")

        configManager.audio.sampleRate = 16000 // 恢复有效值
        configManager.audio.bufferSize = 0
        XCTAssertThrowsError(try configManager.save(), "零缓冲区大小应该阻止保存")

        // When & Then - 测试无效识别配置
        configManager.audio.bufferSize = 1024 // 恢复有效值
        configManager.recognition.numThreads = -1
        XCTAssertThrowsError(try configManager.save(), "负线程数应该阻止保存")

        configManager.recognition.numThreads = 2 // 恢复有效值
        configManager.recognition.maxActivePaths = -1
        XCTAssertThrowsError(try configManager.save(), "负活跃路径数应该阻止保存")
    }

    // MARK: - 性能测试

    func testConfigurationLoadPerformance() {
        // Given - 预填充大量配置数据
        for i in 0..<100 {
            testUserDefaults.set("value_\(i)", forKey: "test_key_\(i)")
        }

        // When & Then
        measure {
            let manager = ConfigurationManager(userDefaults: testUserDefaults)
            manager.load()
        }
    }

    func testConfigurationSavePerformance() throws {
        // Given
        configManager.load()

        // When & Then
        measure {
            do {
                try configManager.save()
            } catch {
                XCTFail("保存配置不应该失败: \(error)")
            }
        }
    }

    // MARK: - 并发访问测试

    func testConcurrentConfigurationAccess() {
        // Given
        configManager.load()
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "并发访问完成")
        expectation.expectedFulfillmentCount = 10

        // When - 并发访问配置
        for i in 0..<10 {
            concurrentQueue.async {
                // 读取配置
                let sampleRate = self.configManager.audio.sampleRate
                XCTAssertGreaterThan(sampleRate, 0, "应该读取到有效的采样率")

                // 写入配置
                self.configManager.audio.sampleRate = Double(16000 + i * 1000)

                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        
        // 验证最终状态是一致的
        XCTAssertGreaterThanOrEqual(configManager.audio.sampleRate, 16000, "采样率应该有效")
    }

    // MARK: - 内存管理测试

    func testMemoryLeaks() {
        weak var weakManager: ConfigurationManager?

        autoreleasepool {
            let manager = ConfigurationManager(userDefaults: testUserDefaults)
            weakManager = manager
            manager.load()
            try? manager.save()
        }

        // 给 ARC 一些时间清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakManager, "ConfigurationManager 应该被释放")
        }
    }

    // MARK: - 边界条件测试

    func testExtremeConfigurationValues() throws {
        // Given
        configManager.load()

        // When & Then - 测试极值
        configManager.audio.sampleRate = Double.greatestFiniteMagnitude
        XCTAssertThrowsError(try configManager.save(), "极大值应该被拒绝")

        configManager.audio.sampleRate = 16000 // 恢复
        configManager.recognition.rule1MinTrailingSilence = Float.infinity
        XCTAssertThrowsError(try configManager.save(), "无限值应该被拒绝")
    }

    func testEmptyStringConfiguration() throws {
        // Given
        configManager.load()

        // When
        configManager.recognition.modelPath = ""
        configManager.general.language = ""

        // Then - 空字符串可能是有效的，取决于业务逻辑
        // 根据实际需求调整这个测试
        XCTAssertNoThrow(try configManager.save(), "空字符串可能是有效配置")
    }

    // MARK: - 配置迁移测试

    func testConfigurationMigration() {
        // Given - 模拟旧版本配置格式
        testUserDefaults.set("old_value", forKey: "deprecated_key")
        testUserDefaults.set(1, forKey: "old_version")

        // When
        configManager.load()

        // Then - 验证迁移逻辑（如果实现了）
        // 这需要根据实际的迁移需求来实现
    }
}

// MARK: - 测试扩展

extension ConfigurationManagerTests {
    
    /// 测试配置文件导出
    func testConfigurationExport() throws {
        // Given
        configManager.load()
        configManager.audio.sampleRate = 48000
        configManager.recognition.numThreads = 4

        // When - 导出配置到文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_config.json")

        try configManager.exportConfiguration(to: tempURL)

        // Then - 验证导出的文件
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "配置文件应该存在")

        let data = try Data(contentsOf: tempURL)
        XCTAssertGreaterThan(data.count, 0, "配置文件应该有内容")

        // 清理
        try? FileManager.default.removeItem(at: tempURL)
    }

    /// 测试配置文件导入
    func testConfigurationImport() throws {
        // Given - 创建测试配置文件
        let testConfig = """
        {
            "audio": {
                "sampleRate": 32000,
                "channels": 2
            },
            "recognition": {
                "numThreads": 6
            }
        }
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("import_test_config.json")
        try testConfig.data(using: .utf8)?.write(to: tempURL)

        // When
        try configManager.importConfiguration(from: tempURL)

        // Then
        XCTAssertEqual(configManager.audio.sampleRate, 32000, "导入的采样率应该生效")
        XCTAssertEqual(configManager.audio.channels, 2, "导入的声道数应该生效")
        XCTAssertEqual(configManager.recognition.numThreads, 6, "导入的线程数应该生效")

        // 清理
        try? FileManager.default.removeItem(at: tempURL)
    }
}