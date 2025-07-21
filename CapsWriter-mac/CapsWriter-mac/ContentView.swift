import SwiftUI
import AVFoundation
import Foundation

struct ContentView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var animationScale: CGFloat = 1.0
    @State private var selectedTab = 0
    @State private var permissionCheckTimer: Timer?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 主页面 - 原有内容
            MainDashboardView(recordingState: recordingState, animationScale: $animationScale)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
                .tag(0)
            
            // 识别服务页面 - 临时内联实现
            ASRServicePlaceholderView()
                .tabItem {
                    Image(systemName: "waveform.and.mic")
                    Text("识别服务")
                }
                .tag(1)
            
            // 实时转录页面
            RealTimeTranscriptionView()
                .tabItem {
                    Image(systemName: "text.bubble")
                    Text("实时转录")
                }
                .tag(2)
            
            // 日志页面 - 任务3.3
            LogView()
                .tabItem {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("系统日志")
                }
                .tag(3)
            
            // 设置页面 - 任务4.2 (临时设置界面)
            SettingsPlaceholderView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(4)
        }
        .onAppear {
            startPermissionCheck()
        }
        .onDisappear {
            stopPermissionCheck()
        }
    }
    
    private func startPermissionCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // 简化权限检查 - 直接检查状态
            recordingState.objectWillChange.send()
        }
    }
    
    private func stopPermissionCheck() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
}

// MARK: - Main Dashboard View
struct MainDashboardView: View {
    @ObservedObject var recordingState: RecordingState
    @Binding var animationScale: CGFloat
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 录音状态指示器
            VStack(spacing: 20) {
                // 主录音按钮
                Button(action: {
                    if recordingState.isRecording {
                        recordingState.stopRecording()
                    } else {
                        recordingState.startRecording()
                    }
                }) {
                    Image(systemName: recordingState.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(recordingState.isRecording ? .red : .blue)
                        .scaleEffect(animationScale)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingState.isRecording)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if recordingState.isRecording {
                        animationScale = 1.2
                    } else {
                        animationScale = 1.0
                    }
                }
                .onChange(of: recordingState.isRecording) { isRecording in
                    animationScale = isRecording ? 1.2 : 1.0
                }
                
                // 状态文本
                Text(recordingState.isRecording ? "录音中..." : "点击开始录音")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // 识别结果显示占位符
                ScrollView {
                    Text("识别结果将在这里显示...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.textBackgroundColor))
                        )
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // 权限状态
            PermissionStatusView(recordingState: recordingState)
        }
        .padding()
    }
}

// MARK: - Permission Status View
struct PermissionStatusView: View {
    @ObservedObject var recordingState: RecordingState
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("麦克风权限")
                Spacer()
            }
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("辅助功能权限")
                Spacer()
            }
        }
        .font(.caption)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Placeholder Views
struct ASRServicePlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("识别服务")
                .font(.title)
                .foregroundColor(.secondary)
            Text("语音识别服务配置和管理")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct RealTimeTranscriptionView: View {
    var body: some View {
        VStack {
            Image(systemName: "text.bubble")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("实时转录")
                .font(.title)
                .foregroundColor(.secondary)
            Text("实时语音转文字功能")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct SettingsPlaceholderView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("应用行为")
                    .font(.headline)
                
                HStack {
                    Text("启用自动启动")
                    Spacer()
                    Toggle("", isOn: $configManager.appBehavior.enableAutoLaunch)
                        .labelsHidden()
                }
                
                HStack {
                    Text("显示状态栏图标")
                    Spacer()
                    Toggle("", isOn: $configManager.ui.showStatusBarIcon)
                        .labelsHidden()
                }
                
                HStack {
                    Text("启用声音提示")
                    Spacer()
                    Toggle("", isOn: $configManager.ui.enableSoundEffects)
                        .labelsHidden()
                }
                
                HStack {
                    Text("显示录音指示器")
                    Spacer()
                    Toggle("", isOn: $configManager.ui.showRecordingIndicator)
                        .labelsHidden()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}