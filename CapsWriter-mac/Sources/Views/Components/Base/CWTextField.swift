import SwiftUI

// MARK: - CapsWriter 文本输入框组件
struct CWTextField: View {
    let title: String?
    let placeholder: String
    let icon: String?
    let style: CWTextFieldStyle
    let validation: CWTextFieldValidation?
    
    @Binding var text: String
    @State private var isValid: Bool = true
    @State private var isFocused: Bool = false
    @State private var validationMessage: String = ""
    
    init(
        title: String? = nil,
        placeholder: String = "",
        icon: String? = nil,
        style: CWTextFieldStyle = .default,
        text: Binding<String>,
        validation: CWTextFieldValidation? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self.icon = icon
        self.style = style
        self._text = text
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
            // 标题
            if let title = title {
                Text(title)
                    .font(CWTheme.fonts.subheadline)
                    .foregroundColor(CWTheme.colors.primaryText)
                    .fontWeight(.medium)
            }
            
            // 输入框主体
            HStack(spacing: CWTheme.spacing.s) {
                // 左侧图标
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                // 文本输入框
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(CWTheme.fonts.body)
                    .foregroundColor(CWTheme.colors.primaryText)
                    .onFocusChange { focused in
                        isFocused = focused
                        if !focused {
                            validateText()
                        }
                    }
                
                // 右侧状态图标
                if validation != nil {
                    Image(systemName: validationIcon)
                        .font(.system(size: 14))
                        .foregroundColor(validationColor)
                        .opacity(text.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                }
            }
            .padding(.horizontal, CWTheme.spacing.m)
            .padding(.vertical, CWTheme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                            .stroke(effectiveBorderColor, lineWidth: style.borderWidth)
                    )
            )
            
            // 验证消息
            if !isValid && !validationMessage.isEmpty {
                HStack(spacing: CWTheme.spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(CWTheme.colors.error)
                    
                    Text(validationMessage)
                        .font(CWTheme.fonts.caption)
                        .foregroundColor(CWTheme.colors.error)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isValid)
            }
        }
        .onChange(of: text) { _ in
            if validation != nil {
                validateText()
            }
        }
    }
    
    // MARK: - 验证逻辑
    private func validateText() {
        guard let validation = validation else {
            isValid = true
            validationMessage = ""
            return
        }
        
        let result = validation.validate(text)
        isValid = result.isValid
        validationMessage = result.message
    }
    
    // MARK: - 计算属性
    private var effectiveBorderColor: Color {
        if !isValid {
            return CWTheme.colors.error
        } else if isFocused {
            return CWTheme.colors.focusBorder
        } else {
            return style.borderColor
        }
    }
    
    private var iconColor: Color {
        if !isValid {
            return CWTheme.colors.error
        } else if isFocused {
            return CWTheme.colors.primary
        } else {
            return CWTheme.colors.secondaryText
        }
    }
    
    private var validationIcon: String {
        return isValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var validationColor: Color {
        return isValid ? CWTheme.colors.success : CWTheme.colors.error
    }
}

// MARK: - 文本输入框样式枚举
enum CWTextFieldStyle {
    case `default`
    case outlined
    case filled
    case minimal
    
    var backgroundColor: Color {
        switch self {
        case .default: return CWTheme.colors.textBackground
        case .outlined: return Color.clear
        case .filled: return CWTheme.colors.cardBackground
        case .minimal: return Color.clear
        }
    }
    
    var borderColor: Color {
        switch self {
        case .default: return CWTheme.colors.border
        case .outlined: return CWTheme.colors.border
        case .filled: return Color.clear
        case .minimal: return Color.clear
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .default: return 1
        case .outlined: return 1.5
        case .filled: return 0
        case .minimal: return 0
        }
    }
}

// MARK: - 验证规则
struct CWTextFieldValidation {
    let rules: [ValidationRule]
    
    func validate(_ text: String) -> ValidationResult {
        for rule in rules {
            let result = rule.validate(text)
            if !result.isValid {
                return result
            }
        }
        return ValidationResult(isValid: true, message: "")
    }
}

// MARK: - 验证结果
struct ValidationResult {
    let isValid: Bool
    let message: String
}

// MARK: - 验证规则协议
protocol ValidationRule {
    func validate(_ text: String) -> ValidationResult
}

// MARK: - 常用验证规则
struct RequiredRule: ValidationRule {
    let message: String
    
    init(message: String = "此字段为必填项") {
        self.message = message
    }
    
    func validate(_ text: String) -> ValidationResult {
        let isValid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ValidationResult(isValid: isValid, message: isValid ? "" : message)
    }
}

struct MinLengthRule: ValidationRule {
    let minLength: Int
    let message: String
    
    init(minLength: Int, message: String? = nil) {
        self.minLength = minLength
        self.message = message ?? "至少需要 \(minLength) 个字符"
    }
    
    func validate(_ text: String) -> ValidationResult {
        let isValid = text.count >= minLength
        return ValidationResult(isValid: isValid, message: isValid ? "" : message)
    }
}

struct MaxLengthRule: ValidationRule {
    let maxLength: Int
    let message: String
    
    init(maxLength: Int, message: String? = nil) {
        self.maxLength = maxLength
        self.message = message ?? "最多只能输入 \(maxLength) 个字符"
    }
    
    func validate(_ text: String) -> ValidationResult {
        let isValid = text.count <= maxLength
        return ValidationResult(isValid: isValid, message: isValid ? "" : message)
    }
}

struct EmailRule: ValidationRule {
    let message: String
    
    init(message: String = "请输入有效的邮箱地址") {
        self.message = message
    }
    
    func validate(_ text: String) -> ValidationResult {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let isValid = text.range(of: emailRegex, options: .regularExpression) != nil
        return ValidationResult(isValid: isValid, message: isValid ? "" : message)
    }
}

// MARK: - 多行文本输入框
struct CWTextEditor: View {
    let title: String?
    let placeholder: String
    let style: CWTextFieldStyle
    let minHeight: CGFloat
    
    @Binding var text: String
    @State private var isFocused: Bool = false
    
    init(
        title: String? = nil,
        placeholder: String = "",
        style: CWTextFieldStyle = .default,
        minHeight: CGFloat = 100,
        text: Binding<String>
    ) {
        self.title = title
        self.placeholder = placeholder
        self.style = style
        self.minHeight = minHeight
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CWTheme.spacing.xs) {
            // 标题
            if let title = title {
                Text(title)
                    .font(CWTheme.fonts.subheadline)
                    .foregroundColor(CWTheme.colors.primaryText)
                    .fontWeight(.medium)
            }
            
            // 文本编辑器
            ZStack(alignment: .topLeading) {
                // 占位符
                if text.isEmpty {
                    Text(placeholder)
                        .font(CWTheme.fonts.body)
                        .foregroundColor(CWTheme.colors.tertiaryText)
                        .padding(.horizontal, CWTheme.spacing.m)
                        .padding(.vertical, CWTheme.spacing.s)
                        .allowsHitTesting(false)
                }
                
                // 实际文本编辑器
                TextEditor(text: $text)
                    .font(CWTheme.fonts.body)
                    .foregroundColor(CWTheme.colors.primaryText)
                    .padding(.horizontal, CWTheme.spacing.m)
                    .padding(.vertical, CWTheme.spacing.s)
                    .background(Color.clear)
                    .onFocusChange { focused in
                        isFocused = focused
                    }
            }
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CWTheme.cornerRadius.s)
                            .stroke(
                                isFocused ? CWTheme.colors.focusBorder : style.borderColor,
                                lineWidth: style.borderWidth
                            )
                    )
            )
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        CWTextField(
            title: "用户名",
            placeholder: "请输入用户名",
            icon: "person.fill",
            text: .constant(""),
            validation: CWTextFieldValidation(rules: [
                RequiredRule(),
                MinLengthRule(minLength: 3)
            ])
        )
        
        CWTextField(
            title: "邮箱",
            placeholder: "请输入邮箱地址",
            icon: "envelope.fill",
            style: .outlined,
            text: .constant(""),
            validation: CWTextFieldValidation(rules: [
                RequiredRule(),
                EmailRule()
            ])
        )
        
        CWTextEditor(
            title: "备注",
            placeholder: "请输入备注信息...",
            text: .constant("")
        )
    }
    .padding()
    .background(CWTheme.colors.background)
}