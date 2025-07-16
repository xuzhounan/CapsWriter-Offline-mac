#!/bin/bash

# 构建最新版 sherpa-onnx C API for macOS
# 用于 Swift 项目集成

set -e  # 遇到错误立即退出

echo "🚀 开始构建最新版 sherpa-onnx C API..."

# 设置工作目录
WORK_DIR="$(pwd)"
BUILD_DIR="$WORK_DIR/sherpa-onnx-latest"
INSTALL_DIR="$WORK_DIR/sherpa-onnx-install"

# 创建构建目录
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 1. 清理并克隆最新版 sherpa-onnx
echo "📥 下载最新版 sherpa-onnx..."
if [ -d "sherpa-onnx" ]; then
    rm -rf sherpa-onnx
fi

git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx.git
cd sherpa-onnx

# 2. 创建构建目录
mkdir -p build
cd build

# 3. 配置 CMake 构建
echo "⚙️ 配置 CMake 构建..."
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
    -DSHERPA_ONNX_ENABLE_TESTS=OFF \
    -DSHERPA_ONNX_ENABLE_CHECK=OFF \
    -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
    -DSHERPA_ONNX_ENABLE_JNI=OFF \
    -DSHERPA_ONNX_ENABLE_C_API=ON \
    -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
    -DSHERPA_ONNX_ENABLE_GPU=OFF \
    -DSHERPA_ONNX_ENABLE_WASM=OFF \
    -DSHERPA_ONNX_ENABLE_BINARY=OFF \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    ..

# 4. 编译
echo "🔨 开始编译..."
make -j$(sysctl -n hw.ncpu)

# 5. 安装到指定目录
echo "📦 安装库文件..."
make install

# 6. 检查生成的文件
echo "✅ 构建完成！检查生成的文件："
echo ""
echo "📚 动态库文件："
find "$INSTALL_DIR" -name "*.dylib" -type f | head -10

echo ""
echo "📄 头文件："
find "$INSTALL_DIR" -name "*.h" -type f | grep -E "(c-api|sherpa)" | head -10

echo ""
echo "🎯 主要文件位置："
echo "   C API 动态库: $INSTALL_DIR/lib/libsherpa-onnx-c-api.dylib"
echo "   主要头文件: $INSTALL_DIR/include/sherpa-onnx/c-api/c-api.h"
echo "   onnxruntime库: $(find "$BUILD_DIR/sherpa-onnx/build" -name "libonnxruntime*.dylib" | head -1)"

echo ""
echo "🚀 现在可以将这些文件集成到 Xcode 项目中！"
echo ""
echo "📋 下一步操作："
echo "1. 复制 libsherpa-onnx-c-api.dylib 到项目"
echo "2. 复制 c-api.h 头文件到项目"
echo "3. 在 Xcode 中配置 Library Search Paths"
echo "4. 更新 bridging header"