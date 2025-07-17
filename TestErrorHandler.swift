import Foundation

/// 错误处理器测试脚本
/// 验证 ErrorHandler 的基本功能
class TestErrorHandler {
    
    static func runAllTests() {
        print("🧪 开始 ErrorHandler 功能测试...\n")
        
        testBasicErrorReporting()
        testErrorSeverityClassification()
        testErrorRecoveryStrategies()
        testErrorResolution()
        testErrorStatistics()
        testConvenienceMethods()
        
        print("\n✅ ErrorHandler 测试完成!")
    }
    
    /// 测试基本错误报告功能
    static func testBasicErrorReporting() {
        print("📋 测试 1: 基本错误报告")
        
        let errorHandler = ErrorHandler.shared
        let initialCount = errorHandler.activeErrors.count
        
        // 报告一个配置错误
        errorHandler.reportConfigurationError("测试配置错误")
        
        // 验证错误是否被正确记录
        assert(errorHandler.activeErrors.count == initialCount + 1, "错误未被正确记录")
        
        let lastError = errorHandler.activeErrors.last!
        assert(lastError.context.component == "Configuration", "组件名称不正确")
        assert(lastError.severity == .medium, "错误严重程度分类不正确")
        
        print("   ✅ 基本错误报告功能正常")
    }
    
    /// 测试错误严重程度分类
    static func testErrorSeverityClassification() {
        print("📋 测试 2: 错误严重程度分类")
        
        let errorHandler = ErrorHandler.shared
        
        // 测试不同类型错误的严重程度
        errorHandler.reportPermissionError("测试权限", message: "权限被拒绝")
        let permissionError = errorHandler.activeErrors.last!
        assert(permissionError.severity == .critical, "权限错误应为严重级别")
        
        errorHandler.reportServiceError("测试服务", message: "服务初始化失败")
        let serviceError = errorHandler.activeErrors.last!
        assert(serviceError.severity == .high, "服务错误应为高级别")
        
        errorHandler.reportModelError("测试模型", message: "模型加载失败")
        let modelError = errorHandler.activeErrors.last!
        assert(modelError.severity == .high, "模型错误应为高级别")
        
        print("   ✅ 错误严重程度分类正确")
    }
    
    /// 测试错误恢复策略
    static func testErrorRecoveryStrategies() {
        print("📋 测试 3: 错误恢复策略")
        
        let errorHandler = ErrorHandler.shared
        
        // 测试不同错误类型的恢复策略
        errorHandler.reportError(
            .permissionDenied("权限测试"),
            context: ErrorHandler.ErrorContext(component: "Test", operation: "权限检查")
        )
        let permissionError = errorHandler.activeErrors.last!
        assert(permissionError.recoveryStrategy == .userAction, "权限错误应使用用户操作策略")
        
        errorHandler.reportError(
            .serviceInitializationFailed("服务测试"),
            context: ErrorHandler.ErrorContext(component: "Test", operation: "服务初始化")
        )
        let serviceError = errorHandler.activeErrors.last!
        assert(serviceError.recoveryStrategy == .restart, "服务错误应使用重启策略")
        
        errorHandler.reportError(
            .modelLoadFailed("模型测试"),
            context: ErrorHandler.ErrorContext(component: "Test", operation: "模型加载")
        )
        let modelError = errorHandler.activeErrors.last!
        assert(modelError.recoveryStrategy == .retry, "模型错误应使用重试策略")
        
        print("   ✅ 错误恢复策略分配正确")
    }
    
    /// 测试错误解决功能
    static func testErrorResolution() {
        print("📋 测试 4: 错误解决功能")
        
        let errorHandler = ErrorHandler.shared
        
        // 报告一个错误
        errorHandler.reportUnknownError("Test", operation: "测试操作", message: "测试错误")
        let testError = errorHandler.activeErrors.last!
        let errorId = testError.id
        
        // 验证错误初始状态
        assert(!testError.isResolved, "新错误不应该被标记为已解决")
        assert(testError.resolvedAt == nil, "新错误不应该有解决时间")
        
        // 解决错误
        errorHandler.markErrorResolved(errorId)
        
        // 给系统一点时间处理
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证错误已被解决
        if let resolvedError = errorHandler.activeErrors.first(where: { $0.id == errorId }) {
            assert(resolvedError.isResolved, "错误应该被标记为已解决")
            assert(resolvedError.resolvedAt != nil, "已解决的错误应该有解决时间")
        }
        
        print("   ✅ 错误解决功能正常")
    }
    
    /// 测试错误统计功能
    static func testErrorStatistics() {
        print("📋 测试 5: 错误统计功能")
        
        let errorHandler = ErrorHandler.shared
        let initialStats = errorHandler.errorStats
        
        let initialTotal = initialStats.totalErrors
        let initialCritical = initialStats.criticalErrors
        
        // 报告一个严重错误
        errorHandler.reportPermissionError("统计测试", message: "权限统计测试")
        
        // 验证统计更新
        assert(errorHandler.errorStats.totalErrors == initialTotal + 1, "总错误数应该增加")
        assert(errorHandler.errorStats.criticalErrors == initialCritical + 1, "严重错误数应该增加")
        
        // 测试组件统计
        let componentStats = errorHandler.getErrorStatistics(for: "Permission")
        assert(componentStats.totalErrors > 0, "组件统计应该记录错误")
        
        print("   ✅ 错误统计功能正常")
    }
    
    /// 测试便捷方法
    static func testConvenienceMethods() {
        print("📋 测试 6: 便捷错误报告方法")
        
        let errorHandler = ErrorHandler.shared
        let initialCount = errorHandler.activeErrors.count
        
        // 测试各种便捷方法
        errorHandler.reportConfigurationError("便捷配置错误")
        errorHandler.reportServiceError("便捷服务", message: "便捷服务错误")
        errorHandler.reportPermissionError("便捷权限", message: "便捷权限错误")
        errorHandler.reportModelError("便捷模型", message: "便捷模型错误")
        errorHandler.reportUnknownError("便捷组件", operation: "便捷操作", message: "便捷未知错误")
        
        // 验证所有错误都被记录
        assert(errorHandler.activeErrors.count == initialCount + 5, "所有便捷方法应该都创建了错误记录")
        
        print("   ✅ 便捷错误报告方法正常")
    }
    
    /// 测试通知系统
    static func testNotificationSystem() {
        print("📋 测试 7: 通知系统")
        
        var notificationReceived = false
        
        // 监听错误通知
        let observer = NotificationCenter.default.addObserver(
            forName: .errorDidOccur,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        
        // 报告错误
        ErrorHandler.shared.reportUnknownError("通知测试", operation: "通知", message: "通知测试错误")
        
        // 给通知系统一点时间
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // 验证通知
        assert(notificationReceived, "错误通知应该被发送")
        
        // 清理
        NotificationCenter.default.removeObserver(observer)
        
        print("   ✅ 通知系统正常")
    }
    
    /// 输出测试摘要
    static func printTestSummary() {
        print("\n📊 ErrorHandler 测试摘要:")
        
        let errorHandler = ErrorHandler.shared
        print("- 活跃错误: \(errorHandler.activeErrors.count)")
        print("- 总错误数: \(errorHandler.errorStats.totalErrors)")
        print("- 严重错误: \(errorHandler.errorStats.criticalErrors)")
        print("- 高级错误: \(errorHandler.errorStats.highErrors)")
        print("- 中级错误: \(errorHandler.errorStats.mediumErrors)")
        print("- 低级错误: \(errorHandler.errorStats.lowErrors)")
        print("- 解决率: \(String(format: "%.1f%%", errorHandler.errorStats.resolutionRate * 100))")
        
        if let highestError = errorHandler.currentHighestSeverityError {
            print("- 最高严重程度: \(highestError.severity.rawValue)")
            print("- 错误描述: \(highestError.error.localizedDescription)")
        }
        
        print("\n🏁 调试信息:")
        print(errorHandler.debugDescription)
    }
    
    /// 清理测试数据
    static func cleanup() {
        print("\n🧹 清理测试数据...")
        ErrorHandler.shared.clearAllErrors()
        print("✅ 清理完成")
    }
}

// MARK: - 运行测试

/// 如果直接运行此文件，执行测试
if CommandLine.argc > 0 && CommandLine.arguments.contains("--run-tests") {
    TestErrorHandler.runAllTests()
    TestErrorHandler.printTestSummary()
    TestErrorHandler.cleanup()
}

/// 简单的测试运行器
class SimpleTestRunner {
    static func run() {
        print("🚀 启动 ErrorHandler 测试套件\n")
        
        TestErrorHandler.runAllTests()
        TestErrorHandler.testNotificationSystem()
        TestErrorHandler.printTestSummary()
        
        print("\n🎉 所有测试通过! ErrorHandler 功能正常。")
        
        // 可选：清理测试数据
        // TestErrorHandler.cleanup()
    }
}

// 可以在 Xcode 中或其他地方调用此方法来运行测试
// SimpleTestRunner.run()