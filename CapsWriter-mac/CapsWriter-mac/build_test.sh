#!/bin/bash

echo "🔨 开始构建测试..."

# 设置环境变量
export PROJECT_DIR="$(pwd)"
export SHERPA_LIB_PATH="../../sherpa-onnx/build/lib"
export ONNX_LIB_PATH="../../sherpa-onnx/build/_deps/onnxruntime-src/lib"

echo "📁 项目目录: $PROJECT_DIR"
echo "📚 Sherpa 库路径: $SHERPA_LIB_PATH"
echo "📚 ONNX 库路径: $ONNX_LIB_PATH"

# 检查必要的库文件
echo "🔍 检查库文件..."
if [ ! -f "$SHERPA_LIB_PATH/libsherpa-onnx-c-api.dylib" ]; then
    echo "❌ 找不到 libsherpa-onnx-c-api.dylib"
    exit 1
fi

if [ ! -f "$ONNX_LIB_PATH/libonnxruntime.1.17.1.dylib" ]; then
    echo "❌ 找不到 libonnxruntime.1.17.1.dylib"
    exit 1
fi

echo "✅ 所有库文件存在"

# 检查模型文件
echo "🔍 检查模型文件..."
if [ ! -d "models/paraformer-zh-streaming" ]; then
    echo "❌ 找不到模型目录"
    exit 1
fi

if [ ! -f "models/paraformer-zh-streaming/encoder.onnx" ]; then
    echo "❌ 找不到 encoder.onnx"
    exit 1
fi

if [ ! -f "models/paraformer-zh-streaming/decoder.onnx" ]; then
    echo "❌ 找不到 decoder.onnx"
    exit 1
fi

if [ ! -f "models/paraformer-zh-streaming/tokens.txt" ]; then
    echo "❌ 找不到 tokens.txt"
    exit 1
fi

echo "✅ 所有模型文件存在"

# 检查 Swift 文件语法
echo "🔍 检查 Swift 文件语法..."
for swift_file in *.swift; do
    if [ -f "$swift_file" ]; then
        echo "  检查 $swift_file..."
        if ! swiftc -parse "$swift_file" 2>/dev/null; then
            echo "❌ $swift_file 语法错误"
            exit 1
        fi
    fi
done

echo "✅ 所有 Swift 文件语法正确"

# 检查桥接头文件
echo "🔍 检查桥接头文件..."
if ! clang -fsyntax-only SherpaONNX-Bridging-Header.h 2>/dev/null; then
    echo "❌ 桥接头文件语法错误"
    exit 1
fi

echo "✅ 桥接头文件语法正确"

# 尝试链接测试
echo "🔗 测试库链接..."
cat > test_link.c << 'EOF'
#include "SherpaONNX-Bridging-Header.h"
int main() {
    return 0;
}
EOF

if clang -I. -L"$SHERPA_LIB_PATH" -L"$ONNX_LIB_PATH" -lsherpa-onnx-c-api -lonnxruntime.1.17.1 test_link.c -o test_link 2>/dev/null; then
    echo "✅ 库链接测试成功"
    rm -f test_link test_link.c
else
    echo "❌ 库链接测试失败"
    rm -f test_link test_link.c
    exit 1
fi

echo "🎉 所有构建测试通过！"
echo ""
echo "📋 构建摘要："
echo "  ✅ Swift 文件语法检查通过"
echo "  ✅ 桥接头文件检查通过"
echo "  ✅ 库文件存在且可链接"
echo "  ✅ 模型文件完整"
echo ""
echo "🚀 项目已准备好在 Xcode 中构建！"