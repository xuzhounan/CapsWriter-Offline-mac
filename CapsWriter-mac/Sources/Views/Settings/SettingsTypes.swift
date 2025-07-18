import Foundation
import SwiftUI

// MARK: - Settings Architecture Types

/// 设置分类枚举
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "通用"
    case audio = "音频"
    case recognition = "识别"
    case hotwords = "热词"
    case shortcuts = "快捷键"
    case advanced = "高级"
    case about = "关于"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "speaker.wave.2"
        case .recognition: return "waveform.path.ecg"
        case .hotwords: return "text.word.spacing"
        case .shortcuts: return "keyboard"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "应用基础设置和偏好"
        case .audio: return "音频设备和录音设置"
        case .recognition: return "语音识别引擎配置"
        case .hotwords: return "热词替换规则管理"
        case .shortcuts: return "键盘快捷键自定义"
        case .advanced: return "高级功能和调试选项"
        case .about: return "应用信息和版本详情"
        }
    }
}

/// 设置项类型
enum SettingType {
    case toggle(Bool)
    case slider(value: Double, min: Double, max: Double, step: Double = 0.1)
    case picker(options: [String], selectedIndex: Int)
    case text(String)
    case button(title: String, action: () -> Void)
    case custom(content: AnyView)
}

/// 设置项模型
struct SettingItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let type: SettingType
    let category: SettingsCategory
    var isEnabled: Bool = true
    
    init(title: String, description: String? = nil, type: SettingType, category: SettingsCategory, isEnabled: Bool = true) {
        self.title = title
        self.description = description
        self.type = type
        self.category = category
        self.isEnabled = isEnabled
    }
}

/// 设置组模型
struct SettingGroup: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let items: [SettingItem]
    let category: SettingsCategory
    
    init(title: String, description: String? = nil, items: [SettingItem], category: SettingsCategory) {
        self.title = title
        self.description = description
        self.items = items
        self.category = category
    }
}

// MARK: - Hot Word Types

/// 热词分类
enum HotWordCategory: String, CaseIterable, Identifiable {
    case chinese = "中文热词"
    case english = "英文热词"
    case rules = "替换规则"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .chinese: return "textformat.abc"
        case .english: return "textformat.alt"
        case .rules: return "arrow.triangle.2.circlepath"
        case .custom: return "plus.circle"
        }
    }
    
    var fileName: String {
        switch self {
        case .chinese: return "hot-zh.txt"
        case .english: return "hot-en.txt" 
        case .rules: return "hot-rule.txt"
        case .custom: return "hot-custom.txt"
        }
    }
}

/// 热词条目
struct HotWordEntry: Identifiable, Codable {
    let id = UUID()
    var originalText: String
    var replacementText: String
    var isEnabled: Bool = true
    var priority: Int = 0
    var category: HotWordCategory
    var isCaseSensitive: Bool = false
    var isWholeWordMatch: Bool = true
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    
    /// 验证热词条目有效性
    func isValid() -> Bool {
        return !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               originalText != replacementText
    }
}

/// 热词排序方式
enum HotWordSortBy: String, CaseIterable {
    case alphabetical = "字母顺序"
    case priority = "优先级"
    case dateCreated = "创建时间"
    case dateModified = "修改时间"
    case usage = "使用频率"
    
    var displayName: String { rawValue }
}

/// 热词冲突信息
struct HotWordConflict: Identifiable {
    let id = UUID()
    let entry1: HotWordEntry
    let entry2: HotWordEntry
    let conflictType: ConflictType
    
    enum ConflictType {
        case duplicate  // 完全重复
        case overlap    // 部分重叠
        case circular   // 循环替换
    }
}

// MARK: - Shortcut Types

/// 快捷键动作
enum ShortcutAction: String, CaseIterable {
    case startRecording = "开始/停止录音"
    case pauseRecording = "暂停录音"
    case showHideWindow = "显示/隐藏窗口"
    case minimizeWindow = "最小化窗口"
    case toggleService = "启用/禁用服务"
    case openSettings = "打开设置"
    case clearTranscript = "清空转录"
    case exportTranscript = "导出转录"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .startRecording: return "开始或停止语音录制"
        case .pauseRecording: return "暂停当前录制"
        case .showHideWindow: return "显示或隐藏主窗口"
        case .minimizeWindow: return "最小化主窗口"
        case .toggleService: return "启用或禁用语音服务"
        case .openSettings: return "打开设置窗口"
        case .clearTranscript: return "清空当前转录内容"
        case .exportTranscript: return "导出转录内容到文件"
        }
    }
    
    var defaultShortcut: KeyboardShortcut? {
        switch self {
        case .startRecording: return KeyboardShortcut("o", modifiers: [.command, .shift])
        case .pauseRecording: return KeyboardShortcut("p", modifiers: [.command])
        case .showHideWindow: return KeyboardShortcut("h", modifiers: [.command, .option])
        case .minimizeWindow: return KeyboardShortcut("m", modifiers: [.command])
        case .toggleService: return KeyboardShortcut("t", modifiers: [.command, .shift])
        case .openSettings: return KeyboardShortcut(",", modifiers: [.command])
        case .clearTranscript: return KeyboardShortcut("k", modifiers: [.command])
        case .exportTranscript: return KeyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

/// 快捷键冲突信息
struct ShortcutConflict: Identifiable {
    let id = UUID()
    let action1: ShortcutAction
    let action2: ShortcutAction
    let shortcut: KeyboardShortcut
    let severity: ConflictSeverity
    
    enum ConflictSeverity {
        case warning  // 警告：可能冲突
        case error    // 错误：确定冲突
    }
}

// MARK: - Import/Export Types

/// 导出选项
struct ExportOptions {
    var includeGeneral: Bool = true
    var includeAudio: Bool = true  
    var includeRecognition: Bool = true
    var includeHotwords: Bool = true
    var includeShortcuts: Bool = true
    var includeAdvanced: Bool = false
    var includeDebug: Bool = false
    
    var exportFormat: ExportFormat = .json
    var compressionEnabled: Bool = false
    var encryptionEnabled: Bool = false
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case plist = "Property List"
        case xml = "XML"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .plist: return "plist"
            case .xml: return "xml"
            }
        }
    }
}

/// 导入结果
struct ImportResult {
    let success: Bool
    let importedCategories: [SettingsCategory]
    let skippedCategories: [SettingsCategory]
    let errors: [ImportError]
    let warnings: [ImportWarning]
    
    struct ImportError: Identifiable {
        let id = UUID()
        let category: SettingsCategory
        let message: String
        let details: String?
    }
    
    struct ImportWarning: Identifiable {
        let id = UUID()
        let category: SettingsCategory
        let message: String
        let suggestion: String?
    }
}

// MARK: - Supported Languages

enum SupportedLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
}

// MARK: - Audio Device

struct AudioDevice: Identifiable, Codable {
    let id: String
    let name: String
    let isDefault: Bool
    let channels: Int
    let sampleRate: Double
    
    init(id: String, name: String, isDefault: Bool = false, channels: Int = 1, sampleRate: Double = 16000) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.channels = channels
        self.sampleRate = sampleRate
    }
}

// MARK: - Extensions

extension KeyboardShortcut {
    /// 显示字符串表示
    var displayString: String {
        var components: [String] = []
        
        if modifiers.contains(.command) {
            components.append("⌘")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        
        // 添加按键
        components.append(key.character?.uppercased() ?? "?")
        
        return components.joined()
    }
}

extension KeyEquivalent {
    /// 获取字符表示
    var character: String? {
        switch self {
        case .space: return "Space"
        case .delete: return "⌫"
        case .deleteForward: return "⌦"
        case .return: return "↩"
        case .tab: return "⇥"
        case .escape: return "⎋"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        default: return "\(self)"
        }
    }
}