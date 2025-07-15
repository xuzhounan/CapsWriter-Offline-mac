import SwiftUI

struct ContentView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 30) {
            // 应用图标区域
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            // 欢迎文字
            VStack(spacing: 10) {
                Text("Welcome to CapsWriter for macOS")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("音频转录工具")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 功能描述
            VStack(spacing: 8) {
                Text("功能特点：")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("实时语音转录")
                    }
                    
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.green)
                        Text("智能标点符号")
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.orange)
                        Text("多种输出格式")
                    }
                }
                .font(.subheadline)
            }
            
            // 权限和状态显示
            VStack(spacing: 12) {
                // 辅助功能权限状态
                HStack {
                    Image(systemName: recordingState.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(recordingState.hasAccessibilityPermission ? .green : .red)
                    
                    Text("辅助功能权限")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.hasAccessibilityPermission ? "已授权" : "未授权")
                        .font(.caption)
                        .foregroundColor(recordingState.hasAccessibilityPermission ? .green : .red)
                        .fontWeight(.medium)
                }
                
                // 监听器状态
                HStack {
                    Image(systemName: "ear.fill")
                        .foregroundColor(.blue)
                    
                    Text("键盘监听器")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(recordingState.keyboardMonitorStatus)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // 权限请求按钮
                if !recordingState.hasAccessibilityPermission {
                    Button("请求辅助功能权限") {
                        KeyboardMonitor.requestAccessibilityPermission()
                        // 延迟检查权限状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            checkPermissionStatus()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            )
            
            // 录音状态显示
            if recordingState.isRecording {
                VStack(spacing: 15) {
                    // 录音动画指示器
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                            .scaleEffect(animationScale)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                                value: animationScale
                            )
                        
                        Text("正在录音...")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    // 录音提示
                    Text("按住右 Shift 键进行语音输入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 录音波形效果（模拟）
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 3, height: CGFloat.random(in: 10...40))
                                .animation(
                                    .easeInOut(duration: 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.05),
                                    value: recordingState.isRecording
                                )
                        }
                    }
                    .frame(height: 50)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            } else {
                // 默认状态信息
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("服务已准备就绪")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("按住右 Shift 键开始录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("CapsWriter-mac")
        .onAppear {
            animationScale = 1.2
            checkPermissionStatus()
            startPeriodicStatusCheck()
        }
    }
    
    // MARK: - 权限检查方法
    private func checkPermissionStatus() {
        let hasPermission = KeyboardMonitor.checkAccessibilityPermission()
        recordingState.updateAccessibilityPermission(hasPermission)
        
        // 更新监听器状态
        if hasPermission {
            recordingState.updateKeyboardMonitorStatus("已启动")
        } else {
            recordingState.updateKeyboardMonitorStatus("等待权限")
        }
    }
    
    private func startPeriodicStatusCheck() {
        // 每秒检查一次权限状态
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissionStatus()
        }
    }
}

#Preview {
    ContentView()
}