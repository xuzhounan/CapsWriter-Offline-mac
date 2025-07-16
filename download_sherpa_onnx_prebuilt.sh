#!/bin/bash

# 下载预编译的 sherpa-onnx C API for macOS
# 用于 Swift 项目集成

set -e  # 遇到错误立即退出

echo "🚀 下载预编译的 sherpa-onnx C API..."

# 设置工作目录
WORK_DIR="$(pwd)"
DOWNLOAD_DIR="$WORK_DIR/sherpa-onnx-prebuilt"

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# 获取最新版本号
echo "📡 获取最新版本信息..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/k2-fsa/sherpa-onnx/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
echo "最新版本: $LATEST_VERSION"

# 下载 macOS 版本
MACOS_FILENAME="sherpa-onnx-${LATEST_VERSION}-osx-universal2-static.tar.bz2"
DOWNLOAD_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${LATEST_VERSION}/${MACOS_FILENAME}"

echo "📥 下载 $MACOS_FILENAME..."
curl -L -o "$MACOS_FILENAME" "$DOWNLOAD_URL"

echo "📦 解压文件..."
tar -xjf "$MACOS_FILENAME"

# 查找解压后的目录
EXTRACTED_DIR=$(find . -name "sherpa-onnx-*" -type d | head -1)
echo "解压目录: $EXTRACTED_DIR"

# 检查文件结构
echo ""
echo "✅ 文件结构："
if [ -d "$EXTRACTED_DIR" ]; then
    echo "📚 库文件:"
    find "$EXTRACTED_DIR" -name "*.dylib" -o -name "*.a" | head -5
    
    echo ""
    echo "📄 头文件:"
    find "$EXTRACTED_DIR" -name "*.h" | grep -E "(c-api|sherpa)" | head -5
    
    echo ""
    echo "🎯 主要文件位置："
    
    # 查找 C API 库
    C_API_LIB=$(find "$EXTRACTED_DIR" -name "*sherpa-onnx-c-api*" | head -1)
    if [ -n "$C_API_LIB" ]; then
        echo "   C API 库: $C_API_LIB"
    fi
    
    # 查找头文件
    C_API_HEADER=$(find "$EXTRACTED_DIR" -name "c-api.h" | head -1)
    if [ -n "$C_API_HEADER" ]; then
        echo "   C API 头文件: $C_API_HEADER"
    fi
    
    # 查找 onnxruntime
    ONNX_LIB=$(find "$EXTRACTED_DIR" -name "*onnxruntime*" | head -1)
    if [ -n "$ONNX_LIB" ]; then
        echo "   ONNX Runtime: $ONNX_LIB"
    fi
    
    echo ""
    echo "📋 接下来的操作："
    echo "1. 复制库文件到 Xcode 项目"
    echo "2. 复制头文件到项目"
    echo "3. 更新 Xcode 配置"
else
    echo "❌ 解压失败或目录结构异常"
fi

echo ""
echo "🚀 下载完成！文件位于: $DOWNLOAD_DIR/$EXTRACTED_DIR"