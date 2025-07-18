import SwiftUI

// MARK: - 音频波形可视化组件
struct AudioWaveform: View {
    let data: [Double]
    let style: AudioWaveformStyle
    let isAnimated: Bool
    let barCount: Int
    
    @State private var animatedData: [Double] = []
    @State private var animationTimer: Timer?
    
    init(
        data: [Double] = [],
        style: AudioWaveformStyle = .default,
        isAnimated: Bool = false,
        barCount: Int = 20
    ) {
        self.data = data
        self.style = style
        self.isAnimated = isAnimated
        self.barCount = barCount
        self._animatedData = State(initialValue: data.isEmpty ? Array(repeating: 0.1, count: barCount) : data)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: style.barSpacing) {
                ForEach(0..<effectiveBarCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: style.barCornerRadius)
                        .fill(colorForBar(at: index))
                        .frame(
                            width: barWidth(in: geometry),
                            height: heightForBar(at: index, in: geometry)
                        )
                        .animation(
                            isAnimated ? .easeInOut(duration: 0.1) : .none,
                            value: animatedData
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if isAnimated {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: data) { newData in
            updateAnimatedData(newData)
        }
    }
    
    private var effectiveBarCount: Int {
        return data.isEmpty ? barCount : data.count
    }
    
    private func barWidth(in geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = style.barSpacing * CGFloat(effectiveBarCount - 1)
        let availableWidth = geometry.size.width - totalSpacing
        return availableWidth / CGFloat(effectiveBarCount)
    }
    
    private func heightForBar(at index: Int, in geometry: GeometryProxy) -> CGFloat {
        let value = index < animatedData.count ? animatedData[index] : 0.1
        let minHeight = style.minBarHeight
        let maxHeight = geometry.size.height - minHeight
        return minHeight + (maxHeight * CGFloat(value))
    }
    
    private func colorForBar(at index: Int) -> Color {
        let value = index < animatedData.count ? animatedData[index] : 0.1
        
        switch style.colorMode {
        case .solid(let color):
            return color.opacity(0.7 + 0.3 * value)
        case .gradient(let colors):
            let colorIndex = Int(value * Double(colors.count - 1))
            return colors[min(colorIndex, colors.count - 1)]
        case .intensity:
            if value < 0.3 {
                return CWTheme.colors.success
            } else if value < 0.7 {
                return CWTheme.colors.warning
            } else {
                return CWTheme.colors.error
            }
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if data.isEmpty {
                // 生成随机波形数据
                let newData = (0..<barCount).map { _ in
                    Double.random(in: 0.1...1.0)
                }
                updateAnimatedData(newData)
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimatedData(_ newData: [Double]) {
        withAnimation(.easeInOut(duration: 0.1)) {
            animatedData = newData
        }
    }
}

// MARK: - 音频波形样式
struct AudioWaveformStyle {
    let barSpacing: CGFloat
    let barCornerRadius: CGFloat
    let minBarHeight: CGFloat
    let colorMode: WaveformColorMode
    
    static let `default` = AudioWaveformStyle(
        barSpacing: 2,
        barCornerRadius: 1,
        minBarHeight: 4,
        colorMode: .solid(CWTheme.colors.primary)
    )
    
    static let colorful = AudioWaveformStyle(
        barSpacing: 3,
        barCornerRadius: 2,
        minBarHeight: 6,
        colorMode: .gradient([.blue, .purple, .pink, .red])
    )
    
    static let intensity = AudioWaveformStyle(
        barSpacing: 1,
        barCornerRadius: 0.5,
        minBarHeight: 2,
        colorMode: .intensity
    )
}

// MARK: - 波形颜色模式
enum WaveformColorMode {
    case solid(Color)
    case gradient([Color])
    case intensity
}

// MARK: - 环形波形可视化组件
struct CircularWaveform: View {
    let data: [Double]
    let radius: CGFloat
    let lineWidth: CGFloat
    let isAnimated: Bool
    
    @State private var animatedData: [Double] = []
    @State private var rotationAngle: Double = 0
    
    init(
        data: [Double] = [],
        radius: CGFloat = 60,
        lineWidth: CGFloat = 3,
        isAnimated: Bool = false
    ) {
        self.data = data
        self.radius = radius
        self.lineWidth = lineWidth
        self.isAnimated = isAnimated
        self._animatedData = State(initialValue: data.isEmpty ? Array(repeating: 0.3, count: 60) : data)
    }
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)
            
            // 波形数据
            ForEach(0..<animatedData.count, id: \.self) { index in
                let angle = Double(index) * 360.0 / Double(animatedData.count)
                let value = animatedData[index]
                let length = radius * 0.3 * CGFloat(value)
                
                Rectangle()
                    .fill(colorForValue(value))
                    .frame(width: lineWidth, height: length)
                    .offset(y: -radius - length / 2)
                    .rotationEffect(.degrees(angle + rotationAngle))
            }
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(
            isAnimated ? .linear(duration: 2.0).repeatForever(autoreverses: false) : .none,
            value: rotationAngle
        )
        .onAppear {
            if isAnimated {
                rotationAngle = 360
                startDataAnimation()
            }
        }
        .onChange(of: data) { newData in
            updateAnimatedData(newData)
        }
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value < 0.3 {
            return CWTheme.colors.success
        } else if value < 0.7 {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.error
        }
    }
    
    private func startDataAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if data.isEmpty {
                let newData = (0..<60).map { _ in
                    Double.random(in: 0.1...1.0)
                }
                updateAnimatedData(newData)
            }
        }
    }
    
    private func updateAnimatedData(_ newData: [Double]) {
        withAnimation(.easeInOut(duration: 0.1)) {
            animatedData = newData
        }
    }
}

// MARK: - 频谱分析器组件
struct SpectrumAnalyzer: View {
    let data: [Double]
    let style: SpectrumAnalyzerStyle
    let isAnimated: Bool
    
    @State private var animatedData: [Double] = []
    @State private var animationTimer: Timer?
    
    init(
        data: [Double] = [],
        style: SpectrumAnalyzerStyle = .default,
        isAnimated: Bool = false
    ) {
        self.data = data
        self.style = style
        self.isAnimated = isAnimated
        self._animatedData = State(initialValue: data.isEmpty ? Array(repeating: 0.2, count: 32) : data)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: style.barSpacing) {
                ForEach(0..<effectiveBarCount, id: \.self) { index in
                    VStack(spacing: 0) {
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: style.barCornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors(for: index),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                width: barWidth(in: geometry),
                                height: heightForBar(at: index, in: geometry)
                            )
                            .animation(
                                isAnimated ? .easeInOut(duration: 0.08) : .none,
                                value: animatedData
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if isAnimated {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: data) { newData in
            updateAnimatedData(newData)
        }
    }
    
    private var effectiveBarCount: Int {
        return data.isEmpty ? 32 : data.count
    }
    
    private func barWidth(in geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = style.barSpacing * CGFloat(effectiveBarCount - 1)
        let availableWidth = geometry.size.width - totalSpacing
        return availableWidth / CGFloat(effectiveBarCount)
    }
    
    private func heightForBar(at index: Int, in geometry: GeometryProxy) -> CGFloat {
        let value = index < animatedData.count ? animatedData[index] : 0.1
        let minHeight = style.minBarHeight
        let maxHeight = geometry.size.height - minHeight
        return minHeight + (maxHeight * CGFloat(value))
    }
    
    private func gradientColors(for index: Int) -> [Color] {
        let value = index < animatedData.count ? animatedData[index] : 0.1
        let hue = Double(index) / Double(effectiveBarCount)
        
        switch style.colorScheme {
        case .rainbow:
            return [
                Color(hue: hue, saturation: 0.8, brightness: 0.6),
                Color(hue: hue, saturation: 1.0, brightness: 1.0)
            ]
        case .mono(let color):
            return [
                color.opacity(0.3),
                color.opacity(1.0)
            ]
        case .intensity:
            if value < 0.3 {
                return [CWTheme.colors.success.opacity(0.3), CWTheme.colors.success]
            } else if value < 0.7 {
                return [CWTheme.colors.warning.opacity(0.3), CWTheme.colors.warning]
            } else {
                return [CWTheme.colors.error.opacity(0.3), CWTheme.colors.error]
            }
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            if data.isEmpty {
                // 生成模拟频谱数据
                let newData = (0..<32).map { index in
                    let baseValue = Double.random(in: 0.1...0.8)
                    let frequency = Double(index) / 32.0
                    let adjustment = sin(frequency * .pi * 2) * 0.3
                    return max(0.1, min(1.0, baseValue + adjustment))
                }
                updateAnimatedData(newData)
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimatedData(_ newData: [Double]) {
        withAnimation(.easeInOut(duration: 0.08)) {
            animatedData = newData
        }
    }
}

// MARK: - 频谱分析器样式
struct SpectrumAnalyzerStyle {
    let barSpacing: CGFloat
    let barCornerRadius: CGFloat
    let minBarHeight: CGFloat
    let colorScheme: SpectrumColorScheme
    
    static let `default` = SpectrumAnalyzerStyle(
        barSpacing: 2,
        barCornerRadius: 1,
        minBarHeight: 4,
        colorScheme: .rainbow
    )
    
    static let mono = SpectrumAnalyzerStyle(
        barSpacing: 1,
        barCornerRadius: 0.5,
        minBarHeight: 2,
        colorScheme: .mono(CWTheme.colors.primary)
    )
    
    static let intensity = SpectrumAnalyzerStyle(
        barSpacing: 1.5,
        barCornerRadius: 2,
        minBarHeight: 6,
        colorScheme: .intensity
    )
}

// MARK: - 频谱颜色方案
enum SpectrumColorScheme {
    case rainbow
    case mono(Color)
    case intensity
}

// MARK: - 音量级别指示器
struct VolumeLevel: View {
    let level: Double
    let style: VolumeLevelStyle
    let isAnimated: Bool
    
    @State private var animatedLevel: Double = 0
    
    init(
        level: Double,
        style: VolumeLevelStyle = .default,
        isAnimated: Bool = true
    ) {
        self.level = max(0, min(1, level))
        self.style = style
        self.isAnimated = isAnimated
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
                    .frame(height: style.height)
                
                // 音量填充
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(volumeColor)
                    .frame(
                        width: geometry.size.width * CGFloat(animatedLevel),
                        height: style.height
                    )
                    .animation(
                        isAnimated ? .easeInOut(duration: 0.2) : .none,
                        value: animatedLevel
                    )
                
                // 峰值指示器
                if style.showPeakIndicator {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: style.height)
                        .offset(x: geometry.size.width * CGFloat(animatedLevel) - 1)
                        .opacity(animatedLevel > 0.1 ? 1 : 0)
                }
            }
        }
        .frame(height: style.height)
        .onAppear {
            updateLevel()
        }
        .onChange(of: level) { _ in
            updateLevel()
        }
    }
    
    private var volumeColor: Color {
        if animatedLevel < 0.3 {
            return CWTheme.colors.success
        } else if animatedLevel < 0.7 {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.error
        }
    }
    
    private func updateLevel() {
        withAnimation(isAnimated ? .easeInOut(duration: 0.2) : .none) {
            animatedLevel = level
        }
    }
}

// MARK: - 音量级别样式
struct VolumeLevelStyle {
    let height: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let showPeakIndicator: Bool
    
    static let `default` = VolumeLevelStyle(
        height: 8,
        cornerRadius: 4,
        backgroundColor: Color.gray.opacity(0.3),
        showPeakIndicator: true
    )
    
    static let thin = VolumeLevelStyle(
        height: 4,
        cornerRadius: 2,
        backgroundColor: Color.gray.opacity(0.2),
        showPeakIndicator: false
    )
    
    static let thick = VolumeLevelStyle(
        height: 16,
        cornerRadius: 8,
        backgroundColor: Color.gray.opacity(0.4),
        showPeakIndicator: true
    )
}

// MARK: - 预览
#Preview {
    VStack(spacing: 30) {
        // 音频波形
        AudioWaveform(
            style: .default,
            isAnimated: true
        )
        .frame(height: 60)
        
        // 频谱分析器
        SpectrumAnalyzer(
            style: .default,
            isAnimated: true
        )
        .frame(height: 100)
        
        // 环形波形
        CircularWaveform(
            isAnimated: true
        )
        .frame(height: 150)
        
        // 音量级别
        VolumeLevel(
            level: 0.7,
            style: .default
        )
        .frame(height: 20)
    }
    .padding()
    .background(CWTheme.colors.background)
}