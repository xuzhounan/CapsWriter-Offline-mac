import Foundation
import ApplicationServices
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    
    // Configuration manager
    private let configManager = ConfigurationManager.shared
    
    // 键盘配置 (now from config manager)
    private var primaryKeyCode: CGKeyCode {
        return CGKeyCode(configManager.keyboard.primaryKeyCode)
    }
    
    private var alternativeOKeyCodes: [CGKeyCode] {
        return [primaryKeyCode] // 使用配置的主键码
    }
    
    // 状态跟踪
    private var isRecording = false
    private var clickCount = 0
    private var lastClickTime: TimeInterval = 0
    
    private var clickInterval: TimeInterval {
        return configManager.keyboard.clickInterval
    }
    
    private var debounceInterval: TimeInterval {
        return configManager.keyboard.debounceInterval
    }
    
    private var requiredClicks: Int {
        return configManager.keyboard.requiredClicks
    }
    
    // 回调函数
    var startRecordingCallback: (() -> Void)?
    var stopRecordingCallback: (() -> Void)?
    
    init() {
        print("🔧🔧🔧 KeyboardMonitor 初始化开始 🔧🔧🔧")
        // 不再使用单独的队列
        print("🔧 KeyboardMonitor 对象创建中...")
        print("📝 监听配置:")
        print("  - 主键码: \(primaryKeyCode)")
        print("  - 备用键码: \(alternativeOKeyCodes)")
        print("  - 连击间隔: \(clickInterval)s")
        print("  - 防抖间隔: \(debounceInterval)s")
        print("  - 需要连击次数: \(requiredClicks)")
        print("  - 监听启用: \(configManager.keyboard.enabled)")
        print("✅✅✅ KeyboardMonitor 初始化完成 ✅✅✅")
    }
    
    deinit {
        print("🛑 KeyboardMonitor deinit 开始")
        stopMonitoring()
        // 清除回调函数引用，避免循环引用
        startRecordingCallback = nil
        stopRecordingCallback = nil
        print("🛑 KeyboardMonitor deinit 完成")
    }
    
    func startMonitoring() {
        print("🟢🟢🟢 KeyboardMonitor.startMonitoring() 被调用 🟢🟢🟢")
        
        guard !isRunning else { 
            print("⚠️ 键盘监听器已在运行中")
            return 
        }
        
        print("🟢 KeyboardMonitor.startMonitoring() 继续执行...")
        
        // 确保在主线程中执行
        if Thread.isMainThread {
            startMonitoringOnMainThread()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startMonitoringOnMainThread()
            }
        }
    }
    
    private func startMonitoringOnMainThread() {
        print("🔍🔍🔍 startMonitoringOnMainThread() 被调用 🔍🔍🔍")
        print("🔍 正在检查辅助功能权限...")
        RecordingState.shared.updateKeyboardMonitorStatus("正在检查权限...")
        
        // 检查辅助功能权限
        if !AXIsProcessTrusted() {
            print("⚠️ 缺少辅助功能权限")
            print("  路径: 系统设置 → 隐私与安全性 → 辅助功能")
            print("  需要将 CapsWriter-mac 添加到允许列表中")
            print("🔧 正在请求辅助功能权限...")
            
            RecordingState.shared.updateKeyboardMonitorStatus("等待权限授权...")
            RecordingState.shared.updateAccessibilityPermission(false)
            
            requestAccessibilityPermission()
            
            // 给用户一些时间来授予权限，然后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if AXIsProcessTrusted() {
                    print("✅ 辅助功能权限已获得，重新启动监听器")
                    RecordingState.shared.updateAccessibilityPermission(true)
                    self?.startMonitoringOnMainThread()
                } else {
                    print("❌ 仍然缺少辅助功能权限，请手动授权")
                    RecordingState.shared.updateKeyboardMonitorStatus("权限被拒绝")
                }
            }
            return
        }
        
        print("✅ 辅助功能权限已获得")
        print("🚀 正在启动键盘监听器...")
        
        RecordingState.shared.updateAccessibilityPermission(true)
        RecordingState.shared.updateKeyboardMonitorStatus("正在启动...")
        
        // 确保在主线程设置事件监听
        setupEventTap()
    }
    
    private func requestAccessibilityPermission() {
        // 创建一个提示权限的选项
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func setupEventTap() {
        print("🔧🔧🔧 setupEventTap() 被调用 🔧🔧🔧")
        print("🔧 正在设置事件监听器...")
        
        // 只监听 keyDown 事件
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        print("📋 事件掩码: \(eventMask)")
        print("🔍 主键码设定为: \(primaryKeyCode)")
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        guard let eventTap = eventTap else {
            print("❌ 无法创建事件监听器 - 可能权限不足或系统限制")
            print("💡 请确保在系统设置中已授予辅助功能权限")
            RecordingState.shared.updateKeyboardMonitorStatus("创建监听器失败")
            return
        }
        print("✅ 事件监听器创建成功")
        
        // 创建运行循环源
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            print("❌ 无法创建运行循环源")
            RecordingState.shared.updateKeyboardMonitorStatus("创建运行循环源失败")
            return
        }
        print("✅ 运行循环源创建成功")
        
        // 添加到主线程的运行循环
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        print("✅ 已添加到主运行循环")
        
        // 启用事件监听
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("✅ 事件监听已启用")
        
        isRunning = true
        print("✅ 键盘监听器已完全启动")
        print("📝 监听主键 (键码: \(primaryKeyCode))")
        print("🎤 连击\(requiredClicks)下主键开始/结束录音")
        
        // 不再直接设置状态，让调用方控制状态更新
        // RecordingState.shared.updateKeyboardMonitorStatus("正在监听")
        
        print("✅ 键盘监听器设置完成，使用主运行循环")
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 获取键码
        let keyCodeInt64 = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = CGKeyCode(keyCodeInt64)
        
        // 获取键名（用于调试）
        let keyName = getKeyNameFromKeyCode(keyCode)
        
        // 检查是否是配置的主键
        if alternativeOKeyCodes.contains(keyCode) && type == .keyDown {
            print("🔍 检测到主键按下，键码: \(keyCode), 键名: \(keyName)")
            
            let currentTime = Date().timeIntervalSince1970
            
            // 防抖检查
            if (currentTime - lastClickTime) < debounceInterval {
                print("⏱️ 主键按下过快，防抖忽略 (间隔: \(String(format: "%.3f", currentTime - lastClickTime))s)")
                return Unmanaged.passUnretained(event)
            }
            
            // 检查连击间隔
            if (currentTime - lastClickTime) > clickInterval {
                // 超过间隔时间，重置计数
                clickCount = 0
                print("🔄 重置连击计数 (上次点击时间: \(String(format: "%.3f", lastClickTime)), 当前时间: \(String(format: "%.3f", currentTime)), 间隔: \(String(format: "%.3f", currentTime - lastClickTime))s)")
            }
            
            clickCount += 1
            lastClickTime = currentTime
            
            print("🔢 主键第 \(clickCount) 次点击 (需要 \(requiredClicks) 次)")
            
            if clickCount >= requiredClicks {
                // 连击达到要求次数，切换录音状态
                clickCount = 0
                isRecording = !isRecording
                
                print("🎯 连击\(requiredClicks)次触发！当前录音状态: \(isRecording)")
                
                if isRecording {
                    print("🟢 连击\(requiredClicks)次 - 开始识别")
                    handleStartRecording()
                } else {
                    print("🔴 连击\(requiredClicks)次 - 停止识别")
                    handleStopRecording()
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleStartRecording() {
        print("🎤 开始识别")
        
        // 确保在主线程执行回调
        DispatchQueue.main.async { [weak self] in
            if let callback = self?.startRecordingCallback {
                callback()
                print("✅ 开始录音回调已执行")
            } else {
                print("❌ 回调函数不存在！")
            }
        }
    }
    
    private func handleStopRecording() {
        print("⏹️ 结束识别")
        
        // 确保在主线程执行回调
        DispatchQueue.main.async { [weak self] in
            if let callback = self?.stopRecordingCallback {
                callback()
                print("✅ 停止录音回调已执行")
            } else {
                print("❌ 回调函数不存在！")
            }
        }
    }
    
    func stopMonitoring() {
        guard isRunning else { return }
        
        print("🛑 正在停止键盘监听器...")
        
        // 确保在主线程执行
        if Thread.isMainThread {
            stopMonitoringOnMainThread()
        } else {
            DispatchQueue.main.sync { [weak self] in
                self?.stopMonitoringOnMainThread()
            }
        }
    }
    
    private func stopMonitoringOnMainThread() {
        isRunning = false
        
        // 停止事件监听
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            print("✅ 事件监听已停用")
        }
        
        // 移除运行循环源
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
            print("✅ 运行循环源已移除")
        }
        
        // 不再直接设置状态，让调用方控制状态更新
        // RecordingState.shared.updateKeyboardMonitorStatus("已停止")
        print("⏹️ 键盘监听器已停止")
    }
    
    // 将键码转换为键名的辅助函数
    private func getKeyNameFromKeyCode(_ keyCode: CGKeyCode) -> String {
        let keyNames: [CGKeyCode: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
            10: "§", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "Enter", 37: "l", 38: "j", 39: "'",
            40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape", 55: "Cmd", 56: "Shift", 57: "CapsLock", 58: "Option", 59: "Ctrl",
            60: "RightShift", 61: "RightOption", 62: "RightCtrl", 63: "Fn", 64: "F17", 65: ".", 66: "*", 67: "+",
            69: "NumLock", 70: "VolumeUp", 71: "VolumeDown", 72: "Mute", 75: "/", 76: "NumEnter", 78: "-",
            79: "F18", 80: "F19", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6",
            89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F16", 114: "Help", 115: "Home",
            116: "PageUp", 117: "ForwardDelete", 118: "F4", 119: "End", 120: "F2", 121: "PageDown", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        
        return keyNames[keyCode] ?? "Unknown(\(keyCode))"
    }
    
    // 设置回调函数
    func setCallbacks(startRecording: @escaping () -> Void, stopRecording: @escaping () -> Void) {
        print("📞 KeyboardMonitor: 设置回调函数...")
        startRecordingCallback = startRecording
        stopRecordingCallback = stopRecording
        print("✅ KeyboardMonitor: 回调函数已设置")
        print("📊 KeyboardMonitor: startRecordingCallback = \(startRecordingCallback != nil ? "存在" : "不存在")")
        print("📊 KeyboardMonitor: stopRecordingCallback = \(stopRecordingCallback != nil ? "存在" : "不存在")")
    }
    
    // 重置监听器状态
    func resetMonitoring() {
        print("🔄 重置键盘监听器...")
        stopMonitoring()
        
        // 重置状态
        clickCount = 0
        lastClickTime = 0
        isRecording = false
        
        print("🔄 状态已重置 - 连击计数: \(clickCount), 录音状态: \(isRecording)")
        
        // 短暂延迟后重新启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            print("🔄 重新启动键盘监听器...")
            self?.startMonitoring()
        }
    }
    
    // 强制重置连击状态（用于调试）
    func forceResetClickState() {
        print("🔄 强制重置连击状态")
        clickCount = 0
        lastClickTime = 0
        isRecording = false
        print("✅ 连击状态已重置 - 连击计数: \(clickCount), 录音状态: \(isRecording)")
    }
}

// MARK: - 辅助功能权限检查扩展
extension KeyboardMonitor {
    static func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}