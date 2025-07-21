import SwiftUI

// MARK: - Main Settings View

/// 主设置界面 - 使用 NavigationSplitView 实现侧边栏和详细内容分离
struct SettingsView: View {
    @StateObject private var configManager = DIContainer.shared.resolve(ConfigurationManager.self)!
    @State private var selectedCategory: SettingsCategory = .general
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationSplitView {
            // 左侧导航栏
            SettingsSidebar(selectedCategory: $selectedCategory)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // 右侧详细设置
            SettingsDetailView(
                category: selectedCategory,
                configManager: configManager
            )
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 导入导出按钮
                ConfigImportExportButtons(
                    showingImporter: $showingImporter,
                    showingExporter: $showingExporter
                )
                
                Divider()
                
                // 重置按钮
                ResetSettingsButton(showingAlert: $showingResetAlert)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            handleConfigImport(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: ConfigExportDocument(configManager: configManager),
            contentType: .json,
            defaultFilename: "CapsWriter-Config-\(formattedDate())"
        ) { result in
            handleConfigExport(result)
        }
        .alert("重置所有设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                configManager.resetToDefaults()
            }
        } message: {
            Text("这将重置所有设置为默认值，此操作无法撤销。确定要继续吗？")
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Private Methods
    
    private func handleConfigImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importConfiguration(from: url)
        case .failure(let error):
            print("❌ 配置导入失败: \(error)")
        }
    }
    
    private func handleConfigExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ 配置已导出到: \(url.path)")
        case .failure(let error):
            print("❌ 配置导出失败: \(error)")
        }
    }
    
    private func importConfiguration(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if configManager.importConfiguration(from: data) {
                print("✅ 配置导入成功")
            } else {
                print("❌ 配置导入失败：格式错误或验证失败")
            }
        } catch {
            print("❌ 配置文件读取失败: \(error)")
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Settings Sidebar

/// 设置侧边栏
struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // 应用标题
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading) {
                    Text("CapsWriter")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("语音转录工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 分类列表
            List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                SettingsCategoryRow(category: category)
                    .tag(category)
            }
            .listStyle(SidebarListStyle())
        }
    }
}

/// 设置分类行
struct SettingsCategoryRow: View {
    let category: SettingsCategory
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                
                Text(category.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Detail View

/// 设置详细内容视图
struct SettingsDetailView: View {
    let category: SettingsCategory
    let configManager: ConfigurationManager
    
    var body: some View {
        Group {
            switch category {
            case .general:
                GeneralSettingsView(configManager: configManager)
            case .audio:
                SimplifiedAudioSettingsView(configManager: configManager)
            case .recognition:
                RecognitionSettingsView(configManager: configManager)
            case .hotwords:
                HotWordSettingsView(configManager: configManager)
            case .shortcuts:
                ShortcutSettingsView(configManager: configManager)
            case .advanced:
                AdvancedSettingsView(configManager: configManager)
            case .about:
                AboutSettingsView()
            }
        }
        .navigationTitle(category.displayName)
        .navigationSubtitle(category.description)
    }
}

// MARK: - Toolbar Components

/// 导入导出按钮组
struct ConfigImportExportButtons: View {
    @Binding var showingImporter: Bool
    @Binding var showingExporter: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { showingImporter = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                    Text("导入")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: { showingExporter = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("导出")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

/// 重置设置按钮
struct ResetSettingsButton: View {
    @Binding var showingAlert: Bool
    
    var body: some View {
        Button(action: { showingAlert = true }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                Text("重置")
                    .font(.system(size: 12))
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundColor(.orange)
    }
}

// MARK: - Configuration Export Document

/// 配置导出文档
struct ConfigExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let configManager: ConfigurationManager
    
    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }
    
    init(configuration: ReadConfiguration) throws {
        // 这个初始化器在导入时使用，我们不需要实现
        fatalError("ConfigExportDocument should only be used for export")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = configManager.exportConfiguration() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    SettingsView()
        .preferredColorScheme(.dark)
}