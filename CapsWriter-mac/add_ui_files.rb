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
