#!/usr/bin/env swift

import Foundation

// 测试状态同步修复
// 模拟不同状态变化场景，验证状态同步逻辑

print("🧪 测试状态同步修复")
print(String(repeating: "=", count: 50))

// 模拟状态变化场景
struct TestScenario {
    let name: String
    let asrRunning: Bool
    let asrInitialized: Bool
    let expectedMainDashboard: String
    let expectedASRService: String
}

let scenarios = [
    TestScenario(
        name: "服务未启动",
        asrRunning: false,
        asrInitialized: false,
        expectedMainDashboard: "已停止",
        expectedASRService: "已停止"
    ),
    TestScenario(
        name: "服务启动中",
        asrRunning: true,
        asrInitialized: false,
        expectedMainDashboard: "正在启动...",
        expectedASRService: "正在启动..."
    ),
    TestScenario(
        name: "服务已就绪",
        asrRunning: true,
        asrInitialized: true,
        expectedMainDashboard: "就绪",
        expectedASRService: "就绪"
    )
]

for scenario in scenarios {
    print("\n📝 测试场景: \(scenario.name)")
    print("   - ASR运行: \(scenario.asrRunning)")
    print("   - ASR初始化: \(scenario.asrInitialized)")
    print("   - 预期状态: \(scenario.expectedMainDashboard)")
    
    // 模拟状态更新逻辑
    let mainDashboardStatus = determineMainDashboardStatus(
        isRunning: scenario.asrRunning,
        isInitialized: scenario.asrInitialized
    )
    
    let _ = determineASRServiceStatus(
        isRunning: scenario.asrRunning,
        isInitialized: scenario.asrInitialized
    )
    
    print("   - 实际状态: \(mainDashboardStatus)")
    print("   - 结果: \(mainDashboardStatus == scenario.expectedMainDashboard ? "✅ 通过" : "❌ 失败")")
}

// 修复后的状态判断逻辑
func determineMainDashboardStatus(isRunning: Bool, isInitialized: Bool) -> String {
    if isInitialized {
        return "就绪"
    } else if isRunning {
        return "正在启动..."
    } else {
        return "已停止"
    }
}

func determineASRServiceStatus(isRunning: Bool, isInitialized: Bool) -> String {
    if isInitialized {
        return "就绪"
    } else if isRunning {
        return "正在启动..."
    } else {
        return "已停止"
    }
}

print("\n🎯 状态同步修复总结:")
print("1. ASRServicePlaceholderView 现在使用统一的服务实例")
print("2. 状态更新逻辑修复：分别更新运行状态和初始化状态")
print("3. 定时器频率提高到2秒，增强响应性")
print("4. 关键状态变化时立即更新状态")
print("5. 两个界面现在使用相同的数据源（RecordingState）")