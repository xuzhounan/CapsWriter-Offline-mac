import Foundation
import ApplicationServices
import AppKit

/// 文本输入服务 - 负责将语音识别结果转换为键盘输入
class TextInputService {
    
    // MARK: - Properties
    
    private let debounceInterval: TimeInterval = 0.5
    private var lastInputTime: Date = Date()
    private let inputQueue = DispatchQueue(label: "com.capswriter.text-input", qos: .userInteractive)
    
    // 权限状态缓存 - 避免重复日志输出
    private var cachedPermissionStatus: Bool?
    private var lastPermissionCheckTime: Date = Date.distantPast
    private let permissionCheckCooldown: TimeInterval = 1.0 // 1秒内不重复检查
    
    // 单例模式
    static let shared = TextInputService()
    
    private init() {
        print("⌨️ TextInputService 初始化")
    }
    
    // MARK: - Public Methods
    
    /// 检查是否有辅助功能权限（键盘输入需要此权限）
    func checkAccessibilityPermission() -> Bool {
        let now = Date()
        
        // 如果距离上次检查时间太短，直接返回缓存的结果
        if now.timeIntervalSince(lastPermissionCheckTime) < permissionCheckCooldown,
           let cached = cachedPermissionStatus {
            return cached
        }
        
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
        
        // 只有在权限状态发生变化时才输出日志
        if cachedPermissionStatus != trusted {
            print("⌨️ 辅助功能权限状态变化: \(trusted ? "✅ 已授权" : "❌ 未授权")")
            cachedPermissionStatus = trusted
        }
        
        lastPermissionCheckTime = now
        return trusted
    }
    
    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        print("⌨️ 请求辅助功能权限...")
        let _ = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
    }
    
    /// 模拟键盘输入文本
    /// - Parameter text: 要输入的文本
    func inputText(_ text: String) {
        guard !text.isEmpty else {
            print("⚠️ 输入文本为空，跳过")
            return
        }
        
        // 检查权限
        guard checkAccessibilityPermission() else {
            print("❌ 没有辅助功能权限，无法输入文本")
            return
        }
        
        // 防抖处理：避免过于频繁的输入
        let now = Date()
        if now.timeIntervalSince(lastInputTime) < debounceInterval {
            print("⏱️ 输入过于频繁，跳过: \(text)")
            return
        }
        lastInputTime = now
        
        print("⌨️ 准备输入文本: \(text)")
        
        // 在后台队列执行输入操作，避免阻塞主线程
        inputQueue.async { [weak self] in
            self?.performTextInput(text)
        }
    }
    
    /// 模拟按键输入（用于特殊键，如回车、删除等）
    /// - Parameter keyCode: 虚拟按键码
    func inputKey(_ keyCode: CGKeyCode, withModifiers modifiers: CGEventFlags = []) {
        guard checkAccessibilityPermission() else {
            print("❌ 没有辅助功能权限，无法输入按键")
            return
        }
        
        inputQueue.async {
            self.performKeyInput(keyCode, withModifiers: modifiers)
        }
    }
    
    /// 输入回车键
    func inputEnter() {
        print("⌨️ 输入回车键")
        inputKey(36) // Return key
    }
    
    /// 输入退格键
    func inputBackspace() {
        print("⌨️ 输入退格键")
        inputKey(51) // Delete key
    }
    
    /// 清空当前行（Cmd+A + Delete）
    func clearCurrentLine() {
        print("⌨️ 清空当前行")
        inputKey(0, withModifiers: .maskCommand) // Cmd+A
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            self.inputKey(51) // Delete
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行文本输入的核心逻辑
    private func performTextInput(_ text: String) {
        print("⌨️ 开始输入文本: \(text)")
        
        // 获取当前活动的应用程序
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        print("🎯 当前活动应用: \(frontmostApp?.localizedName ?? "未知")")
        
        // 使用 CGEvent 模拟键盘输入
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 遍历每个字符并创建键盘事件
        for char in text {
            if let keyCode = getKeyCodeForCharacter(char) {
                // 对于普通字符，使用按键事件
                let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                
                // 设置字符
                keyDownEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.unicodeScalars.first!.value)])
                keyUpEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.unicodeScalars.first!.value)])
                
                // 发送事件
                keyDownEvent?.post(tap: .cghidEventTap)
                keyUpEvent?.post(tap: .cghidEventTap)
                
                // 轻微延迟，模拟真实的按键间隔
                usleep(1000) // 1ms
            } else {
                // 对于无法映射到按键的字符，使用 Unicode 输入
                inputUnicodeCharacter(char)
            }
        }
        
        print("✅ 文本输入完成: \(text)")
    }
    
    /// 执行按键输入
    private func performKeyInput(_ keyCode: CGKeyCode, withModifiers modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("❌ 无法创建按键事件")
            return
        }
        
        // 设置修饰键
        if !modifiers.isEmpty {
            keyDownEvent.flags = modifiers
            keyUpEvent.flags = modifiers
        }
        
        // 发送事件
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("✅ 按键输入完成: keyCode=\(keyCode), modifiers=\(modifiers)")
    }
    
    /// 输入 Unicode 字符
    private func inputUnicodeCharacter(_ char: Character) {
        let source = CGEventSource(stateID: .hidSystemState)
        let unicodeEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        
        let unicodeValue = char.unicodeScalars.first?.value ?? 0
        unicodeEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(unicodeValue)])
        unicodeEvent?.post(tap: .cghidEventTap)
        
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// 获取字符对应的虚拟按键码
    private func getKeyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        // 基本字母和数字的映射
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
            "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34, "J": 38,
            "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12, "R": 15, "S": 1,
            "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            " ": 49, // Space
            ".": 47, ",": 43, "?": 44, "!": 18, // 需要 Shift
            "\n": 36, "\r": 36, // Return
        ]
        
        return keyMap[char]
    }
}

// MARK: - Extensions

extension TextInputService {
    /// 格式化文本（添加标点符号、处理换行等）
    func formatTextForInput(_ text: String) -> String {
        var formattedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 基本的标点符号处理
        if !formattedText.isEmpty && !formattedText.hasSuffix(".") && !formattedText.hasSuffix("。") &&
           !formattedText.hasSuffix("!") && !formattedText.hasSuffix("！") &&
           !formattedText.hasSuffix("?") && !formattedText.hasSuffix("？") {
            // 如果文本看起来像完整的句子，添加句号
            if formattedText.count > 3 {
                formattedText += "。"
            }
        }
        
        return formattedText
    }
    
    /// 检查文本是否应该输入（过滤掉过短或无意义的文本）
    func shouldInputText(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 过短的文本不输入
        if trimmedText.count < 2 {
            return false
        }
        
        // 纯数字或符号不输入（可能是识别错误）
        let alphanumericSet = CharacterSet.alphanumerics
        let chineseRange = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
        let validSet = alphanumericSet.union(chineseRange)
        
        if trimmedText.unicodeScalars.allSatisfy({ !validSet.contains($0) }) {
            return false
        }
        
        return true
    }
}