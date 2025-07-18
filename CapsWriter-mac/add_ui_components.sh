#!/bin/bash

# 添加 UI 组件到 Xcode 项目的脚本

set -e

PROJECT_DIR="/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac"
PROJECT_FILE="$PROJECT_DIR/CapsWriter-mac.xcodeproj"
TARGET_NAME="CapsWriter-mac"

echo "正在添加 UI 组件到 Xcode 项目..."

# UI 组件文件路径
UI_FILES=(
    "Sources/Views/Theme/CWTheme.swift"
    "Sources/Views/Components/Base/CWButton.swift"
    "Sources/Views/Components/Base/CWCard.swift"
    "Sources/Views/Components/Base/CWProgressBar.swift"
    "Sources/Views/Components/Base/CWTextField.swift"
    "Sources/Views/Components/Base/CWLabel.swift"
    "Sources/Views/Components/Composite/RecordingPanel.swift"
    "Sources/Views/Components/Composite/StatusCard.swift"
    "Sources/Views/Components/Indicators/RecordingIndicator.swift"
    "Sources/Views/Enhanced/Animations/BreathingAnimation.swift"
    "Sources/Views/Enhanced/Visualizers/AudioWaveform.swift"
)

# 检查文件是否存在
for file in "${UI_FILES[@]}"; do
    if [ ! -f "$PROJECT_DIR/$file" ]; then
        echo "错误: 文件 $file 不存在"
        exit 1
    fi
done

# 使用 ruby 脚本添加文件到 Xcode 项目
cat > "$PROJECT_DIR/add_ui_files.rb" << 'EOF'
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

# 创建 Views 组结构
views_group = project.main_group.find_subpath('Views', true)
views_group.set_source_tree('SOURCE_ROOT')

# 创建子组
theme_group = views_group.find_subpath('Theme', true)
theme_group.set_source_tree('SOURCE_ROOT')

components_group = views_group.find_subpath('Components', true)
components_group.set_source_tree('SOURCE_ROOT')

base_group = components_group.find_subpath('Base', true)
base_group.set_source_tree('SOURCE_ROOT')

composite_group = components_group.find_subpath('Composite', true)
composite_group.set_source_tree('SOURCE_ROOT')

indicators_group = components_group.find_subpath('Indicators', true)
indicators_group.set_source_tree('SOURCE_ROOT')

enhanced_group = views_group.find_subpath('Enhanced', true)
enhanced_group.set_source_tree('SOURCE_ROOT')

animations_group = enhanced_group.find_subpath('Animations', true)
animations_group.set_source_tree('SOURCE_ROOT')

visualizers_group = enhanced_group.find_subpath('Visualizers', true)
visualizers_group.set_source_tree('SOURCE_ROOT')

# 添加文件到对应组
files.each do |file_path|
    # 确定文件应该添加到哪个组
    group = nil
    if file_path.include?('Theme/')
        group = theme_group
    elsif file_path.include?('Base/')
        group = base_group
    elsif file_path.include?('Composite/')
        group = composite_group
    elsif file_path.include?('Indicators/')
        group = indicators_group
    elsif file_path.include?('Animations/')
        group = animations_group
    elsif file_path.include?('Visualizers/')
        group = visualizers_group
    else
        group = views_group
    end
    
    # 添加文件引用
    file_ref = group.new_reference(file_path)
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
ruby add_ui_files.rb "$PROJECT_FILE" "$TARGET_NAME" "${UI_FILES[@]}"

# 清理临时文件
rm -f add_ui_files.rb

echo "完成！请在 Xcode 中重新打开项目以查看更改。"
echo ""
echo "📋 已添加的 UI 组件："
echo "  🎨 主题系统: CWTheme.swift"
echo "  🔧 基础组件: Button, Card, ProgressBar, TextField, Label"
echo "  📦 复合组件: RecordingPanel, StatusCard"
echo "  🎯 指示器: RecordingIndicator"
echo "  ✨ 动画效果: BreathingAnimation"
echo "  📊 可视化: AudioWaveform"
echo ""
echo "🚀 接下来可以在 ContentView.swift 中使用这些组件进行界面重构。"