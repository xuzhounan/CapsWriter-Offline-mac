#!/bin/bash

echo "🔍 CapsWriter-mac 项目完整性验证"
echo "================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅${NC} $1"
        return 0
    else
        echo -e "${RED}❌${NC} $1"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✅${NC} $1"
        return 0
    else
        echo -e "${RED}❌${NC} $1"
        return 1
    fi
}

# 初始化计数器
total_checks=0
passed_checks=0

# 1. 检查源文件
echo "📁 检查源文件..."
echo "----------------"

files_to_check=(
    "CapsWriterApp.swift"
    "AppDelegate.swift"
    "ContentView.swift"
    "StatusBarController.swift"
    "KeyboardMonitor.swift"
    "RecordingState.swift"
    "SherpaASRService.swift"
    "SherpaONNX-Bridging-Header.h"
    "sherpa-onnx-types.h"
)

for file in "${files_to_check[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""

# 2. 检查库文件
echo "📚 检查库文件..."
echo "----------------"

lib_files=(
    "../../sherpa-onnx/build/lib/libsherpa-onnx-c-api.dylib"
    "../../sherpa-onnx/build/_deps/onnxruntime-src/lib/libonnxruntime.1.17.1.dylib"
)

for lib in "${lib_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$lib"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""

# 3. 检查模型文件
echo "🧠 检查模型文件..."
echo "----------------"

total_checks=$((total_checks + 1))
if check_dir "models/paraformer-zh-streaming"; then
    passed_checks=$((passed_checks + 1))
fi

model_files=(
    "models/paraformer-zh-streaming/encoder.onnx"
    "models/paraformer-zh-streaming/decoder.onnx"
    "models/paraformer-zh-streaming/tokens.txt"
)

for model in "${model_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$model"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""

# 4. 检查项目配置文件
echo "⚙️ 检查项目配置..."
echo "----------------"

config_files=(
    "../CapsWriter-mac.xcodeproj/project.pbxproj"
    "Info.plist"
    "CapsWriter-mac.entitlements"
)

for config in "${config_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$config"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""

# 5. 语法检查
echo "🔍 进行语法检查..."
echo "----------------"

syntax_error=0

echo "  检查 Swift 文件语法..."
for swift_file in *.swift; do
    if [ -f "$swift_file" ]; then
        total_checks=$((total_checks + 1))
        if swiftc -parse "$swift_file" 2>/dev/null; then
            echo -e "    ${GREEN}✅${NC} $swift_file"
            passed_checks=$((passed_checks + 1))
        else
            echo -e "    ${RED}❌${NC} $swift_file"
            syntax_error=1
        fi
    fi
done

echo "  检查桥接头文件语法..."
total_checks=$((total_checks + 1))
if clang -fsyntax-only SherpaONNX-Bridging-Header.h 2>/dev/null; then
    echo -e "    ${GREEN}✅${NC} SherpaONNX-Bridging-Header.h"
    passed_checks=$((passed_checks + 1))
else
    echo -e "    ${RED}❌${NC} SherpaONNX-Bridging-Header.h"
    syntax_error=1
fi

echo ""

# 6. 链接测试
echo "🔗 进行链接测试..."
echo "----------------"

total_checks=$((total_checks + 1))

cat > test_link.c << 'EOF'
#include "SherpaONNX-Bridging-Header.h"
int main() {
    return 0;
}
EOF

if clang -I. -L../../sherpa-onnx/build/lib -L../../sherpa-onnx/build/_deps/onnxruntime-src/lib -lsherpa-onnx-c-api -lonnxruntime.1.17.1 test_link.c -o test_link 2>/dev/null; then
    echo -e "${GREEN}✅${NC} 库链接测试通过"
    passed_checks=$((passed_checks + 1))
    rm -f test_link
else
    echo -e "${RED}❌${NC} 库链接测试失败"
fi

rm -f test_link.c

echo ""

# 7. 结果汇总
echo "📊 验证结果"
echo "=========="

echo "通过检查: $passed_checks / $total_checks"

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 所有检查都通过了！${NC}"
    echo ""
    echo -e "${GREEN}✨ 项目状态：准备就绪${NC}"
    echo ""
    echo "📋 构建准备清单："
    echo "  ✅ 所有源文件存在且语法正确"
    echo "  ✅ 所有库文件存在且可链接"
    echo "  ✅ 语音识别模型文件完整"
    echo "  ✅ 项目配置文件完整"
    echo "  ✅ 桥接头文件配置正确"
    echo ""
    echo -e "${GREEN}🚀 现在可以在 Xcode 中打开并构建项目了！${NC}"
    echo ""
    echo "📝 构建步骤："
    echo "  1. 在 Xcode 中打开 CapsWriter-mac.xcodeproj"
    echo "  2. 选择目标设备 (Mac)"
    echo "  3. 点击 Build 或按 Cmd+B"
    echo "  4. 如有问题，检查 Build Settings 中的库搜索路径"
    exit 0
else
    echo -e "${RED}❌ 有 $((total_checks - passed_checks)) 个检查失败${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  项目状态：需要修复${NC}"
    echo ""
    echo "请检查上述失败的项目并修复后重新运行此脚本。"
    exit 1
fi