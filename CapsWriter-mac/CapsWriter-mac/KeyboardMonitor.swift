import Foundation
import ApplicationServices
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorQueue: DispatchQueue?
    private var isRunning = false
    
    // 右 Shift 键的键码
    private let rightShiftKeyCode: CGKeyCode = 60
    
    // 状态跟踪
    private var rightShiftPressed = false
    
    // 回调函数
    var startRecordingCallback: (() -> Void)?
    var stopRecordingCallback: (() -> Void)?
    
    init() {
        monitorQueue = DispatchQueue(label: "com.capswriter.keyboard-monitor", qos: .userInitiated)
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !isRunning else { 
            print("⚠️ 键盘监听器已在运行中")
            return 
        }
        
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
                    self?.startMonitoring()
                } else {
                    print("❌ 仍然缺少辅助功能权限，请手动授权")
                    RecordingState.shared.updateKeyboardMonitorStatus("权限被拒绝")
                }
            }
            return
        }
        
        print("✅ 辅助功能权限已获得")
        print("🚀 正在启动键盘监听器...")
        
        // 确保状态在主线程更新
        DispatchQueue.main.async {
            RecordingState.shared.updateAccessibilityPermission(true)
            RecordingState.shared.updateKeyboardMonitorStatus("正在启动...")
        }
        
        monitorQueue?.async { [weak self] in
            self?.setupEventTap()
        }
    }
    
    private func requestAccessibilityPermission() {
        // 创建一个提示权限的选项
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func setupEventTap() {
        print("🔧 正在设置事件监听器...")
        
        // 创建事件回调
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        print("📋 事件掩码: \(eventMask)")
        
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
            return
        }
        print("✅ 运行循环源创建成功")
        
        // 添加到运行循环
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        print("✅ 已添加到运行循环")
        
        // 启用事件监听
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("✅ 事件监听已启用")
        
        isRunning = true
        print("✅ 键盘监听器已完全启动")
        print("📝 监听右 Shift 键 (键码: \(rightShiftKeyCode))")
        print("🎤 按住右 Shift 键开始录音，释放结束录音")
        
        // 确保状态更新在主线程
        DispatchQueue.main.async {
            RecordingState.shared.updateKeyboardMonitorStatus("正在监听")
        }
        
        // 运行循环
        print("🔄 开始运行事件循环...")
        CFRunLoopRun()
        print("⏹️ 事件循环已结束")
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 获取键码
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 调试：记录所有按键事件（仅限于特定键码范围以避免过多日志）
        if keyCode >= 54 && keyCode <= 62 { // Shift, Cmd, Option 键区域
            print("🔍 检测到按键事件: 键码=\(keyCode), 类型=\(type.rawValue), 目标键码=\(rightShiftKeyCode)")
        }
        
        // 只处理右 Shift 键
        guard keyCode == rightShiftKeyCode else {
            return Unmanaged.passUnretained(event)
        }
        
        print("✅ 检测到右 Shift 键事件: \(type.rawValue == 10 ? "按下" : "释放")")
        
        switch type {
        case .keyDown:
            if !rightShiftPressed {
                rightShiftPressed = true
                print("🎤 右 Shift 键按下 - 开始录音")
                DispatchQueue.main.async { [weak self] in
                    self?.handleRightShiftPressed()
                }
            }
            
        case .keyUp:
            if rightShiftPressed {
                rightShiftPressed = false
                print("⏹️ 右 Shift 键释放 - 停止录音")
                DispatchQueue.main.async { [weak self] in
                    self?.handleRightShiftReleased()
                }
            }
            
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleRightShiftPressed() {
        print("🎤 开始识别")
        startRecordingCallback?()
    }
    
    private func handleRightShiftReleased() {
        print("⏹️ 结束识别")
        stopRecordingCallback?()
    }
    
    func stopMonitoring() {
        guard isRunning else { return }
        
        isRunning = false
        
        // 停止事件监听
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        // 移除运行循环源
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        // 停止运行循环
        CFRunLoopStop(CFRunLoopGetCurrent())
        
        RecordingState.shared.updateKeyboardMonitorStatus("已停止")
        print("⏹️ 键盘监听器已停止")
    }
    
    // 设置回调函数
    func setCallbacks(startRecording: @escaping () -> Void, stopRecording: @escaping () -> Void) {
        startRecordingCallback = startRecording
        stopRecordingCallback = stopRecording
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