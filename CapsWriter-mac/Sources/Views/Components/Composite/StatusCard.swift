import SwiftUI

// MARK: - 状态卡片组件
struct StatusCard: View {
    let title: String
    let services: [ServiceStatus]
    let style: StatusCardStyle
    let onRefresh: (() -> Void)?
    let onServiceAction: ((ServiceStatus) -> Void)?
    
    init(
        title: String,
        services: [ServiceStatus],
        style: StatusCardStyle = .default,
        onRefresh: (() -> Void)? = nil,
        onServiceAction: ((ServiceStatus) -> Void)? = nil
    ) {
        self.title = title
        self.services = services
        self.style = style
        self.onRefresh = onRefresh
        self.onServiceAction = onServiceAction
    }
    
    var body: some View {
        CWCard(
            title: title,
            subtitle: "\(services.count) 个服务",
            headerIcon: "gear.circle",
            style: style.cardStyle
        ) {
            VStack(spacing: CWTheme.spacing.m) {
                // 服务状态列表
                ForEach(services) { service in
                    ServiceStatusRow(
                        service: service,
                        style: style.rowStyle
                    ) {
                        onServiceAction?(service)
                    }
                }
                
                // 操作按钮
                if let onRefresh = onRefresh {
                    HStack {
                        Spacer()
                        
                        CWButton(
                            "刷新状态",
                            icon: "arrow.clockwise",
                            style: .ghost,
                            size: .small
                        ) {
                            onRefresh()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 服务状态行组件
struct ServiceStatusRow: View {
    let service: ServiceStatus
    let style: ServiceStatusRowStyle
    let onAction: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: CWTheme.spacing.m) {
            // 服务图标
            ZStack {
                Circle()
                    .fill(service.status.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: service.icon)
                    .font(.system(size: 16))
                    .foregroundColor(service.status.color)
                    .rotationEffect(.degrees(isAnimating && service.status == .running ? 360 : 0))
                    .animation(
                        isAnimating && service.status == .running ? 
                        Animation.linear(duration: 2.0).repeatForever(autoreverses: false) : .none,
                        value: isAnimating
                    )
            }
            
            // 服务信息
            VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                Text(service.name)
                    .font(CWTheme.fonts.subheadline)
                    .foregroundColor(CWTheme.colors.primaryText)
                    .fontWeight(.medium)
                
                Text(service.description)
                    .font(CWTheme.fonts.caption)
                    .foregroundColor(CWTheme.colors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 状态指示器
            VStack(alignment: .trailing, spacing: CWTheme.spacing.xs) {
                CWStatusLabel(status: service.status)
                
                if let detail = service.statusDetail {
                    Text(detail)
                        .font(CWTheme.fonts.caption2)
                        .foregroundColor(CWTheme.colors.tertiaryText)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(CWTheme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        )
        .onTapGesture {
            onAction()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 服务状态数据模型
struct ServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let status: CWStatusType
    let statusDetail: String?
    let isInteractive: Bool
    
    init(
        name: String,
        description: String,
        icon: String,
        status: CWStatusType,
        statusDetail: String? = nil,
        isInteractive: Bool = false
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.status = status
        self.statusDetail = statusDetail
        self.isInteractive = isInteractive
    }
}

// MARK: - 扩展状态类型
extension CWStatusType {
    var color: Color {
        switch self {
        case .ready: return CWTheme.colors.success
        case .running: return CWTheme.colors.processing
        case .error: return CWTheme.colors.error
        case .warning: return CWTheme.colors.warning
        case .disabled: return CWTheme.colors.secondaryText
        }
    }
}

// MARK: - 状态卡片样式枚举
enum StatusCardStyle {
    case `default`
    case compact
    case detailed
    
    var cardStyle: CWCardStyle {
        switch self {
        case .default: return .default
        case .compact: return .transparent
        case .detailed: return .highlighted
        }
    }
    
    var rowStyle: ServiceStatusRowStyle {
        switch self {
        case .default: return .default
        case .compact: return .compact
        case .detailed: return .detailed
        }
    }
}

// MARK: - 服务状态行样式枚举
enum ServiceStatusRowStyle {
    case `default`
    case compact
    case detailed
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.cardBackground.opacity(0.3)
        case .compact: return Color.clear
        case .detailed: return CWTheme.colors.cardBackground
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return Color.clear
        case .compact: return Color.clear
        case .detailed: return CWTheme.colors.border
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .default: return 0
        case .compact: return 0
        case .detailed: return 1
        }
    }
}

// MARK: - 系统状态卡片组件
struct SystemStatusCard: View {
    @ObservedObject var recordingState: RecordingState
    let onPermissionAction: (PermissionType) -> Void
    
    var body: some View {
        StatusCard(
            title: "系统状态",
            services: systemServices,
            style: .detailed,
            onRefresh: {
                recordingState.refreshPermissionStatus()
            },
            onServiceAction: { service in
                if let permissionType = permissionTypeForService(service) {
                    onPermissionAction(permissionType)
                }
            }
        )
    }
    
    private var systemServices: [ServiceStatus] {
        [
            ServiceStatus(
                name: "辅助功能权限",
                description: "用于键盘事件监听",
                icon: "hand.point.up.left",
                status: recordingState.hasAccessibilityPermission ? .ready : .error,
                statusDetail: recordingState.hasAccessibilityPermission ? "已授权" : "未授权",
                isInteractive: !recordingState.hasAccessibilityPermission
            ),
            ServiceStatus(
                name: "麦克风权限",
                description: "用于音频录制",
                icon: "mic.fill",
                status: recordingState.hasMicrophonePermission ? .ready : .warning,
                statusDetail: recordingState.hasMicrophonePermission ? "已授权" : "需要授权",
                isInteractive: !recordingState.hasMicrophonePermission
            ),
            ServiceStatus(
                name: "键盘监听器",
                description: "监听 O 键连击事件",
                icon: "keyboard",
                status: isKeyboardMonitorRunning ? .ready : .disabled,
                statusDetail: recordingState.keyboardMonitorStatus,
                isInteractive: true
            ),
            ServiceStatus(
                name: "语音识别服务",
                description: "Sherpa-ONNX 识别引擎",
                icon: "brain.head.profile",
                status: asrServiceStatus,
                statusDetail: asrServiceStatusDetail,
                isInteractive: true
            ),
            ServiceStatus(
                name: "音频采集服务",
                description: "音频录制和处理",
                icon: "waveform",
                status: recordingState.isAudioCaptureServiceReady ? .ready : .warning,
                statusDetail: recordingState.isAudioCaptureServiceReady ? "就绪" : "等待中",
                isInteractive: false
            ),
            ServiceStatus(
                name: "文本输入服务",
                description: "文本输出和剪贴板",
                icon: "text.cursor",
                status: recordingState.hasTextInputPermission ? .ready : .warning,
                statusDetail: recordingState.hasTextInputPermission ? "已授权" : "等待授权",
                isInteractive: false
            )
        ]
    }
    
    private var isKeyboardMonitorRunning: Bool {
        return recordingState.keyboardMonitorStatus == "已启动" || 
               recordingState.keyboardMonitorStatus == "正在监听"
    }
    
    private var asrServiceStatus: CWStatusType {
        if recordingState.isASRServiceInitialized {
            return .ready
        } else if recordingState.isASRServiceRunning {
            return .running
        } else {
            return .error
        }
    }
    
    private var asrServiceStatusDetail: String {
        if recordingState.isASRServiceInitialized {
            return "已初始化"
        } else if recordingState.isASRServiceRunning {
            return recordingState.initializationProgress
        } else {
            return "未启动"
        }
    }
    
    private func permissionTypeForService(_ service: ServiceStatus) -> PermissionType? {
        switch service.name {
        case "辅助功能权限": return .accessibility
        case "麦克风权限": return .microphone
        default: return nil
        }
    }
}

// MARK: - 权限类型枚举
enum PermissionType {
    case accessibility
    case microphone
}

// MARK: - 性能监控卡片组件
struct PerformanceCard: View {
    @State private var cpuUsage: Double = 0.0
    @State private var memoryUsage: Double = 0.0
    @State private var updateTimer: Timer?
    
    var body: some View {
        CWCard(
            title: "性能监控",
            subtitle: "实时系统资源使用情况",
            headerIcon: "speedometer",
            style: .default
        ) {
            VStack(spacing: CWTheme.spacing.m) {
                // CPU 使用率
                VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                    HStack {
                        Text("CPU 使用率")
                            .font(CWTheme.fonts.subheadline)
                            .foregroundColor(CWTheme.colors.primaryText)
                        
                        Spacer()
                        
                        Text("\(Int(cpuUsage * 100))%")
                            .font(CWTheme.fonts.monospacedDigits)
                            .foregroundColor(cpuUsageColor)
                    }
                    
                    CWProgressBar(
                        progress: cpuUsage,
                        style: .colorful,
                        showPercentage: false
                    )
                }
                
                // 内存使用率
                VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
                    HStack {
                        Text("内存使用率")
                            .font(CWTheme.fonts.subheadline)
                            .foregroundColor(CWTheme.colors.primaryText)
                        
                        Spacer()
                        
                        Text("\(Int(memoryUsage * 100))%")
                            .font(CWTheme.fonts.monospacedDigits)
                            .foregroundColor(memoryUsageColor)
                    }
                    
                    CWProgressBar(
                        progress: memoryUsage,
                        style: .default,
                        showPercentage: false
                    )
                }
                
                // 性能统计
                HStack(spacing: CWTheme.spacing.m) {
                    CWValueLabel(
                        title: "平均延迟",
                        value: "120",
                        unit: "ms",
                        style: .compact
                    )
                    
                    CWValueLabel(
                        title: "运行时间",
                        value: "2.5",
                        unit: "小时",
                        style: .compact
                    )
                    
                    CWValueLabel(
                        title: "处理次数",
                        value: "42",
                        unit: "次",
                        style: .compact
                    )
                }
            }
        }
        .onAppear {
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
    }
    
    private var cpuUsageColor: Color {
        if cpuUsage < 0.5 {
            return CWTheme.colors.success
        } else if cpuUsage < 0.8 {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.error
        }
    }
    
    private var memoryUsageColor: Color {
        if memoryUsage < 0.6 {
            return CWTheme.colors.success
        } else if memoryUsage < 0.8 {
            return CWTheme.colors.warning
        } else {
            return CWTheme.colors.error
        }
    }
    
    private func startPerformanceMonitoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 模拟性能数据更新
            withAnimation(.easeInOut(duration: 0.5)) {
                cpuUsage = Double.random(in: 0.1...0.4)
                memoryUsage = Double.random(in: 0.3...0.7)
            }
        }
    }
    
    private func stopPerformanceMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        SystemStatusCard(
            recordingState: RecordingState.shared,
            onPermissionAction: { permission in
                print("权限操作: \(permission)")
            }
        )
        
        PerformanceCard()
    }
    .padding()
    .background(CWTheme.colors.background)
    .frame(width: 400, height: 800)
}