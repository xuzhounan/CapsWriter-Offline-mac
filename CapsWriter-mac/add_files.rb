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
