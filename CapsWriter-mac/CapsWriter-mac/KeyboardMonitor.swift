import Foundation
import ApplicationServices
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorQueue: DispatchQueue?
    private var isRunning = false
    
    // 右 Shift 键的键码（可能因键盘布局而异）
    private let rightShiftKeyCode: CGKeyCode = 60
    
    // 备用的右 Shift 键码（一些键盘可能使用不同的码）
    private let alternativeRightShiftKeyCodes: [CGKeyCode] = [60, 124, 56]
    
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
        
        // 在后台线程启动事件监听
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
        
        // 创建事件回调 - 监听所有键盘事件以便调试
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        print("📋 事件掩码: \(eventMask)")
        print("🔍 右Shift键码设定为: \(rightShiftKeyCode)")
        
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
        
        // 添加到当前线程的运行循环
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
        
        // 在后台线程中运行事件循环
        print("🔄 开始运行事件循环...")
        CFRunLoopRun()
        print("⏹️ 事件循环已结束")
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 获取键码并转换为正确的类型
        let keyCodeInt64 = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = CGKeyCode(keyCodeInt64)
        
        // 记录所有键盘事件进行调试
        print("🔍 键盘事件: 键码=\(keyCode)(\(getKeyName(for: keyCode))), 类型=\(type.rawValue)")
        
        // 详细检查右 Shift 键（包括备用键码）
        if alternativeRightShiftKeyCodes.contains(keyCode) {
            print("✅ 检测到右 Shift 键事件: \(type.rawValue == 10 ? "按下(keyDown)" : type.rawValue == 11 ? "释放(keyUp)" : "其他类型(\(type.rawValue))")")
            
            switch type {
            case .keyDown:
                if !rightShiftPressed {
                    rightShiftPressed = true
                    print("🎤 右 Shift 键按下 - 开始录音")
                    DispatchQueue.main.async { [weak self] in
                        self?.handleRightShiftPressed()
                    }
                } else {
                    print("⚠️ 右 Shift 键重复按下事件")
                }
                
            case .keyUp:
                if rightShiftPressed {
                    rightShiftPressed = false
                    print("⏹️ 右 Shift 键释放 - 停止录音")
                    DispatchQueue.main.async { [weak self] in
                        self?.handleRightShiftReleased()
                    }
                } else {
                    print("⚠️ 右 Shift 键释放但之前未检测到按下")
                }
                
            default:
                print("❓ 右 Shift 键未知事件类型: \(type.rawValue)")
                break
            }
        } else {
            // 记录其他可能相关的键
            let keyName = getKeyName(for: keyCode)
            if keyCode >= 50 && keyCode <= 65 { // 包含所有修饰键区域
                print("🔸 其他修饰键: \(keyName) (键码=\(keyCode))")
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // 辅助方法：获取键名
    private func getKeyName(for keyCode: CGKeyCode) -> String {
        switch keyCode {
        case 54: return "右Command"
        case 55: return "左Command"
        case 56: return "左Shift"
        case 57: return "Caps Lock"
        case 58: return "左Option"
        case 59: return "左Control"
        case 60: return "右Shift"
        case 61: return "右Option"
        case 62: return "右Control"
        case 63: return "Fn"
        case 124: return "右Shift(备用)"
        default: 
            if keyCode >= 0 && keyCode <= 127 {
                return "键(\(keyCode))"
            } else {
                return "未知键(\(keyCode))"
            }
        }
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
        
        print("🛑 正在停止键盘监听器...")
        isRunning = false
        
        // 在监听线程中停止
        monitorQueue?.async { [weak self] in
            guard let self = self else { return }
            
            // 停止事件监听
            if let eventTap = self.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
                self.eventTap = nil
                print("✅ 事件监听已停用")
            }
            
            // 移除运行循环源
            if let runLoopSource = self.runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
                print("✅ 运行循环源已移除")
            }
            
            // 停止运行循环
            CFRunLoopStop(CFRunLoopGetCurrent())
            print("✅ 运行循环已停止")
        }
        
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