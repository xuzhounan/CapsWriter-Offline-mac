import SwiftUI

// MARK: - About Settings View

/// 关于界面
struct AboutSettingsView: View {
    @State private var showingLicenses = false
    @State private var showingChangelog = false
    @State private var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @State private var buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 应用信息
                AppInfoSection(appVersion: appVersion, buildNumber: buildNumber)
                
                // 开发团队
                DevelopmentTeamSection()
                
                // 开源组件
                OpenSourceSection(showingLicenses: $showingLicenses)
                
                // 版本信息
                VersionInfoSection(showingChangelog: $showingChangelog)
                
                // 支持与反馈
                SupportSection()
                
                // 法律信息
                LegalSection()
            }
            .padding()
        }
        .sheet(isPresented: $showingLicenses) {
            LicensesView()
        }
        .sheet(isPresented: $showingChangelog) {
            ChangelogView()
        }
    }
}

// MARK: - App Info Section

struct AppInfoSection: View {
    let appVersion: String
    let buildNumber: String
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和名称
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                
                VStack(spacing: 4) {
                    Text("CapsWriter")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("离线语音转录工具")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("版本 \(appVersion) (构建 \(buildNumber))")
                        .font(.system(size: 13, family: .monospaced))
                        .foregroundColor(.tertiary)
                }
            }
            
            // 应用描述
            VStack(spacing: 8) {
                Text("基于 Sherpa-ONNX 的 macOS 原生语音识别应用")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                
                Text("支持离线中文语音识别、热词替换、实时转录等功能")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 400)
        }
    }
}

// MARK: - Development Team Section

struct DevelopmentTeamSection: View {
    var body: some View {
        SettingsSection(
            title: "开发团队",
            description: "感谢所有为 CapsWriter 做出贡献的开发者们"
        ) {
            VStack(spacing: 16) {
                // 主要开发者
                VStack(spacing: 12) {
                    DeveloperCard(
                        name: "CapsWriter Team",
                        role: "核心开发团队",
                        avatar: "person.circle",
                        description: "负责应用的整体架构设计和核心功能开发"
                    )
                    
                    DeveloperCard(
                        name: "Sherpa-ONNX Contributors",
                        role: "语音识别引擎",
                        avatar: "waveform.path.ecg",
                        description: "提供高质量的离线语音识别技术支持"
                    )
                }
                
                Divider()
                
                // 致谢
                VStack(alignment: .leading, spacing: 8) {
                    Text("特别感谢")
                        .font(.system(size: 14, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 阿里巴巴 Paraformer 模型团队")
                        Text("• Sherpa-ONNX 开源社区")
                        Text("• macOS 开发者社区")
                        Text("• 所有 Beta 测试用户")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Developer Card

struct DeveloperCard: View {
    let name: String
    let role: String
    let avatar: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: avatar)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                
                Text(role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Open Source Section

struct OpenSourceSection: View {
    @Binding var showingLicenses: Bool
    
    var body: some View {
        SettingsSection(
            title: "开源组件",
            description: "CapsWriter 基于以下优秀的开源项目构建"
        ) {
            VStack(spacing: 16) {
                // 主要组件
                VStack(spacing: 8) {
                    OpenSourceComponent(
                        name: "Sherpa-ONNX",
                        version: "1.9.0",
                        license: "Apache 2.0",
                        description: "高性能离线语音识别框架"
                    )
                    
                    OpenSourceComponent(
                        name: "Paraformer",
                        version: "2023.11",
                        license: "Apache 2.0",
                        description: "阿里巴巴开源中文语音识别模型"
                    )
                    
                    OpenSourceComponent(
                        name: "ONNX Runtime",
                        version: "1.16.0",
                        license: "MIT",
                        description: "跨平台机器学习推理加速器"
                    )
                }
                
                Divider()
                
                // 查看完整许可证
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开源许可证")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("查看所有第三方组件的详细许可证信息")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("查看许可证") {
                        showingLicenses = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // 开源贡献
                InfoCard(
                    title: "开源贡献",
                    description: "CapsWriter 的部分代码和改进也将回馈给开源社区。我们相信开源协作的力量。",
                    icon: "heart.circle",
                    backgroundColor: .pink
                )
            }
        }
    }
}

// MARK: - Open Source Component

struct OpenSourceComponent: View {
    let name: String
    let version: String
    let license: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text("v\(version)")
                        .font(.system(size: 11, family: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("许可证: \(license)")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Version Info Section

struct VersionInfoSection: View {
    @Binding var showingChangelog: Bool
    
    var body: some View {
        SettingsSection(
            title: "版本信息",
            description: "查看版本历史和更新日志"
        ) {
            VStack(spacing: 16) {
                // 系统信息
                VStack(spacing: 8) {
                    SystemInfoRow(title: "macOS 版本", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    SystemInfoRow(title: "系统架构", value: systemArchitecture)
                    SystemInfoRow(title: "Xcode 版本", value: xcodeVersion)
                    SystemInfoRow(title: "Swift 版本", value: swiftVersion)
                }
                
                Divider()
                
                // 版本历史
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("更新日志")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("查看详细的版本更新历史")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("查看更新日志") {
                        showingChangelog = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // 检查更新
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自动更新")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("检查并下载最新版本")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("检查更新") {
                        checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private var systemArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }
    
    private var xcodeVersion: String {
        #if DEBUG
        return Bundle.main.infoDictionary?["DTXcode"] as? String ?? "Unknown"
        #else
        return "Release Build"
        #endif
    }
    
    private var swiftVersion: String {
        #if swift(>=5.9)
        return "Swift 5.9+"
        #elseif swift(>=5.8)
        return "Swift 5.8"
        #elseif swift(>=5.7)
        return "Swift 5.7"
        #else
        return "Swift 5.x"
        #endif
    }
    
    private func checkForUpdates() {
        print("🔄 检查更新")
        // 实现更新检查逻辑
    }
}

// MARK: - System Info Row

struct SystemInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, family: .monospaced))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Support Section

struct SupportSection: View {
    var body: some View {
        SettingsSection(
            title: "支持与反馈",
            description: "获取帮助、报告问题或提供反馈建议"
        ) {
            VStack(spacing: 16) {
                // 支持选项
                VStack(spacing: 8) {
                    SupportOption(
                        title: "用户手册",
                        description: "查看详细的使用说明和常见问题解答",
                        icon: "book.circle",
                        action: openUserManual
                    )
                    
                    SupportOption(
                        title: "GitHub 仓库",
                        description: "查看源代码、报告问题或参与开发",
                        icon: "chevron.left.forwardslash.chevron.right",
                        action: openGitHubRepo
                    )
                    
                    SupportOption(
                        title: "问题反馈",
                        description: "报告 Bug 或提出功能建议",
                        icon: "exclamationmark.bubble.circle",
                        action: reportIssue
                    )
                    
                    SupportOption(
                        title: "联系我们",
                        description: "通过邮件联系开发团队",
                        icon: "envelope.circle",
                        action: contactSupport
                    )
                }
                
                Divider()
                
                // 社区链接
                VStack(alignment: .leading, spacing: 8) {
                    Text("社区")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack(spacing: 12) {
                        Button("Discord") {
                            openDiscord()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("QQ 群") {
                            openQQGroup()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("微信群") {
                            openWeChatGroup()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func openUserManual() {
        if let url = URL(string: "https://capswriter.com/docs") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openGitHubRepo() {
        if let url = URL(string: "https://github.com/capswriter/capswriter-mac") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func reportIssue() {
        if let url = URL(string: "https://github.com/capswriter/capswriter-mac/issues") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:support@capswriter.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openDiscord() {
        print("💬 打开 Discord")
    }
    
    private func openQQGroup() {
        print("💬 打开 QQ 群")
    }
    
    private func openWeChatGroup() {
        print("💬 打开微信群")
    }
}

// MARK: - Support Option

struct SupportOption: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legal Section

struct LegalSection: View {
    var body: some View {
        SettingsSection(
            title: "法律信息",
            description: "隐私政策、服务条款和法律声明"
        ) {
            VStack(spacing: 16) {
                // 法律文档
                VStack(spacing: 8) {
                    LegalDocument(
                        title: "隐私政策",
                        description: "了解我们如何保护您的隐私和数据安全",
                        action: openPrivacyPolicy
                    )
                    
                    LegalDocument(
                        title: "服务条款",
                        description: "使用 CapsWriter 的条款和条件",
                        action: openTermsOfService
                    )
                    
                    LegalDocument(
                        title: "开源许可证",
                        description: "第三方开源组件的许可证信息",
                        action: openLicenses
                    )
                }
                
                Divider()
                
                // 版权信息
                VStack(spacing: 4) {
                    Text("© 2024 CapsWriter Team. All rights reserved.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("CapsWriter 是在 MIT 许可证下发布的开源软件")
                        .font(.system(size: 10))
                        .foregroundColor(.tertiary)
                }
            }
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://capswriter.com/privacy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://capswriter.com/terms") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openLicenses() {
        if let url = URL(string: "https://capswriter.com/licenses") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Legal Document

struct LegalDocument: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Views

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("第三方许可证")
                .font(.headline)
                .padding()
            
            Text("这里将显示所有第三方组件的详细许可证信息")
                .padding()
            
            Button("关闭") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
}

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("更新日志")
                .font(.headline)
                .padding()
            
            Text("这里将显示详细的版本更新历史")
                .padding()
            
            Button("关闭") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Preview

#Preview {
    AboutSettingsView()
        .frame(width: 600, height: 1000)
}