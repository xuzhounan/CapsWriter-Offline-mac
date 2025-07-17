#!/usr/bin/env swift

import Foundation

// 模拟状态同步测试
print("🧪 开始测试状态同步逻辑...")

// 模拟不同的状态情况
struct ASRServiceStatus {
    let isRunning: Bool
    let isInitialized: Bool
}

func testStatusDisplay(_ status: ASRServiceStatus) -> String {
    if status.isInitialized {
        return "就绪"
    } else if status.isRunning {
        return "正在初始化..."
    } else {
        return "已停止"
    }
}

// 测试用例
let testCases = [
    ("服务未启动", ASRServiceStatus(isRunning: false, isInitialized: false)),
    ("服务启动中", ASRServiceStatus(isRunning: true, isInitialized: false)),
    ("服务已就绪", ASRServiceStatus(isRunning: true, isInitialized: true)),
    ("服务异常状态", ASRServiceStatus(isRunning: false, isInitialized: true)) // 不应该发生
]

print("📊 状态显示测试:")
for (description, status) in testCases {
    let displayText = testStatusDisplay(status)
    print("  \(description): \(displayText)")
}

print("✅ 状态同步逻辑测试完成")