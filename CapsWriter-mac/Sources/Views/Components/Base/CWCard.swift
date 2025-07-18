import SwiftUI

// MARK: - CapsWriter 卡片组件
struct CWCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerIcon: String?
    let style: CWCardStyle
    let content: Content
    
    @State private var isHovered = false
    
    // MARK: - 初始化方法
    init(
        title: String? = nil,
        subtitle: String? = nil,
        headerIcon: String? = nil,
        style: CWCardStyle = .default,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerIcon = headerIcon
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            if hasHeader {
                headerView
                    .padding(.horizontal, CWTheme.spacing.cardPadding)
                    .padding(.top, CWTheme.spacing.cardPadding)
                    .padding(.bottom, CWTheme.spacing.m)
            }
            
            // 卡片内容
            content
                .padding(.horizontal, CWTheme.spacing.cardPadding)
                .padding(.bottom, CWTheme.spacing.cardPadding)
                .padding(.top, hasHeader ? 0 : CWTheme.spacing.cardPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.card)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: CWTheme.cornerRadius.card)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        )
        .overlay(
            // 悬停效果
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.card)
                .stroke(style.hoverBorderColor, lineWidth: isHovered ? 2 : 0)
                .opacity(isHovered ? 1 : 0)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(CWTheme.animations.normal, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .cwShadow(style.shadow)
    }
    
    // MARK: - 头部视图
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: CWTheme.spacing.m) {
            // 头部图标
            if let headerIcon = headerIcon {
                Image(systemName: headerIcon)
                    .font(.title2)
                    .foregroundColor(style.iconColor)
            }
            
            // 标题和副标题
            VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                if let title = title {
                    Text(title)
                        .font(CWTheme.fonts.headline)
                        .foregroundColor(style.titleColor)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(style.subtitleColor)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - 计算属性
    private var hasHeader: Bool {
        title != nil || subtitle != nil || headerIcon != nil
    }
}

// MARK: - 卡片样式枚举
enum CWCardStyle {
    case `default`
    case highlighted
    case success
    case warning
    case error
    case transparent
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.cardBackground
        case .highlighted: return CWTheme.colors.primary.opacity(0.05)
        case .success: return CWTheme.colors.success.opacity(0.05)
        case .warning: return CWTheme.colors.warning.opacity(0.05)
        case .error: return CWTheme.colors.error.opacity(0.05)
        case .transparent: return Color.clear
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return CWTheme.colors.border
        case .highlighted: return CWTheme.colors.primary.opacity(0.3)
        case .success: return CWTheme.colors.success.opacity(0.3)
        case .warning: return CWTheme.colors.warning.opacity(0.3)
        case .error: return CWTheme.colors.error.opacity(0.3)
        case .transparent: return Color.clear
        }
    }
    
    var hoverBorderColor: Color {
        switch self {
        case .default: return CWTheme.colors.primary.opacity(0.5)
        case .highlighted: return CWTheme.colors.primary
        case .success: return CWTheme.colors.success
        case .warning: return CWTheme.colors.warning
        case .error: return CWTheme.colors.error
        case .transparent: return CWTheme.colors.border
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .default: return 1
        case .highlighted: return 1.5
        case .success: return 1.5
        case .warning: return 1.5
        case .error: return 1.5
        case .transparent: return 0
        }
    }
    
    var titleColor: Color {
        switch self {
        case .default: return CWTheme.colors.primaryText
        case .highlighted: return CWTheme.colors.primary
        case .success: return CWTheme.colors.success
        case .warning: return CWTheme.colors.warning
        case .error: return CWTheme.colors.error
        case .transparent: return CWTheme.colors.primaryText
        }
    }
    
    var subtitleColor: Color {
        return CWTheme.colors.secondaryText
    }
    
    var iconColor: Color {
        switch self {
        case .default: return CWTheme.colors.primary
        case .highlighted: return CWTheme.colors.primary
        case .success: return CWTheme.colors.success
        case .warning: return CWTheme.colors.warning
        case .error: return CWTheme.colors.error
        case .transparent: return CWTheme.colors.primary
        }
    }
    
    var shadow: Shadow {
        switch self {
        case .default: return CWShadows.card
        case .highlighted: return CWShadows.medium
        case .success: return CWShadows.card
        case .warning: return CWShadows.card
        case .error: return CWShadows.card
        case .transparent: return Shadow(color: .clear, radius: 0, x: 0, y: 0)
        }
    }
}

// MARK: - 特殊卡片组件
struct CWStatusCard: View {
    let title: String
    let status: CWStatusType
    let description: String?
    let action: (() -> Void)?
    
    var body: some View {
        CWCard(
            title: title,
            subtitle: description,
            headerIcon: status.icon,
            style: status.cardStyle
        ) {
            if let action = action {
                HStack {
                    Spacer()
                    CWButton(
                        status.actionTitle,
                        style: status.buttonStyle,
                        size: .small
                    ) {
                        action()
                    }
                }
            }
        }
    }
}

// MARK: - 状态类型枚举
enum CWStatusType {
    case ready
    case running
    case error
    case warning
    case disabled
    
    var icon: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .running: return "gear"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .disabled: return "pause.circle.fill"
        }
    }
    
    var cardStyle: CWCardStyle {
        switch self {
        case .ready: return .success
        case .running: return .highlighted
        case .error: return .error
        case .warning: return .warning
        case .disabled: return .default
        }
    }
    
    var buttonStyle: CWButtonStyle {
        switch self {
        case .ready: return .success
        case .running: return .warning
        case .error: return .error
        case .warning: return .warning
        case .disabled: return .secondary
        }
    }
    
    var actionTitle: String {
        switch self {
        case .ready: return "就绪"
        case .running: return "运行中"
        case .error: return "重试"
        case .warning: return "检查"
        case .disabled: return "启用"
        }
    }
}

// MARK: - 预览
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CWCard(
                title: "基础卡片",
                subtitle: "这是一个基础卡片示例",
                headerIcon: "doc.text"
            ) {
                Text("这是卡片的内容区域")
                    .foregroundColor(CWTheme.colors.secondaryText)
            }
            
            CWCard(
                title: "高亮卡片",
                headerIcon: "star.fill",
                style: .highlighted
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("重要信息")
                        .font(CWTheme.fonts.headline)
                    Text("这是一个高亮显示的卡片")
                        .font(CWTheme.fonts.body)
                        .foregroundColor(CWTheme.colors.secondaryText)
                }
            }
            
            CWStatusCard(
                title: "语音识别服务",
                status: .ready,
                description: "服务运行正常",
                action: {
                    print("状态卡片按钮点击")
                }
            )
        }
        .padding()
    }
    .background(CWTheme.colors.background)
}