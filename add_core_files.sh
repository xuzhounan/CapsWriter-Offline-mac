#!/bin/bash

# 添加 Sources/Core 目录下的文件到 Xcode 项目
# 这是一个半自动化的解决方案

cd /Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac

echo "开始添加 Sources/Core 文件到 Xcode 项目..."

# 列出需要添加的文件
FILES_TO_ADD=(
    "CapsWriter-mac/Sources/Core/DIContainer.swift"
    "CapsWriter-mac/Sources/Core/ErrorHandler.swift"
    "CapsWriter-mac/Sources/Core/AppEvents.swift"
    "CapsWriter-mac/Sources/Core/EventBus.swift"
    "CapsWriter-mac/Sources/Core/StateManager.swift"
    "CapsWriter-mac/Sources/Core/ErrorHandlerIntegration.swift"
    "CapsWriter-mac/Sources/Core/EventBusAdapter.swift"
)

echo "需要手动添加以下文件到 Xcode 项目:"
for file in "${FILES_TO_ADD[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (文件不存在)"
    fi
done

echo ""
echo "请按照以下步骤操作:"
echo "1. 打开 Xcode 项目: CapsWriter-mac.xcodeproj"
echo "2. 在项目导航器中右键点击项目根目录"
echo "3. 选择 'Add Files to \"CapsWriter-mac\"'"
echo "4. 导航到 CapsWriter-mac/Sources/Core 目录"
echo "5. 选择所有 .swift 文件并添加"
echo "6. 确保选择了正确的 target (CapsWriter-mac)"
echo ""

# 尝试用 xed 命令打开项目（如果可用）
if command -v xed >/dev/null 2>&1; then
    echo "正在打开 Xcode 项目..."
    xed CapsWriter-mac.xcodeproj
else
    echo "请手动打开 Xcode 项目: CapsWriter-mac.xcodeproj"
fi

echo ""
echo "添加文件后，请重新编译项目以验证修复效果。"