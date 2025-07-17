#!/usr/bin/env swift

import Foundation

// 模拟测试标点符号处理功能
// 这个测试脚本验证标点符号处理的各种场景

print("🔤 开始测试标点符号处理功能...")

// 测试用例数据
let testCases = [
    // 基本句子测试
    ("今天天气很好", "今天天气很好。"),
    ("你好吗", "你好吗？"),
    ("太棒了", "太棒了！"),
    ("首先我们需要准备材料然后开始制作", "首先我们需要准备材料，然后开始制作。"),
    
    // 疑问句测试
    ("你知道这个问题的答案吗", "你知道这个问题的答案吗？"),
    ("什么时候开始", "什么时候开始？"),
    ("哪里可以买到", "哪里可以买到？"),
    ("为什么会这样", "为什么会这样？"),
    
    // 感叹句测试
    ("太好了", "太好了！"),
    ("真是太棒了", "真是太棒了！"),
    ("哇这个很厉害", "哇这个很厉害！"),
    
    // 复杂句子测试
    ("总之我们完成了这个项目", "总之我们完成了这个项目。"),
    ("因此我认为这样做是对的", "因此我认为这样做是对的。"),
    ("另外我想说明一个问题", "另外我想说明一个问题。"),
    
    // 已有标点符号的文本（应该跳过处理）
    ("这是一个已经有标点的句子。", "这是一个已经有标点的句子。"),
    ("你好吗？", "你好吗？"),
    ("太好了！", "太好了！"),
    
    // 空文本和特殊情况
    ("", ""),
    ("   ", ""),
    ("一", "一。")
]

// 模拟标点符号处理逻辑
func simulatePunctuationProcessing(_ text: String) -> String {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 空文本直接返回
    guard !trimmedText.isEmpty else {
        return ""
    }
    
    // 检查是否已有标点符号
    let chinesePunctuation = CharacterSet(charactersIn: "。，！？；：、\"\"''（）【】《》")
    if trimmedText.rangeOfCharacter(from: chinesePunctuation) != nil {
        return text  // 已有标点符号，跳过处理
    }
    
    var result = trimmedText
    
    // 疑问句标记词汇
    let questionMarkers = ["吗", "呢", "吧", "什么", "哪里", "为什么", "怎么", "怎样", "多少", "几", "谁", "哪个", "哪些", "是否", "可否", "能否"]
    
    // 感叹句标记词汇
    let exclamationMarkers = ["太", "真", "好", "糟", "哇", "哎", "唉", "咦", "哈哈", "呵呵", "太棒了", "太好了", "太糟了", "真是", "简直", "居然"]
    
    // 停顿标记词汇（需要逗号）
    let pauseMarkers = ["然后", "接着", "然而", "但是", "不过", "可是", "另外", "此外", "首先", "其次", "最后", "同时", "另一方面", "一方面"]
    
    // 句子结束标记词汇
    let sentenceEndMarkers = ["了", "的", "吧", "呢", "啊", "哦", "嗯", "好", "总之", "因此", "所以", "总的来说", "综上所述", "完成", "结束", "完毕", "好了", "行了"]
    
    // 1. 添加逗号（在停顿词后）
    for marker in pauseMarkers {
        if let range = result.range(of: marker) {
            let nextCharIndex = result.index(after: range.upperBound)
            if nextCharIndex < result.endIndex {
                let nextChar = result[nextCharIndex]
                // 如果后面不是标点符号或空格，添加逗号
                if !nextChar.isPunctuation && nextChar != " " {
                    result.insert("，", at: nextCharIndex)
                }
            }
        }
    }
    
    // 2. 处理句子结尾
    let shouldAddQuestionMark = questionMarkers.contains { marker in
        result.contains(marker)
    }
    
    let shouldAddExclamationMark = exclamationMarkers.contains { marker in
        result.contains(marker)
    }
    
    let shouldAddPeriod = sentenceEndMarkers.contains { marker in
        result.hasSuffix(marker)
    } || result.count > 10
    
    if shouldAddQuestionMark {
        result.append("？")
    } else if shouldAddExclamationMark {
        result.append("！")
    } else if shouldAddPeriod {
        result.append("。")
    }
    
    return result
}

// 运行测试
var passedTests = 0
var totalTests = testCases.count

print("\n📋 开始执行测试用例...")

for (index, testCase) in testCases.enumerated() {
    let (input, expected) = testCase
    let actual = simulatePunctuationProcessing(input)
    let passed = actual == expected
    
    if passed {
        passedTests += 1
        print("✅ 测试 \(index + 1): PASS")
    } else {
        print("❌ 测试 \(index + 1): FAIL")
        print("   输入: \"\(input)\"")
        print("   期望: \"\(expected)\"")
        print("   实际: \"\(actual)\"")
    }
}

// 输出测试结果
print("\n📊 测试结果统计:")
print("   总测试数: \(totalTests)")
print("   通过数: \(passedTests)")
print("   失败数: \(totalTests - passedTests)")
print("   通过率: \(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%")

if passedTests == totalTests {
    print("\n🎉 所有测试通过！标点符号处理功能工作正常。")
} else {
    print("\n⚠️  部分测试失败，需要调整标点符号处理逻辑。")
}

// 扩展字符类型检查
extension Character {
    var isPunctuation: Bool {
        let chinesePunctuation = CharacterSet(charactersIn: "。，！？；：、\"\"''（）【】《》")
        return String(self).rangeOfCharacter(from: chinesePunctuation) != nil ||
               String(self).rangeOfCharacter(from: .punctuationCharacters) != nil
    }
}

print("\n🔤 标点符号处理功能测试完成！")