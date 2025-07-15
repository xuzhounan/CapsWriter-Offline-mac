import SwiftUI

struct ASRServiceView: View {
    @StateObject private var asrService = SherpaASRService()
    @State private var isAutoScroll = true
    
    var body: some View {
        VStack(spacing: 20) {
            // 服务控制区域
            VStack(spacing: 16) {
                // 服务状态
                HStack {
                    Image(systemName: asrService.isServiceRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(asrService.isServiceRunning ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("语音识别服务")
                            .font(.headline)
                        Text(asrService.isServiceRunning ? "运行中" : "已停止")
                            .font(.caption)
                            .foregroundColor(asrService.isServiceRunning ? .green : .red)
                    }
                    
                    Spacer()
                }
                
                // 识别状态
                HStack {
                    Image(systemName: asrService.isRecognizing ? "mic.fill" : "mic.slash.fill")
                        .foregroundColor(asrService.isRecognizing ? .blue : .gray)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("识别状态")
                            .font(.headline)
                        Text(asrService.isRecognizing ? "正在识别" : "等待中")
                            .font(.caption)
                            .foregroundColor(asrService.isRecognizing ? .blue : .gray)
                    }
                    
                    Spacer()
                }
                
                // 控制按钮
                HStack(spacing: 12) {
                    Button(asrService.isServiceRunning ? "停止服务" : "启动服务") {
                        if asrService.isServiceRunning {
                            asrService.stopService()
                        } else {
                            asrService.startService()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(false)
                    
                    Button(asrService.isRecognizing ? "停止识别" : "开始识别") {
                        if asrService.isRecognizing {
                            asrService.stopRecognition()
                        } else {
                            asrService.startRecognition()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!asrService.isServiceRunning)
                    
                    Button("清空日志") {
                        asrService.logs.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
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
            
            // 识别结果区域
            if !asrService.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("识别结果")
                            .font(.headline)
                        Spacer()
                        Button("复制") {
                            copyToClipboard(asrService.transcript)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ScrollView {
                        Text(asrService.transcript)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 120)
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
            }
            
            // 日志区域
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("运行日志")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("自动滚动", isOn: $isAutoScroll)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(asrService.logs.enumerated()), id: \.offset) { index, log in
                                HStack(alignment: .top) {
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                    
                                    Text(log)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    index % 2 == 0 ? Color.clear : Color(.controlBackgroundColor).opacity(0.5)
                                )
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .onChange(of: asrService.logs.count) { _ in
                        if isAutoScroll && !asrService.logs.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(asrService.logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("识别服务")
        .onAppear {
            // 自动启动服务（可选）
            // asrService.startService()
        }
        .onDisappear {
            // 清理资源
            if asrService.isRecognizing {
                asrService.stopRecognition()
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    ASRServiceView()
        .frame(width: 600, height: 500)
}