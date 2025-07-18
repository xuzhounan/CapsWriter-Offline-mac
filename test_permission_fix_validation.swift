#!/usr/bin/env swift

import Foundation
import ApplicationServices
import AVFoundation

print("🧪 权限修复验证测试")
print("====================")

// 模拟 RecordingState 的新权限检查逻辑
func checkAccessibilityPermission() -> Bool {
    return AXIsProcessTrusted()
}

func checkMicrophonePermission() -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    return (status == .authorized || status == .notDetermined)
}

func getMicrophoneStatusDescription(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
        return "未确定（可以使用）"
    case .restricted:
        return "受限制"
    case .denied:
        return "已拒绝"
    case .authorized:
        return "已授权"
    @unknown default:
        return "未知状态"
    }
}

print("\n🔍 执行修复后的权限检查逻辑:")

// 1. 检查辅助功能权限
let accessibilityPermission = checkAccessibilityPermission()
print("🔐 辅助功能权限 = \(accessibilityPermission)")

// 2. 检查麦克风权限（使用新逻辑）
let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
let microphonePermission = checkMicrophonePermission()

print("🎤 麦克风权限状态原始值 = \(microphoneAuthStatus.rawValue)")
print("🎤 麦克风权限状态描述 = \(getMicrophoneStatusDescription(microphoneAuthStatus))")
print("🎤 麦克风权限（新逻辑）= \(microphonePermission)")

// 3. 检查文本输入权限
let textInputPermission = accessibilityPermission
print("📝 文本输入权限 = \(textInputPermission)")

print("\n📊 修复结果总结:")
print("==================")
print("✅ 辅助功能权限: \(accessibilityPermission ? "通过" : "需要授权")")
print("✅ 麦克风权限: \(microphonePermission ? "通过" : "需要授权")")
print("✅ 文本输入权限: \(textInputPermission ? "通过" : "需要授权")")

let allPermissionsOK = accessibilityPermission && microphonePermission && textInputPermission
print("\n🎯 总体状态: \(allPermissionsOK ? "✅ 所有权限正常" : "❌ 部分权限需要处理")")

if !allPermissionsOK {
    print("\n💡 权限处理建议:")
    if !accessibilityPermission {
        print("  - 需要在系统设置中授予辅助功能权限")
    }
    if !microphonePermission {
        print("  - 麦克风权限被明确拒绝，需要在系统设置中重新授权")
    }
}