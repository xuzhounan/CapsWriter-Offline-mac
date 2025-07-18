import SwiftUI

// MARK: - Settings Components

/// 设置区块容器
struct SettingsSection<Content: View>: View {
    let title: String
    let description: String?
    let content: Content
    
    init(title: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 区块标题
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
        }
    }
}

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
                .onChange(of: text) { newValue in
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
            
            Button(action: action) {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                    }
                    
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(swiftUIButtonStyle)
        }
    }
    
    private var swiftUIButtonStyle: some SwiftUI.ButtonStyle {
        switch style {
        case .primary:
            return AnyButtonStyle(.borderedProminent)
        case .secondary:
            return AnyButtonStyle(.bordered)
        case .destructive:
            return AnyButtonStyle(DestructiveButtonStyle())
        case .bordered:
            return AnyButtonStyle(.bordered)
        }
    }
}

/// 破坏性按钮样式
struct DestructiveButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.red)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.red.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red, lineWidth: 1)
                    )
            )
    }
}

/// 类型擦除的按钮样式
struct AnyButtonStyle: SwiftUI.ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: SwiftUI.ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
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

#Preview("Settings Section") {
    SettingsSection(
        title: "测试区块",
        description: "这是一个测试设置区块，展示了各种设置组件"
    ) {
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