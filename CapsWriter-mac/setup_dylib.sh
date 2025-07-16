#\!/bin/bash

# 这个脚本将在构建时自动复制动态库到应用包中

FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"
SOURCE_DYLIB="${SRCROOT}/CapsWriter-mac/Frameworks/libsherpa-onnx-c-api.dylib"

echo "Setting up dynamic library..."
echo "Source: ${SOURCE_DYLIB}"
echo "Destination: ${FRAMEWORKS_DIR}"

# 创建 Frameworks 目录
mkdir -p "${FRAMEWORKS_DIR}"

# 复制动态库
if [ -f "${SOURCE_DYLIB}" ]; then
    cp "${SOURCE_DYLIB}" "${FRAMEWORKS_DIR}/"
    echo "Successfully copied libsherpa-onnx-c-api.dylib"
else
    echo "Error: Source dylib not found at ${SOURCE_DYLIB}"
    exit 1
fi

# 检查库是否正确复制
if [ -f "${FRAMEWORKS_DIR}/libsherpa-onnx-c-api.dylib" ]; then
    echo "Dynamic library setup complete"
else
    echo "Error: Failed to copy dynamic library"
    exit 1
fi
