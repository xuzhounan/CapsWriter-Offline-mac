import SwiftUI

// MARK: - CapsWriter 进度条组件
struct CWProgressBar: View {
    let progress: Double
    let style: CWProgressBarStyle
    let showPercentage: Bool
    let animationDuration: Double
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        style: CWProgressBarStyle = .default,
        showPercentage: Bool = false,
        animationDuration: Double = 0.5
    ) {
        self.progress = max(0, min(1, progress))
        self.style = style
        self.showPercentage = showPercentage
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
            // 进度条主体
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(style.backgroundColor)
                        .frame(height: style.height)
                    
                    // 进度填充
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(style.progressColor)
                        .frame(
                            width: geometry.size.width * animatedProgress,
                            height: style.height
                        )
                        .animation(.easeInOut(duration: animationDuration), value: animatedProgress)
                    
                    // 进度条纹理（可选）
                    if style.showStripes {
                        stripesOverlay
                            .frame(
                                width: geometry.size.width * animatedProgress,
                                height: style.height
                            )
                            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
            }
            .frame(height: style.height)
            
            // 百分比显示
            if showPercentage {
                HStack {
                    Text("\(Int(animatedProgress * 100))%")
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(style.textColor)
                    
                    Spacer()
                    
                    if style.showTime {
                        Text(estimatedTimeRemaining)
                            .font(CWTheme.fonts.caption)
                            .foregroundColor(CWTheme.colors.secondaryText)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: animationDuration)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeInOut(duration: animationDuration)) {
                animatedProgress = newValue
            }
        }
    }
    
    // MARK: - 条纹纹理
    private var stripesOverlay: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.width / 8), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 4)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 4)
                }
            }
            .rotationEffect(.degrees(45))
            .clipped()
        }
    }
    
    // MARK: - 估计剩余时间
    private var estimatedTimeRemaining: String {
        guard progress > 0 && progress < 1 else { return "--:--" }
        
        let remainingProgress = 1 - progress
        let estimatedSeconds = Int(remainingProgress * 60) // 简化计算
        let minutes = estimatedSeconds / 60
        let seconds = estimatedSeconds % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 进度条样式枚举
enum CWProgressBarStyle {
    case `default`
    case thin
    case thick
    case colorful
    case striped
    
    var height: CGFloat {
        switch self {
        case .default: return 8
        case .thin: return 4
        case .thick: return 12
        case .colorful: return 10
        case .striped: return 16
        }
    }
    
    var cornerRadius: CGFloat {
        return height / 2
    }
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.border.opacity(0.3)
        case .thin: return CWTheme.colors.border.opacity(0.2)
        case .thick: return CWTheme.colors.border.opacity(0.4)
        case .colorful: return Color.gray.opacity(0.2)
        case .striped: return CWTheme.colors.border.opacity(0.3)
        }
    }
    
    var progressColor: Color {
        switch self {
        case .default: return CWTheme.colors.primary
        case .thin: return CWTheme.colors.primary
        case .thick: return CWTheme.colors.primary
        case .colorful: return Color.rainbow
        case .striped: return CWTheme.colors.success
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return Color.clear
        case .thin: return Color.clear
        case .thick: return CWTheme.colors.border
        case .colorful: return Color.clear
        case .striped: return CWTheme.colors.border
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .default: return 0
        case .thin: return 0
        case .thick: return 1
        case .colorful: return 0
        case .striped: return 1
        }
    }
    
    var textColor: Color {
        return CWTheme.colors.primaryText
    }
    
    var showStripes: Bool {
        return self == .striped
    }
    
    var showTime: Bool {
        return self == .thick || self == .striped
    }
}

// MARK: - 圆形进度条组件
struct CWCircularProgressBar: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let style: CWCircularProgressStyle
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        size: CGFloat = 60,
        lineWidth: CGFloat = 6,
        style: CWCircularProgressStyle = .default
    ) {
        self.progress = max(0, min(1, progress))
        self.size = size
        self.lineWidth = lineWidth
        self.style = style
    }
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(style.backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    style.progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: animatedProgress)
            
            // 中心文字
            if style.showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.2, weight: .medium, design: .monospaced))
                    .foregroundColor(style.textColor)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - 圆形进度条样式
enum CWCircularProgressStyle {
    case `default`
    case colorful
    case minimal
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.border.opacity(0.3)
        case .colorful: return Color.gray.opacity(0.2)
        case .minimal: return Color.clear
        }
    }
    
    var progressColor: Color {
        switch self {
        case .default: return CWTheme.colors.primary
        case .colorful: return Color.rainbow
        case .minimal: return CWTheme.colors.primary
        }
    }
    
    var textColor: Color {
        return CWTheme.colors.primaryText
    }
    
    var showPercentage: Bool {
        return self != .minimal
    }
}

// MARK: - 彩虹色扩展
extension Color {
    static let rainbow = LinearGradient(
        gradient: Gradient(colors: [
            .red, .orange, .yellow, .green, .blue, .purple
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - 预览
#Preview {
    VStack(spacing: 30) {
        VStack(spacing: 20) {
            CWProgressBar(progress: 0.3, style: .default, showPercentage: true)
            CWProgressBar(progress: 0.6, style: .thick, showPercentage: true)
            CWProgressBar(progress: 0.8, style: .colorful, showPercentage: true)
            CWProgressBar(progress: 0.45, style: .striped, showPercentage: true)
        }
        
        HStack(spacing: 20) {
            CWCircularProgressBar(progress: 0.3, size: 80, style: .default)
            CWCircularProgressBar(progress: 0.6, size: 80, style: .colorful)
            CWCircularProgressBar(progress: 0.8, size: 80, style: .minimal)
        }
    }
    .padding()
    .background(CWTheme.colors.background)
}