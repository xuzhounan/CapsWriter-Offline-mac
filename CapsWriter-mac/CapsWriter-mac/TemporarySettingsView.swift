import SwiftUI

/// 临时设置视图 - 用于解决构建问题
/// 完整的设置界面位于 Sources/Views/Settings/ 目录下
struct TemporarySettingsView: View {
    @State private var showFullSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("设置")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 说明
            Text("完整的设置界面正在开发中")
                .font(.body)
                .foregroundColor(.secondary)
            
            // 基本配置项
            VStack(alignment: .leading, spacing: 16) {
                Text("基本设置")
                    .font(.headline)
                
                Toggle("启用自动启动", isOn: .constant(false))
                Toggle("显示状态栏图标", isOn: .constant(true))
                Toggle("启用声音提示", isOn: .constant(true))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            
            Spacer()
            
            // 说明文字
            Text("完整设置界面包含:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• 通用设置 (应用行为、界面偏好)")
                Text("• 音频设置 (设备选择、音质配置)")
                Text("• 识别设置 (模型配置、语言设置)")
                Text("• 热词管理 (自定义热词、导入导出)")
                Text("• 快捷键配置 (键位自定义)")
                Text("• 高级设置 (日志、性能调优)")
                Text("• 关于信息 (版本、许可证)")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    TemporarySettingsView()
}