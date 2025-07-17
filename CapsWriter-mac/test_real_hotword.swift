#!/usr/bin/env swift

// 基于真实 HotWordService 实现的测试
import Foundation

print("🔥 测试真实的热词替换系统实现...")

// 模拟真实的 HotWordService 逻辑
class RealHotWordService {
    
    // 优先级定义
    enum HotWordType: String, CaseIterable {
        case chinese = "chinese"
        case english = "english"
        case rule = "rule"
        case runtime = "runtime"
        
        var priority: Int {
            switch self {
            case .rule, .runtime: return 100    // 最高优先级
            case .chinese: return 50            // 中等优先级
            case .english: return 10            // 最低优先级
            }
        }
    }
    
    struct HotWordEntry {
        let original: String
        let replacement: String
        let type: HotWordType
        let priority: Int
        
        init(original: String, replacement: String, type: HotWordType) {
            self.original = original
            self.replacement = replacement
            self.type = type
            self.priority = type.priority
        }
    }
    
    private var hotWordDictionaries: [HotWordType: [String: HotWordEntry]] = [:]
    private var flatDictionary: [String: HotWordEntry] = [:]
    private var regexCache: [String: NSRegularExpression] = [:]
    
    func loadHotWords() {
        // 清空字典
        hotWordDictionaries.removeAll()
        
        // 加载中文热词
        hotWordDictionaries[.chinese] = [
            "人工智能": HotWordEntry(original: "人工智能", replacement: "AI", type: .chinese),
            "机器学习": HotWordEntry(original: "机器学习", replacement: "ML", type: .chinese),
            "深度学习": HotWordEntry(original: "深度学习", replacement: "DL", type: .chinese),
            "自然语言处理": HotWordEntry(original: "自然语言处理", replacement: "NLP", type: .chinese),
            "你好": HotWordEntry(original: "你好", replacement: "Hello", type: .chinese),
            "谢谢": HotWordEntry(original: "谢谢", replacement: "Thank you", type: .chinese)
        ]
        
        // 加载英文热词
        hotWordDictionaries[.english] = [
            "ai": HotWordEntry(original: "ai", replacement: "artificial intelligence", type: .english),
            "ml": HotWordEntry(original: "ml", replacement: "machine learning", type: .english),
            "js": HotWordEntry(original: "js", replacement: "JavaScript", type: .english),
            "css": HotWordEntry(original: "css", replacement: "Cascading Style Sheets", type: .english),
            "teh": HotWordEntry(original: "teh", replacement: "the", type: .english),
            "recieve": HotWordEntry(original: "recieve", replacement: "receive", type: .english)
        ]
        
        // 加载规则热词
        hotWordDictionaries[.rule] = [
            "\\b(ios|IOS)\\b": HotWordEntry(original: "\\b(ios|IOS)\\b", replacement: "iOS", type: .rule),
            "\\b(macos|MacOS|MACOS)\\b": HotWordEntry(original: "\\b(macos|MacOS|MACOS)\\b", replacement: "macOS", type: .rule),
            "\\b(javascript)\\b": HotWordEntry(original: "\\b(javascript)\\b", replacement: "JavaScript", type: .rule),
            "htpp://": HotWordEntry(original: "htpp://", replacement: "http://", type: .rule),
            "，，": HotWordEntry(original: "，，", replacement: "，", type: .rule),
            "。。": HotWordEntry(original: "。。", replacement: "。", type: .rule)
        ]
        
        // 初始化运行时字典
        hotWordDictionaries[.runtime] = [:]
        
        // 重建扁平字典
        rebuildFlatDictionary()
    }
    
    private func rebuildFlatDictionary() {
        var newFlatDictionary: [String: HotWordEntry] = [:]
        
        // 按优先级排序类型
        let sortedTypes = HotWordType.allCases.sorted { $0.priority > $1.priority }
        
        for type in sortedTypes {
            if let dictionary = hotWordDictionaries[type] {
                for (original, entry) in dictionary {
                    // 高优先级覆盖低优先级
                    if newFlatDictionary[original] == nil || entry.priority > newFlatDictionary[original]!.priority {
                        newFlatDictionary[original] = entry
                    }
                }
            }
        }
        
        flatDictionary = newFlatDictionary
    }
    
    func processText(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        var replacementCount = 0
        
        // 1. 先处理正则表达式规则
        if let ruleDict = hotWordDictionaries[.rule] {
            for (pattern, entry) in ruleDict {
                if let regex = getOrCreateRegex(pattern) {
                    let range = NSRange(location: 0, length: result.utf16.count)
                    if regex.firstMatch(in: result, options: [], range: range) != nil {
                        result = regex.stringByReplacingMatches(
                            in: result,
                            options: [],
                            range: range,
                            withTemplate: entry.replacement
                        )
                        replacementCount += 1
                    }
                }
            }
        }
        
        // 2. 处理普通字符串替换（按优先级）
        for (original, entry) in flatDictionary.sorted(by: { $0.value.priority > $1.value.priority }) {
            if entry.type != .rule && result.contains(original) {
                result = result.replacingOccurrences(of: original, with: entry.replacement)
                replacementCount += 1
            }
        }
        
        return result
    }
    
    private func getOrCreateRegex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] {
            return cached
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            regexCache[pattern] = regex
            return regex
        } catch {
            print("❌ 无效正则表达式: \(pattern)")
            return nil
        }
    }
}

// 创建服务实例
let service = RealHotWordService()
service.loadHotWords()

// 测试用例
let testCases = [
    ("人工智能很有趣", "中文热词基本替换"),
    ("我在学习机器学习", "中文术语替换"),
    ("你好世界", "中英文混合"),
    ("I need to learn ai", "英文热词展开"),
    ("js is great", "编程语言缩写"),
    ("I have teh book", "英文纠错（避免冲突）"),
    ("ios app development", "大小写规则"),
    ("macos system", "品牌名称规则"),
    ("htpp://example.com", "URL修正"),
    ("这是一个测试，，", "标点符号清理"),
    ("我用javascript开发ios应用", "多规则组合"),
    ("深度学习用js很方便", "复杂混合替换"),
    ("", "空字符串"),
    ("no replacement needed", "无需替换"),
    ("人工智能人工智能", "重复词汇"),
    ("recieve", "单词纠错"),
    ("I recieve emails", "句子中的词汇纠错"),
    ("javascript and ios", "多个规则应用"),
    ("macos javascript ios", "多个规则组合"),
    ("机器学习ai很有趣", "中英文热词混合")
]

print("\n📊 执行测试用例...")
var totalTests = 0
var passedTests = 0

for (input, description) in testCases {
    let result = service.processText(input)
    totalTests += 1
    
    // 检查是否有变化
    let hasChange = result != input
    
    if input.isEmpty {
        // 空字符串测试
        if result.isEmpty {
            passedTests += 1
            print("✅ \(description): 空字符串处理正确")
        } else {
            print("❌ \(description): 空字符串处理错误")
        }
    } else if input == "no replacement needed" {
        // 无需替换测试
        if result == input {
            passedTests += 1
            print("✅ \(description): 无需替换处理正确")
        } else {
            print("❌ \(description): 无需替换处理错误")
        }
    } else {
        // 其他测试
        if hasChange {
            passedTests += 1
            print("✅ \(description): \"\(input)\" -> \"\(result)\"")
        } else {
            print("⚠️ \(description): 无变化 \"\(input)\"")
        }
    }
}

print("\n📈 测试结果:")
print("  - 总计: \(totalTests)")
print("  - 有效: \(passedTests)")
print("  - 成功率: \(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%")

// 性能测试
print("\n⚡ 性能测试:")
let longText = "人工智能和机器学习是现代技术的重要组成部分，javascript开发者经常使用js来构建ios和macos应用程序。"
let iterations = 1000

let startTime = CFAbsoluteTimeGetCurrent()
for _ in 0..<iterations {
    _ = service.processText(longText)
}
let endTime = CFAbsoluteTimeGetCurrent()

let duration = endTime - startTime
print("  - 处理\(iterations)次耗时: \(String(format: "%.3f", duration))秒")
print("  - 平均每次: \(String(format: "%.6f", duration / Double(iterations)))秒")
print("  - 每秒处理: \(String(format: "%.0f", Double(iterations) / duration))次")

// 优先级测试
print("\n🏆 优先级测试:")
let priorityTests = [
    ("ios", "规则vs英文热词"),
    ("javascript", "规则vs英文热词"),
    ("ai", "中文vs英文热词"),
]

for (input, description) in priorityTests {
    let result = service.processText(input)
    print("  - \(description): \"\(input)\" -> \"\(result)\"")
}

print("\n✅ 真实热词替换系统测试完成")