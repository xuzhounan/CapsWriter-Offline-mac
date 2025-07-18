import SwiftUI

// MARK: - CapsWriter 按钮组件
struct CWButton: View {
    let title: String
    let icon: String?
    let style: CWButtonStyle
    let size: CWButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - 初始化方法
    init(
        _ title: String,
        icon: String? = nil,
        style: CWButtonStyle = .primary,
        size: CWButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled && !isLoading {
                action()
            }
        }) {
            HStack(spacing: CWTheme.spacing.s) {
                // 图标或加载指示器
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.textColor))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                
                // 标题文本
                if !title.isEmpty {
                    Text(title)
                        .font(size.textFont)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(effectiveTextColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minWidth: size.minWidth)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: CWTheme.cornerRadius.button)
                    .fill(effectiveBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CWTheme.cornerRadius.button)
                            .stroke(effectiveBorderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(CWTheme.animations.buttonPress, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .disabled(isDisabled || isLoading)
    }
    
    // MARK: - 计算属性
    private var effectiveBackgroundColor: Color {
        if isDisabled {
            return style.backgroundColor.opacity(0.3)
        } else if isHovered {
            return style.backgroundColor.opacity(0.8)
        } else {
            return style.backgroundColor
        }
    }
    
    private var effectiveBorderColor: Color {
        if isDisabled {
            return style.borderColor.opacity(0.3)
        } else if isHovered {
            return style.borderColor.opacity(0.8)
        } else {
            return style.borderColor
        }
    }
    
    private var effectiveTextColor: Color {
        if isDisabled {
            return style.textColor.opacity(0.5)
        } else {
            return style.textColor
        }
    }
}

// MARK: - 按钮尺寸枚举
enum CWButtonSize {
    case small
    case medium
    case large
    
    var textFont: Font {
        switch self {
        case .small: return CWTheme.fonts.caption
        case .medium: return CWTheme.fonts.body
        case .large: return CWTheme.fonts.headline
        }
    }
    
    var iconFont: Font {
        switch self {
        case .small: return .system(size: 12)
        case .medium: return .system(size: 16)
        case .large: return .system(size: 20)
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return CWTheme.spacing.s
        case .medium: return CWTheme.spacing.l
        case .large: return CWTheme.spacing.xl
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return CWTheme.spacing.xs
        case .medium: return CWTheme.spacing.s
        case .large: return CWTheme.spacing.m
        }
    }
    
    var height: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 36
        case .large: return 44
        }
    }
    
    var minWidth: CGFloat {
        switch self {
        case .small: return 60
        case .medium: return 80
        case .large: return 100
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            CWButton("主要按钮", style: .primary) {}
            CWButton("次要按钮", style: .secondary) {}
            CWButton("成功按钮", style: .success) {}
        }
        
        HStack(spacing: 12) {
            CWButton("警告按钮", style: .warning) {}
            CWButton("错误按钮", style: .error) {}
            CWButton("幽灵按钮", style: .ghost) {}
        }
        
        HStack(spacing: 12) {
            CWButton("小按钮", size: .small) {}
            CWButton("中按钮", size: .medium) {}
            CWButton("大按钮", size: .large) {}
        }
        
        HStack(spacing: 12) {
            CWButton("带图标", icon: "mic.fill") {}
            CWButton("加载中", isLoading: true) {}
            CWButton("禁用", isDisabled: true) {}
        }
    }
    .padding()
    .background(CWTheme.colors.background)
}