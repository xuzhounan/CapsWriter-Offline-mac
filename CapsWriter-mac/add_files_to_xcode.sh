#!/bin/bash

# 添加状态管理文件到 Xcode 项目的脚本

set -e

PROJECT_DIR="/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac"
PROJECT_FILE="$PROJECT_DIR/CapsWriter-mac.xcodeproj"
TARGET_NAME="CapsWriter-mac"

echo "正在添加状态管理文件到 Xcode 项目..."

# 文件路径
FILES=(
    "CapsWriter-mac/AudioState.swift"
    "CapsWriter-mac/RecognitionState.swift"
    "CapsWriter-mac/AppState.swift"
)

# 检查文件是否存在
for file in "${FILES[@]}"; do
    if [ ! -f "$PROJECT_DIR/$file" ]; then
        echo "错误: 文件 $file 不存在"
        exit 1
    fi
done

# 使用 ruby 脚本添加文件到 Xcode 项目
cat > "$PROJECT_DIR/add_files.rb" << 'EOF'
require 'xcodeproj'

project_path = ARGV[0]
target_name = ARGV[1]
files = ARGV[2..-1]

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }

if target.nil?
    puts "错误: 找不到目标 #{target_name}"
    exit 1
end

# 创建 States 组
states_group = project.main_group.find_subpath('States', true)
states_group.set_source_tree('SOURCE_ROOT')

files.each do |file_path|
    # 添加文件引用
    file_ref = states_group.new_reference(file_path)
    file_ref.set_source_tree('SOURCE_ROOT')
    
    # 添加到构建阶段
    target.source_build_phase.add_file_reference(file_ref)
    
    puts "已添加: #{file_path}"
end

project.save
puts "项目保存成功"
EOF

# 检查是否安装了 xcodeproj gem
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo "正在安装 xcodeproj gem..."
    gem install xcodeproj
fi

# 运行 ruby 脚本
cd "$PROJECT_DIR"
ruby add_files.rb "$PROJECT_FILE" "$TARGET_NAME" "${FILES[@]}"

# 清理临时文件
rm -f add_files.rb

echo "完成！请在 Xcode 中重新打开项目以查看更改。"