import SwiftUI

// MARK: - Settings Components

/// 设置开关组件
struct SettingsToggle: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    
    init(title: String, description: String? = nil, isOn: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self.description = description
        self._isOn = isOn
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
        }
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

/// 设置选择器组件
struct SettingsPicker<T: Hashable, Content: View>: View {
    let title: String
    let description: String?
    @Binding var selection: T
    let options: [T]
    let content: (T) -> Content
    
    init(
        title: String,
        description: String? = nil,
        selection: Binding<T>,
        options: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.title = title
        self.description = description
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    content(option).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 设置滑块组件
struct SettingsSlider: View {
    let title: String
    let description: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: NumberFormatter?
    
    init(
        title: String,
        description: String? = nil,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 0.1,
        formatter: NumberFormatter? = nil
    ) {
        self.title = title
        self.description = description
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                Text(formattedValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range, step: step)
        }
    }
    
    private var formattedValue: String {
        if let formatter = formatter {
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

/// 设置文本输入组件
struct SettingsTextField: View {
    let title: String
    let description: String?
    let placeholder: String
    @Binding var text: String
    var validation: ((String) -> Bool)?
    
    @State private var isValid = true
    
    init(
        title: String,
        description: String? = nil,
        placeholder: String = "",
        text: Binding<String>,
        validation: ((String) -> Bool)? = nil
    ) {
        self.title = title
        self.description = description
        self.placeholder = placeholder
        self._text = text
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                )
                .onChange(of: text) { _, newValue in
                    validateText(newValue)
                }
            
            if !isValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    Text("输入格式不正确")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func validateText(_ text: String) {
        if let validation = validation {
            isValid = validation(text)
        }
    }
}

/// 设置按钮组件
struct SettingsButton: View {
    let title: String
    let description: String?
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case bordered
    }
    
    init(
        title: String,
        description: String? = nil,
        icon: String? = nil,
        style: ButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            styledButton {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                    }
                    
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
            }
        }
    }
    
    @ViewBuilder
    private func styledButton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch style {
        case .primary, .bordered:
            Button(action: action) {
                content()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
            
        case .secondary:
            Button(action: action) {
                content()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
        case .destructive:
            Button(action: action) {
                content()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
    }
}

/// 信息卡片组件
struct InfoCard: View {
    let title: String
    let description: String
    let icon: String
    let backgroundColor: Color
    
    init(
        title: String,
        description: String,
        icon: String = "info.circle",
        backgroundColor: Color = .blue
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(backgroundColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
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
                .fill(backgroundColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(backgroundColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// 警告卡片组件
struct WarningCard: View {
    let title: String
    let description: String
    
    var body: some View {
        InfoCard(
            title: title,
            description: description,
            icon: "exclamationmark.triangle",
            backgroundColor: .orange
        )
    }
}

/// 错误卡片组件
struct ErrorCard: View {
    let title: String
    let description: String
    
    var body: some View {
        InfoCard(
            title: title,
            description: description,
            icon: "xmark.circle",
            backgroundColor: .red
        )
    }
}

/// 成功卡片组件
struct SuccessCard: View {
    let title: String
    let description: String
    
    var body: some View {
        InfoCard(
            title: title,
            description: description,
            icon: "checkmark.circle",
            backgroundColor: .green
        )
    }
}

// MARK: - Preview

#Preview("Settings Toggle") {
    VStack(spacing: 20) {
        SettingsToggle(
            title: "启用功能",
            description: "这是一个测试开关，用于演示设置组件的样式",
            isOn: .constant(true)
        )
        
        SettingsToggle(
            title: "禁用的功能",
            description: "这是一个禁用的开关示例",
            isOn: .constant(false),
            isEnabled: false
        )
    }
    .padding()
    .frame(width: 400)
}

// MARK: - Configuration Validation Components

/// 配置验证组件 - 用于实时验证配置项
struct ConfigurationValidator: View {
    let title: String
    let configurationName: String
    let validationResult: ConfigurationValidationResult
    let onRevalidate: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button("重新验证") {
                    onRevalidate?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ValidateResultRow(result: validationResult)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(validationResult.borderColor, lineWidth: 1)
                )
        )
    }
}

/// 验证结果行
struct ValidateResultRow: View {
    let result: ConfigurationValidationResult
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.icon)
                .font(.system(size: 14))
                .foregroundColor(result.iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(result.textColor)
                
                if let suggestion = result.suggestion {
                    Text(suggestion)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if result.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
}

/// 配置验证结果
struct ConfigurationValidationResult {
    let isValid: Bool
    let message: String
    let suggestion: String?
    let isLoading: Bool
    
    init(
        isValid: Bool, 
        message: String, 
        suggestion: String? = nil, 
        isLoading: Bool = false
    ) {
        self.isValid = isValid
        self.message = message
        self.suggestion = suggestion
        self.isLoading = isLoading
    }
    
    var icon: String {
        if isLoading { return "clock.circle" }
        return isValid ? "checkmark.circle" : "xmark.circle"
    }
    
    var iconColor: Color {
        if isLoading { return .blue }
        return isValid ? .green : .red
    }
    
    var textColor: Color {
        return isValid ? .primary : .red
    }
    
    var borderColor: Color {
        if isLoading { return .blue.opacity(0.3) }
        return isValid ? .green.opacity(0.3) : .red.opacity(0.3)
    }
    
    // 预设的验证结果
    static let validating = ConfigurationValidationResult(
        isValid: true, 
        message: "正在验证配置...", 
        isLoading: true
    )
    
    static let valid = ConfigurationValidationResult(
        isValid: true, 
        message: "配置有效"
    )
    
    static func invalid(_ message: String, suggestion: String? = nil) -> ConfigurationValidationResult {
        ConfigurationValidationResult(
            isValid: false, 
            message: message, 
            suggestion: suggestion
        )
    }
}

/// 批量配置验证器
struct BatchConfigurationValidator: View {
    let title: String
    let validationResults: [String: ConfigurationValidationResult]  // 配置名 -> 验证结果
    let onRevalidateAll: (() -> Void)?
    
    var overallStatus: ConfigurationValidationResult {
        let results = Array(validationResults.values)
        
        if results.isEmpty {
            return .invalid("没有找到配置项")
        }
        
        if results.contains(where: { $0.isLoading }) {
            return .validating
        }
        
        let invalidResults = results.filter { !$0.isValid }
        if invalidResults.isEmpty {
            return .valid
        } else {
            return .invalid(
                "\(invalidResults.count) 个配置项无效",
                suggestion: "请检查并修复无效的配置项"
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总体状态
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("配置验证状态")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("全部重新验证") {
                    onRevalidateAll?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ValidateResultRow(result: overallStatus)
            
            if !validationResults.isEmpty {
                Divider()
                
                // 详细结果
                VStack(alignment: .leading, spacing: 8) {
                    Text("详细验证结果")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(validationResults.keys.sorted()), id: \.self) { configName in
                            if let result = validationResults[configName] {
                                HStack {
                                    Text(configName)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: 120, alignment: .leading)
                                    
                                    ValidateResultRow(result: result)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(overallStatus.borderColor, lineWidth: 1.5)
                )
        )
    }
}

#Preview("Settings Section") {
    SettingsSection(title: "测试区块") {
        VStack(spacing: 16) {
            SettingsToggle(
                title: "开关设置",
                description: "测试开关功能",
                isOn: .constant(true)
            )
            
            Divider()
            
            SettingsSlider(
                title: "滑块设置",
                description: "测试滑块功能",
                value: .constant(0.5),
                in: 0...1
            )
        }
    }
    .padding()
    .frame(width: 500)
}

