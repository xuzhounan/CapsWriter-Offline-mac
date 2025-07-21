import SwiftUI
import Combine

/// 用户友好的错误通知视图
/// 显示应用程序错误并提供用户操作选项
struct ErrorNotificationView: View {
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var showingErrorDetail = false
    @State private var selectedError: ErrorHandler.ErrorRecord?
    
    var body: some View {
        VStack {
            if let highestError = errorHandler.currentHighestSeverityError {
                errorBanner(for: highestError)
            }
        }
        .sheet(isPresented: $showingErrorDetail) {
            if let error = selectedError {
                ErrorDetailView(error: error)
            }
        }
        .onChange(of: errorHandler.shouldShowErrorNotification) { shouldShow in
            if shouldShow {
                // 自动隐藏通知
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    errorHandler.shouldShowErrorNotification = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func errorBanner(for error: ErrorHandler.ErrorRecord) -> some View {
        if !error.isResolved && errorHandler.shouldShowErrorNotification {
            HStack(spacing: 12) {
                // 错误图标
                Image(systemName: iconForSeverity(error.severity))
                    .foregroundColor(colorForSeverity(error.severity))
                    .font(.title2)
                
                // 错误信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.error.localizedDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("\(error.context.component) - \(error.context.operation)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(error.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 8) {
                    // 查看详情按钮
                    Button("详情") {
                        selectedError = error
                        showingErrorDetail = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    // 重试按钮（如果支持重试）
                    if error.recoveryStrategy == .retry {
                        Button("重试") {
                            errorHandler.markErrorResolved(error.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    // 关闭按钮
                    Button("关闭") {
                        errorHandler.shouldShowErrorNotification = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorForSeverity(error.severity).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorForSeverity(error.severity).opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: errorHandler.shouldShowErrorNotification)
        }
    }
    
    private func iconForSeverity(_ severity: ErrorHandler.ErrorSeverity) -> String {
        switch severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        }
    }
    
    private func colorForSeverity(_ severity: ErrorHandler.ErrorSeverity) -> Color {
        switch severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// 错误详情视图
struct ErrorDetailView: View {
    let error: ErrorHandler.ErrorRecord
    @Environment(\.dismiss) private var dismiss
    @StateObject private var errorHandler = ErrorHandler.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 错误概述
                    errorOverviewSection
                    
                    // 错误详情
                    errorDetailsSection
                    
                    // 恢复策略
                    recoveryStrategySection
                    
                    // 上下文信息
                    contextSection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("错误详情")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("错误概述")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconForSeverity(error.severity))
                    .foregroundColor(colorForSeverity(error.severity))
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.error.localizedDescription)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    HStack {
                        Label("严重程度", systemImage: "exclamationmark.triangle")
                        Text(error.severity.rawValue)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForSeverity(error.severity))
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Label("状态", systemImage: error.isResolved ? "checkmark.circle" : "clock")
                        Text(error.isResolved ? "已解决" : "未解决")
                            .fontWeight(.semibold)
                            .foregroundColor(error.isResolved ? .green : .orange)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    @ViewBuilder
    private var errorDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("详细信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "组件", value: error.context.component)
                DetailRow(label: "操作", value: error.context.operation)
                DetailRow(label: "发生时间", value: DateFormatter.full.string(from: error.context.timestamp))
                
                if error.isResolved, let resolvedAt = error.resolvedAt {
                    DetailRow(label: "解决时间", value: DateFormatter.full.string(from: resolvedAt))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    @ViewBuilder
    private var recoveryStrategySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("恢复策略")
                .font(.headline)
            
            HStack(spacing: 8) {
                Image(systemName: iconForRecoveryStrategy(error.recoveryStrategy))
                    .foregroundColor(.blue)
                
                Text(descriptionForRecoveryStrategy(error.recoveryStrategy))
                    .font(.subheadline)
                
                Spacer()
            }
            
            Text(detailForRecoveryStrategy(error.recoveryStrategy))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
    
    @ViewBuilder
    private var contextSection: some View {
        if !error.context.userInfo.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("上下文信息")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(error.context.userInfo.keys.sorted()), id: \.self) { key in
                        DetailRow(
                            label: key,
                            value: String(describing: error.context.userInfo[key] ?? "N/A")
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !error.isResolved {
                HStack(spacing: 12) {
                    if error.recoveryStrategy == .retry {
                        Button("重试") {
                            errorHandler.markErrorResolved(error.id)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if error.recoveryStrategy == .userAction {
                        Button("手动处理") {
                            // 触发用户操作
                            openSystemSettings(for: error)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("标记为已解决") {
                        errorHandler.markErrorResolved(error.id)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Button("复制错误信息") {
                copyErrorInfo()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // Helper methods
    private func iconForSeverity(_ severity: ErrorHandler.ErrorSeverity) -> String {
        switch severity {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    private func colorForSeverity(_ severity: ErrorHandler.ErrorSeverity) -> Color {
        switch severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func iconForRecoveryStrategy(_ strategy: ErrorHandler.RecoveryStrategy) -> String {
        switch strategy {
        case .none: return "minus.circle"
        case .retry: return "arrow.clockwise"
        case .fallback: return "arrow.down.circle"
        case .restart: return "restart.circle"
        case .userAction: return "person.circle"
        }
    }
    
    private func descriptionForRecoveryStrategy(_ strategy: ErrorHandler.RecoveryStrategy) -> String {
        switch strategy {
        case .none: return "无需操作"
        case .retry: return "自动重试"
        case .fallback: return "降级处理"
        case .restart: return "重启服务"
        case .userAction: return "需要用户操作"
        }
    }
    
    private func detailForRecoveryStrategy(_ strategy: ErrorHandler.RecoveryStrategy) -> String {
        switch strategy {
        case .none: return "此错误不需要特殊的恢复操作"
        case .retry: return "系统将自动重试失败的操作"
        case .fallback: return "系统将使用备用方案继续运行"
        case .restart: return "相关服务将被重启以恢复正常功能"
        case .userAction: return "需要用户手动解决此问题"
        }
    }
    
    private func openSystemSettings(for error: ErrorHandler.ErrorRecord) {
        // 根据错误类型打开相应的系统设置
        if error.error.localizedDescription.contains("权限") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func copyErrorInfo() {
        let errorInfo = """
        错误信息: \(error.error.localizedDescription)
        组件: \(error.context.component)
        操作: \(error.context.operation)
        严重程度: \(error.severity.rawValue)
        发生时间: \(DateFormatter.full.string(from: error.context.timestamp))
        恢复策略: \(descriptionForRecoveryStrategy(error.recoveryStrategy))
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(errorInfo, forType: .string)
    }
}

/// 详情行视图
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// DateFormatter 扩展
extension DateFormatter {
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    ErrorNotificationView()
}