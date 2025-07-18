import SwiftUI

// MARK: - CapsWriter 主题系统
struct CWTheme {
    static let colors = CWColors()
    static let fonts = CWFonts()
    static let spacing = CWSpacing()
    static let animations = CWAnimations()
    static let cornerRadius = CWCornerRadius()
    static let shadows = CWShadows()
}

// MARK: - 颜色系统
struct CWColors {
    // 主色调
    let primary = Color.accentColor
    let secondary = Color.secondary
    
    // 状态颜色
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
    let info = Color.blue
    
    // 录音状态颜色
    let recordingActive = Color.red
    let recordingInactive = Color.gray
    let processing = Color.orange
    let completed = Color.green
    
    // 背景颜色
    let background = Color(.windowBackgroundColor)
    let cardBackground = Color(.controlBackgroundColor)
    let textBackground = Color(.textBackgroundColor)
    
    // 边框颜色
    let border = Color(.separatorColor)
    let focusBorder = Color.accentColor
    
    // 文本颜色
    let primaryText = Color.primary
    let secondaryText = Color.secondary
    let tertiaryText = Color(.tertiaryLabelColor)
    
    // 音频可视化颜色
    let waveform = Color.blue.opacity(0.7)
    let spectrum = Color.purple.opacity(0.6)
    let volumeLevel = Color.green.opacity(0.8)
}

// MARK: - 字体系统
struct CWFonts {
    let largeTitle = Font.largeTitle
    let title = Font.title
    let title2 = Font.title2
    let headline = Font.headline
    let subheadline = Font.subheadline
    let body = Font.body
    let callout = Font.callout
    let caption = Font.caption
    let caption2 = Font.caption2
    let footnote = Font.footnote
    
    // 专用字体
    let monospacedDigits = Font.system(.body, design: .monospaced)
    let statusIndicator = Font.system(.caption, weight: .medium)
    let recordingTime = Font.system(.title2, design: .monospaced)
}

// MARK: - 间距系统
struct CWSpacing {
    let xxs: CGFloat = 2
    let xs: CGFloat = 4
    let s: CGFloat = 8
    let m: CGFloat = 12
    let l: CGFloat = 16
    let xl: CGFloat = 20
    let xxl: CGFloat = 24
    let xxxl: CGFloat = 32
    let xxxxl: CGFloat = 40
    
    // 特定用途间距
    let cardPadding: CGFloat = 16
    let sectionSpacing: CGFloat = 20
    let elementSpacing: CGFloat = 12
}

// MARK: - 动画系统
struct CWAnimations {
    let fast = Animation.easeInOut(duration: 0.2)
    let normal = Animation.easeInOut(duration: 0.3)
    let slow = Animation.easeInOut(duration: 0.5)
    
    // 录音动画
    let recordingPulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    let breathingEffect = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    let rotationEffect = Animation.linear(duration: 2.0).repeatForever(autoreverses: false)
    
    // 状态切换动画
    let stateTransition = Animation.spring(response: 0.6, dampingFraction: 0.8)
    let buttonPress = Animation.spring(response: 0.3, dampingFraction: 0.6)
    
    // 音频可视化动画
    let waveformAnimation = Animation.easeInOut(duration: 0.1).repeatForever(autoreverses: true)
    let spectrumAnimation = Animation.linear(duration: 0.05).repeatForever(autoreverses: true)
}

// MARK: - 圆角系统
struct CWCornerRadius {
    let xs: CGFloat = 4
    let s: CGFloat = 6
    let m: CGFloat = 8
    let l: CGFloat = 12
    let xl: CGFloat = 16
    let xxl: CGFloat = 20
    
    // 特定用途圆角
    let button: CGFloat = 8
    let card: CGFloat = 12
    let indicator: CGFloat = 6
}

// MARK: - 阴影系统
struct CWShadows {
    static let light = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let heavy = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    
    // 特定用途阴影
    static let card = Shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    static let button = Shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    static let indicator = Shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
}

// MARK: - 辅助结构
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 主题扩展
extension View {
    func cwShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func cwCard() -> some View {
        self
            .padding(CWTheme.spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CWTheme.cornerRadius.card)
                    .fill(CWTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CWTheme.cornerRadius.card)
                            .stroke(CWTheme.colors.border, lineWidth: 1)
                    )
            )
            .cwShadow(CWShadows.card)
    }
    
    func cwButton(style: CWButtonStyle = .primary) -> some View {
        self
            .padding(.horizontal, CWTheme.spacing.l)
            .padding(.vertical, CWTheme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: CWTheme.cornerRadius.button)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CWTheme.cornerRadius.button)
                            .stroke(style.borderColor, lineWidth: 1)
                    )
            )
            .foregroundColor(style.textColor)
            .cwShadow(CWShadows.button)
    }
}

// MARK: - 按钮样式枚举
enum CWButtonStyle {
    case primary
    case secondary
    case success
    case warning
    case error
    case ghost
    
    var backgroundColor: Color {
        switch self {
        case .primary: return CWTheme.colors.primary
        case .secondary: return CWTheme.colors.secondary.opacity(0.1)
        case .success: return CWTheme.colors.success
        case .warning: return CWTheme.colors.warning
        case .error: return CWTheme.colors.error
        case .ghost: return Color.clear
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary: return CWTheme.colors.primary
        case .secondary: return CWTheme.colors.secondary
        case .success: return CWTheme.colors.success
        case .warning: return CWTheme.colors.warning
        case .error: return CWTheme.colors.error
        case .ghost: return CWTheme.colors.border
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return CWTheme.colors.primaryText
        case .success: return .white
        case .warning: return .white
        case .error: return .white
        case .ghost: return CWTheme.colors.primaryText
        }
    }
}