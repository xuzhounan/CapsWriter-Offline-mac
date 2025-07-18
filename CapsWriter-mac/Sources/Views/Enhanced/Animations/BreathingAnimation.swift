import SwiftUI

// MARK: - 呼吸动画组件
struct BreathingAnimation: View {
    let content: AnyView
    let duration: Double
    let minScale: CGFloat
    let maxScale: CGFloat
    let isEnabled: Bool
    
    @State private var isAnimating = false
    
    init<Content: View>(
        duration: Double = 2.0,
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.duration = duration
        self.minScale = minScale
        self.maxScale = maxScale
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        content
            .scaleEffect(isAnimating ? maxScale : minScale)
            .animation(
                isEnabled ? 
                Animation.easeInOut(duration: duration).repeatForever(autoreverses: true) : .none,
                value: isAnimating
            )
            .onAppear {
                if isEnabled {
                    isAnimating = true
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    isAnimating = true
                } else {
                    isAnimating = false
                }
            }
    }
}

// MARK: - 脉冲动画组件
struct PulseAnimation: View {
    let content: AnyView
    let duration: Double
    let pulseScale: CGFloat
    let pulseOpacity: Double
    let isEnabled: Bool
    
    @State private var isPulsing = false
    
    init<Content: View>(
        duration: Double = 1.0,
        pulseScale: CGFloat = 1.2,
        pulseOpacity: Double = 0.6,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.duration = duration
        self.pulseScale = pulseScale
        self.pulseOpacity = pulseOpacity
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        ZStack {
            // 脉冲光环
            if isEnabled {
                content
                    .scaleEffect(isPulsing ? pulseScale : 1.0)
                    .opacity(isPulsing ? pulseOpacity : 1.0)
                    .animation(
                        Animation.easeInOut(duration: duration).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .blur(radius: isPulsing ? 2 : 0)
            }
            
            // 主内容
            content
        }
        .onAppear {
            if isEnabled {
                isPulsing = true
            }
        }
        .onChange(of: isEnabled) { enabled in
            isPulsing = enabled
        }
    }
}

// MARK: - 波纹动画组件
struct RippleAnimation: View {
    let content: AnyView
    let rippleColor: Color
    let rippleCount: Int
    let duration: Double
    let isEnabled: Bool
    
    @State private var rippleScales: [CGFloat] = []
    @State private var rippleOpacities: [Double] = []
    
    init<Content: View>(
        rippleColor: Color = .blue,
        rippleCount: Int = 3,
        duration: Double = 2.0,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.rippleColor = rippleColor
        self.rippleCount = rippleCount
        self.duration = duration
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        ZStack {
            // 波纹圆环
            if isEnabled {
                ForEach(0..<rippleCount, id: \.self) { index in
                    Circle()
                        .stroke(
                            rippleColor.opacity(
                                index < rippleOpacities.count ? rippleOpacities[index] : 0
                            ),
                            lineWidth: 2
                        )
                        .scaleEffect(
                            index < rippleScales.count ? rippleScales[index] : 1.0
                        )
                        .animation(
                            Animation.easeOut(duration: duration)
                                .delay(Double(index) * duration / Double(rippleCount))
                                .repeatForever(autoreverses: false),
                            value: rippleScales
                        )
                }
            }
            
            // 主内容
            content
        }
        .onAppear {
            if isEnabled {
                startRippleAnimation()
            }
        }
        .onChange(of: isEnabled) { enabled in
            if enabled {
                startRippleAnimation()
            } else {
                stopRippleAnimation()
            }
        }
    }
    
    private func startRippleAnimation() {
        rippleScales = Array(repeating: 0.1, count: rippleCount)
        rippleOpacities = Array(repeating: 1.0, count: rippleCount)
        
        withAnimation {
            rippleScales = Array(repeating: 2.0, count: rippleCount)
            rippleOpacities = Array(repeating: 0.0, count: rippleCount)
        }
    }
    
    private func stopRippleAnimation() {
        rippleScales = []
        rippleOpacities = []
    }
}

// MARK: - 浮动动画组件
struct FloatingAnimation: View {
    let content: AnyView
    let amplitude: CGFloat
    let frequency: Double
    let isEnabled: Bool
    
    @State private var offset: CGFloat = 0
    
    init<Content: View>(
        amplitude: CGFloat = 10.0,
        frequency: Double = 2.0,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.amplitude = amplitude
        self.frequency = frequency
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        content
            .offset(y: isEnabled ? offset : 0)
            .animation(
                isEnabled ? 
                Animation.easeInOut(duration: frequency).repeatForever(autoreverses: true) : .none,
                value: offset
            )
            .onAppear {
                if isEnabled {
                    offset = amplitude
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    offset = amplitude
                } else {
                    offset = 0
                }
            }
    }
}

// MARK: - 抖动动画组件
struct ShakeAnimation: View {
    let content: AnyView
    let intensity: CGFloat
    let duration: Double
    let isEnabled: Bool
    
    @State private var shakeOffset: CGFloat = 0
    
    init<Content: View>(
        intensity: CGFloat = 5.0,
        duration: Double = 0.1,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.intensity = intensity
        self.duration = duration
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        content
            .offset(x: isEnabled ? shakeOffset : 0)
            .animation(
                isEnabled ? 
                Animation.easeInOut(duration: duration).repeatForever(autoreverses: true) : .none,
                value: shakeOffset
            )
            .onAppear {
                if isEnabled {
                    startShaking()
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    startShaking()
                } else {
                    shakeOffset = 0
                }
            }
    }
    
    private func startShaking() {
        let shakeValues: [CGFloat] = [0, intensity, -intensity, intensity, 0]
        
        for (index, value) in shakeValues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * duration) {
                withAnimation(.easeInOut(duration: duration)) {
                    shakeOffset = value
                }
            }
        }
        
        // 重复抖动
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(shakeValues.count)) {
            if isEnabled {
                startShaking()
            }
        }
    }
}

// MARK: - 旋转动画组件
struct RotationAnimation: View {
    let content: AnyView
    let duration: Double
    let direction: RotationDirection
    let isEnabled: Bool
    
    @State private var rotationAngle: Double = 0
    
    init<Content: View>(
        duration: Double = 2.0,
        direction: RotationDirection = .clockwise,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.duration = duration
        self.direction = direction
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        content
            .rotationEffect(.degrees(isEnabled ? rotationAngle : 0))
            .animation(
                isEnabled ? 
                Animation.linear(duration: duration).repeatForever(autoreverses: false) : .none,
                value: rotationAngle
            )
            .onAppear {
                if isEnabled {
                    rotationAngle = direction == .clockwise ? 360 : -360
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    rotationAngle = direction == .clockwise ? 360 : -360
                } else {
                    rotationAngle = 0
                }
            }
    }
}

// MARK: - 旋转方向枚举
enum RotationDirection {
    case clockwise
    case counterclockwise
}

// MARK: - 组合动画组件
struct CombinedAnimation: View {
    let content: AnyView
    let animations: [AnimationType]
    let isEnabled: Bool
    
    init<Content: View>(
        animations: [AnimationType],
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = AnyView(content())
        self.animations = animations
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        animations.reduce(content) { currentContent, animation in
            switch animation {
            case .breathing(let duration, let minScale, let maxScale):
                return AnyView(
                    BreathingAnimation(
                        duration: duration,
                        minScale: minScale,
                        maxScale: maxScale,
                        isEnabled: isEnabled
                    ) {
                        currentContent
                    }
                )
            case .pulse(let duration, let scale, let opacity):
                return AnyView(
                    PulseAnimation(
                        duration: duration,
                        pulseScale: scale,
                        pulseOpacity: opacity,
                        isEnabled: isEnabled
                    ) {
                        currentContent
                    }
                )
            case .floating(let amplitude, let frequency):
                return AnyView(
                    FloatingAnimation(
                        amplitude: amplitude,
                        frequency: frequency,
                        isEnabled: isEnabled
                    ) {
                        currentContent
                    }
                )
            case .rotation(let duration, let direction):
                return AnyView(
                    RotationAnimation(
                        duration: duration,
                        direction: direction,
                        isEnabled: isEnabled
                    ) {
                        currentContent
                    }
                )
            }
        }
    }
}

// MARK: - 动画类型枚举
enum AnimationType {
    case breathing(duration: Double, minScale: CGFloat, maxScale: CGFloat)
    case pulse(duration: Double, scale: CGFloat, opacity: Double)
    case floating(amplitude: CGFloat, frequency: Double)
    case rotation(duration: Double, direction: RotationDirection)
}

// MARK: - 便捷扩展
extension View {
    func breathing(
        duration: Double = 2.0,
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        isEnabled: Bool = true
    ) -> some View {
        BreathingAnimation(
            duration: duration,
            minScale: minScale,
            maxScale: maxScale,
            isEnabled: isEnabled
        ) {
            self
        }
    }
    
    func pulse(
        duration: Double = 1.0,
        scale: CGFloat = 1.2,
        opacity: Double = 0.6,
        isEnabled: Bool = true
    ) -> some View {
        PulseAnimation(
            duration: duration,
            pulseScale: scale,
            pulseOpacity: opacity,
            isEnabled: isEnabled
        ) {
            self
        }
    }
    
    func ripple(
        color: Color = .blue,
        count: Int = 3,
        duration: Double = 2.0,
        isEnabled: Bool = true
    ) -> some View {
        RippleAnimation(
            rippleColor: color,
            rippleCount: count,
            duration: duration,
            isEnabled: isEnabled
        ) {
            self
        }
    }
    
    func floating(
        amplitude: CGFloat = 10.0,
        frequency: Double = 2.0,
        isEnabled: Bool = true
    ) -> some View {
        FloatingAnimation(
            amplitude: amplitude,
            frequency: frequency,
            isEnabled: isEnabled
        ) {
            self
        }
    }
    
    func shake(
        intensity: CGFloat = 5.0,
        duration: Double = 0.1,
        isEnabled: Bool = true
    ) -> some View {
        ShakeAnimation(
            intensity: intensity,
            duration: duration,
            isEnabled: isEnabled
        ) {
            self
        }
    }
    
    func rotate(
        duration: Double = 2.0,
        direction: RotationDirection = .clockwise,
        isEnabled: Bool = true
    ) -> some View {
        RotationAnimation(
            duration: duration,
            direction: direction,
            isEnabled: isEnabled
        ) {
            self
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .breathing()
            
            Circle()
                .fill(Color.red)
                .frame(width: 50, height: 50)
                .pulse()
            
            Circle()
                .fill(Color.green)
                .frame(width: 50, height: 50)
                .floating()
        }
        
        HStack(spacing: 20) {
            Circle()
                .fill(Color.orange)
                .frame(width: 50, height: 50)
                .rotate()
            
            Circle()
                .fill(Color.purple)
                .frame(width: 50, height: 50)
                .ripple(color: .purple)
            
            Circle()
                .fill(Color.pink)
                .frame(width: 50, height: 50)
                .shake()
        }
        
        // 组合动画示例
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .cornerRadius(20)
            .breathing()
            .floating(amplitude: 15, frequency: 1.5)
    }
    .padding()
    .background(CWTheme.colors.background)
}