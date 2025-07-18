import SwiftUI

// MARK: - CapsWriter 标签组件
struct CWLabel: View {
    let text: String
    let style: CWLabelStyle
    let icon: String?
    let iconPosition: CWLabelIconPosition
    
    init(
        _ text: String,
        style: CWLabelStyle = .default,
        icon: String? = nil,
        iconPosition: CWLabelIconPosition = .leading
    ) {
        self.text = text
        self.style = style
        self.icon = icon
        self.iconPosition = iconPosition
    }
    
    var body: some View {
        HStack(spacing: CWTheme.spacing.xs) {
            if iconPosition == .leading, let icon = icon {
                Image(systemName: icon)
                    .font(style.iconFont)
                    .foregroundColor(style.iconColor)
            }
            
            Text(text)
                .font(style.font)
                .foregroundColor(style.textColor)
                .fontWeight(style.fontWeight)
                .lineLimit(style.lineLimit)
            
            if iconPosition == .trailing, let icon = icon {
                Image(systemName: icon)
                    .font(style.iconFont)
                    .foregroundColor(style.iconColor)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        )
    }
}

// MARK: - 标签样式枚举
enum CWLabelStyle {
    case `default`
    case title
    case subtitle
    case caption
    case status
    case badge
    case tag
    case monospaced
    case error
    case warning
    case success
    case info
    
    var font: Font {
        switch self {
        case .default: return CWTheme.fonts.body
        case .title: return CWTheme.fonts.title2
        case .subtitle: return CWTheme.fonts.subheadline
        case .caption: return CWTheme.fonts.caption
        case .status: return CWTheme.fonts.statusIndicator
        case .badge: return CWTheme.fonts.caption2
        case .tag: return CWTheme.fonts.caption
        case .monospaced: return CWTheme.fonts.monospacedDigits
        case .error: return CWTheme.fonts.subheadline
        case .warning: return CWTheme.fonts.subheadline
        case .success: return CWTheme.fonts.subheadline
        case .info: return CWTheme.fonts.subheadline
        }
    }
    
    var iconFont: Font {
        switch self {
        case .default: return .system(size: 14)
        case .title: return .system(size: 18)
        case .subtitle: return .system(size: 14)
        case .caption: return .system(size: 10)
        case .status: return .system(size: 12)
        case .badge: return .system(size: 8)
        case .tag: return .system(size: 10)
        case .monospaced: return .system(size: 14, design: .monospaced)
        case .error: return .system(size: 14)
        case .warning: return .system(size: 14)
        case .success: return .system(size: 14)
        case .info: return .system(size: 14)
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .default: return .regular
        case .title: return .semibold
        case .subtitle: return .medium
        case .caption: return .regular
        case .status: return .medium
        case .badge: return .bold
        case .tag: return .medium
        case .monospaced: return .regular
        case .error: return .medium
        case .warning: return .medium
        case .success: return .medium
        case .info: return .medium
        }
    }
    
    var textColor: Color {
        switch self {
        case .default: return CWTheme.colors.primaryText
        case .title: return CWTheme.colors.primaryText
        case .subtitle: return CWTheme.colors.secondaryText
        case .caption: return CWTheme.colors.tertiaryText
        case .status: return CWTheme.colors.primaryText
        case .badge: return .white
        case .tag: return CWTheme.colors.primaryText
        case .monospaced: return CWTheme.colors.primaryText
        case .error: return CWTheme.colors.error
        case .warning: return CWTheme.colors.warning
        case .success: return CWTheme.colors.success
        case .info: return CWTheme.colors.info
        }
    }
    
    var iconColor: Color {
        switch self {
        case .default: return CWTheme.colors.secondaryText
        case .title: return CWTheme.colors.primary
        case .subtitle: return CWTheme.colors.secondaryText
        case .caption: return CWTheme.colors.tertiaryText
        case .status: return CWTheme.colors.primary
        case .badge: return .white
        case .tag: return CWTheme.colors.primary
        case .monospaced: return CWTheme.colors.secondaryText
        case .error: return CWTheme.colors.error
        case .warning: return CWTheme.colors.warning
        case .success: return CWTheme.colors.success
        case .info: return CWTheme.colors.info
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .default: return Color.clear
        case .title: return Color.clear
        case .subtitle: return Color.clear
        case .caption: return Color.clear
        case .status: return Color.clear
        case .badge: return CWTheme.colors.primary
        case .tag: return CWTheme.colors.primary.opacity(0.1)
        case .monospaced: return Color.clear
        case .error: return CWTheme.colors.error.opacity(0.1)
        case .warning: return CWTheme.colors.warning.opacity(0.1)
        case .success: return CWTheme.colors.success.opacity(0.1)
        case .info: return CWTheme.colors.info.opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return Color.clear
        case .title: return Color.clear
        case .subtitle: return Color.clear
        case .caption: return Color.clear
        case .status: return Color.clear
        case .badge: return Color.clear
        case .tag: return CWTheme.colors.primary.opacity(0.3)
        case .monospaced: return Color.clear
        case .error: return CWTheme.colors.error.opacity(0.3)
        case .warning: return CWTheme.colors.warning.opacity(0.3)
        case .success: return CWTheme.colors.success.opacity(0.3)
        case .info: return CWTheme.colors.info.opacity(0.3)
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .badge: return 0
        case .tag: return 1
        case .error, .warning, .success, .info: return 1
        default: return 0
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .badge: return CWTheme.spacing.s
        case .tag: return CWTheme.spacing.s
        case .error, .warning, .success, .info: return CWTheme.spacing.s
        default: return 0
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .badge: return CWTheme.spacing.xs
        case .tag: return CWTheme.spacing.xs
        case .error, .warning, .success, .info: return CWTheme.spacing.xs
        default: return 0
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .badge: return CWTheme.cornerRadius.xl
        case .tag: return CWTheme.cornerRadius.s
        case .error, .warning, .success, .info: return CWTheme.cornerRadius.s
        default: return 0
        }
    }
    
    var lineLimit: Int? {
        switch self {
        case .badge: return 1
        case .tag: return 1
        case .caption: return 2
        default: return nil
        }
    }
}

// MARK: - 图标位置枚举
enum CWLabelIconPosition {
    case leading
    case trailing
}

// MARK: - 状态标签组件
struct CWStatusLabel: View {
    let status: CWStatusType
    let text: String?
    
    init(status: CWStatusType, text: String? = nil) {
        self.status = status
        self.text = text ?? status.displayText
    }
    
    var body: some View {
        CWLabel(
            text,
            style: status.labelStyle,
            icon: status.icon,
            iconPosition: .leading
        )
    }
}

// MARK: - 扩展状态类型
extension CWStatusType {
    var displayText: String {
        switch self {
        case .ready: return "就绪"
        case .running: return "运行中"
        case .error: return "错误"
        case .warning: return "警告"
        case .disabled: return "已禁用"
        }
    }
    
    var labelStyle: CWLabelStyle {
        switch self {
        case .ready: return .success
        case .running: return .info
        case .error: return .error
        case .warning: return .warning
        case .disabled: return .default
        }
    }
}

// MARK: - 数值标签组件
struct CWValueLabel: View {
    let title: String
    let value: String
    let unit: String?
    let style: CWValueLabelStyle
    
    init(
        title: String,
        value: String,
        unit: String? = nil,
        style: CWValueLabelStyle = .default
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.style = style
    }
    
    var body: some View {
        VStack(alignment: style.alignment, spacing: CWTheme.spacing.xs) {
            CWLabel(title, style: .subtitle)
            
            HStack(spacing: CWTheme.spacing.xs) {
                CWLabel(value, style: .monospaced)
                
                if let unit = unit {
                    CWLabel(unit, style: .caption)
                }
            }
        }
        .padding(style.padding)
        .background(
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.m)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: CWTheme.cornerRadius.m)
                        .stroke(style.borderColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - 数值标签样式
enum CWValueLabelStyle {
    case `default`
    case compact
    case prominent
    
    var alignment: HorizontalAlignment {
        switch self {
        case .default: return .leading
        case .compact: return .center
        case .prominent: return .center
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .default: return CWTheme.spacing.s
        case .compact: return CWTheme.spacing.xs
        case .prominent: return CWTheme.spacing.m
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.cardBackground
        case .compact: return Color.clear
        case .prominent: return CWTheme.colors.primary.opacity(0.05)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return CWTheme.colors.border
        case .compact: return Color.clear
        case .prominent: return CWTheme.colors.primary.opacity(0.2)
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        // 基础标签
        VStack(alignment: .leading, spacing: 8) {
            CWLabel("默认标签", style: .default)
            CWLabel("标题标签", style: .title, icon: "star.fill")
            CWLabel("副标题标签", style: .subtitle, icon: "info.circle")
            CWLabel("说明文字", style: .caption)
        }
        
        // 状态标签
        HStack(spacing: 12) {
            CWStatusLabel(status: .ready)
            CWStatusLabel(status: .running)
            CWStatusLabel(status: .error)
            CWStatusLabel(status: .warning)
        }
        
        // 徽章和标签
        HStack(spacing: 8) {
            CWLabel("NEW", style: .badge)
            CWLabel("热门", style: .tag)
            CWLabel("重要", style: .error)
            CWLabel("提示", style: .info)
        }
        
        // 数值标签
        HStack(spacing: 16) {
            CWValueLabel(title: "录音时长", value: "02:35", unit: "分钟")
            CWValueLabel(title: "准确率", value: "96.5", unit: "%", style: .compact)
            CWValueLabel(title: "文件大小", value: "2.1", unit: "MB", style: .prominent)
        }
    }
    .padding()
    .background(CWTheme.colors.background)
}