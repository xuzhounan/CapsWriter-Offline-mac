import Foundation
import ApplicationServices
import Carbon

class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    
    // O 键的键码（美式键盘）
    private let oKeyCode: CGKeyCode = 31
    
    // 备用的 O 键码（一些键盘可能使用不同的码）
    private let alternativeOKeyCodes: [CGKeyCode] = [31]
    
    // 状态跟踪
    private var isRecording = false
    private var clickCount = 0
    private var lastClickTime: TimeInterval = 0
    private let clickInterval: TimeInterval = 0.8 // 800ms 连击间隔
    private let debounceInterval: TimeInterval = 0.1 // 100ms 防抖间隔
    private let requiredClicks = 3 // 需要连击3次
    
    // 回调函数
    var startRecordingCallback: (() -> Void)?
    var stopRecordingCallback: (() -> Void)?
    
    init() {
        // 不再使用单独的队列
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !isRunning else { 
            print("⚠️ 键盘监听器已在运行中")
            return 
        }
        
        print("🟢 KeyboardMonitor.startMonitoring() 被调用")
        
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
        print("🔧 正在设置事件监听器...")
        
        // 只监听 keyDown 事件
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        print("📋 事件掩码: \(eventMask)")
        print("🔍 O键码设定为: \(oKeyCode)")
        
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
        print("📝 监听 O 键 (键码: \(oKeyCode))")
        print("🎤 连击3下 O 键开始/结束录音")
        
        // 更新状态
        RecordingState.shared.updateKeyboardMonitorStatus("正在监听")
        
        print("✅ 键盘监听器设置完成，使用主运行循环")
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 获取键码
        let keyCodeInt64 = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = CGKeyCode(keyCodeInt64)
        
        // 检查是否是 O 键
        if alternativeOKeyCodes.contains(keyCode) && type == .keyDown {
            print("🔍 检测到 O 键按下，键码: \(keyCode)")
            
            let currentTime = Date().timeIntervalSince1970
            
            // 防抖检查
            if (currentTime - lastClickTime) < debounceInterval {
                print("⏱️ O 键按下过快，防抖忽略 (间隔: \(String(format: "%.3f", currentTime - lastClickTime))s)")
                return Unmanaged.passUnretained(event)
            }
            
            // 检查连击间隔
            if (currentTime - lastClickTime) > clickInterval {
                // 超过间隔时间，重置计数
                clickCount = 0
                print("🔄 重置连击计数")
            }
            
            clickCount += 1
            lastClickTime = currentTime
            
            print("🔢 O 键第 \(clickCount) 次点击")
            
            if clickCount >= requiredClicks {
                // 连击3次，切换录音状态
                clickCount = 0
                isRecording = !isRecording
                
                print("🎯 连击3次触发！当前录音状态: \(isRecording)")
                
                if isRecording {
                    print("🟢 连击3次 - 开始识别")
                    handleStartRecording()
                } else {
                    print("🔴 连击3次 - 停止识别")
                    handleStopRecording()
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleStartRecording() {
        print("🎤 开始识别")
        print("📞 准备调用 startRecordingCallback")
        
        // 确保在主线程执行回调
        DispatchQueue.main.async { [weak self] in
            if let callback = self?.startRecordingCallback {
                print("✅ 回调函数存在，正在调用...")
                callback()
                print("✅ 回调函数已调用")
            } else {
                print("❌ 回调函数不存在！")
            }
        }
    }
    
    private func handleStopRecording() {
        print("⏹️ 结束识别")
        print("📞 准备调用 stopRecordingCallback")
        
        // 确保在主线程执行回调
        DispatchQueue.main.async { [weak self] in
            if let callback = self?.stopRecordingCallback {
                print("✅ 回调函数存在，正在调用...")
                callback()
                print("✅ 回调函数已调用")
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
        
        RecordingState.shared.updateKeyboardMonitorStatus("已停止")
        print("⏹️ 键盘监听器已停止")
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
        
        // 短暂延迟后重新启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startMonitoring()
        }
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