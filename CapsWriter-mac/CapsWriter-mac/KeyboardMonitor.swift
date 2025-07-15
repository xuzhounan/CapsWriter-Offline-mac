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
        guard !isRunning else { return }
        
        // 检查辅助功能权限
        if !AXIsProcessTrusted() {
            print("⚠️ 请在系统设置中启用辅助功能权限")
            print("  路径: 系统设置 → 隐私与安全性 → 辅助功能")
            print("  需要将 CapsWriter-mac 添加到允许列表中")
            requestAccessibilityPermission()
            return
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
        // 创建事件回调
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
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
            print("❌ 无法创建事件监听器")
            return
        }
        
        // 创建运行循环源
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            print("❌ 无法创建运行循环源")
            return
        }
        
        // 添加到运行循环
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // 启用事件监听
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isRunning = true
        print("✅ 键盘监听器已启动")
        print("📝 按住右 Shift 键开始录音，释放结束录音")
        
        // 运行循环
        CFRunLoopRun()
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 获取键码
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 只处理右 Shift 键
        guard keyCode == rightShiftKeyCode else {
            return Unmanaged.passUnretained(event)
        }
        
        switch type {
        case .keyDown:
            if !rightShiftPressed {
                rightShiftPressed = true
                DispatchQueue.main.async { [weak self] in
                    self?.handleRightShiftPressed()
                }
            }
            
        case .keyUp:
            if rightShiftPressed {
                rightShiftPressed = false
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