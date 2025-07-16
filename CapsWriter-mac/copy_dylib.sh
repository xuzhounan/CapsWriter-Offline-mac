#\!/bin/bash

# 创建 Frameworks 目录
mkdir -p "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

# 复制动态库
cp "${SRCROOT}/CapsWriter-mac/Frameworks/libsherpa-onnx-c-api.dylib" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/"

echo "Copied libsherpa-onnx-c-api.dylib to Frameworks"
