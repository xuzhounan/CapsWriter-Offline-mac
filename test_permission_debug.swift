#!/usr/bin/env swift

import Foundation
import ApplicationServices
import AVFoundation

print("🔍 开始权限调试检查...")

// 检查辅助功能权限
print("\n1. 检查辅助功能权限:")
let hasAccessibilityPermission = AXIsProcessTrusted()
print("   AXIsProcessTrusted() = \(hasAccessibilityPermission)")

// 检查麦克风权限
print("\n2. 检查麦克风权限:")
let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
print("   AVCaptureDevice.authorizationStatus = \(microphoneStatus.rawValue)")
print("   对应状态: \(microphoneStatus == .authorized ? "已授权" : "未授权")")

switch microphoneStatus {
case .notDetermined:
    print("   状态详细: 未确定")
case .restricted:
    print("   状态详细: 受限制")
case .denied:
    print("   状态详细: 已拒绝")
case .authorized:
    print("   状态详细: 已授权")
@unknown default:
    print("   状态详细: 未知状态")
}

// 测试权限请求
print("\n3. 测试权限请求:")
if !hasAccessibilityPermission {
    print("   辅助功能权限未授权，尝试请求...")
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let newStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
    print("   请求后状态: \(newStatus)")
}

if microphoneStatus != .authorized {
    print("   麦克风权限未授权，需要在应用运行时请求")
}

print("\n✅ 权限调试检查完成")