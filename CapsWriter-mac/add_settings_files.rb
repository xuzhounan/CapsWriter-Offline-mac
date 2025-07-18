#!/usr/bin/env ruby

require 'xcodeproj'

# 定义要添加的文件列表
new_files = [
  'Sources/Views/Settings/SettingsTypes.swift',
  'Sources/Views/Settings/SettingsView.swift',
  'Sources/Views/Settings/Components/SettingsComponents.swift',
  'Sources/Views/Settings/Categories/GeneralSettingsView.swift',
  'Sources/Views/Settings/Categories/AudioSettingsView.swift',
  'Sources/Views/Settings/Categories/RecognitionSettingsView.swift',
  'Sources/Views/Settings/Categories/HotWordSettingsView.swift',
  'Sources/Views/Settings/Categories/ShortcutSettingsView.swift',
  'Sources/Views/Settings/Categories/AdvancedSettingsView.swift',
  'Sources/Views/Settings/Categories/AboutSettingsView.swift',
  'Sources/Views/Settings/Editors/HotWordEditor.swift'
]

project_path = 'CapsWriter-mac.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主要的 target
main_target = project.targets.find { |target| target.name == 'CapsWriter-mac' }

if main_target.nil?
  puts "找不到主要的 target"
  exit 1
end

# 找到 Sources 组
sources_group = project.main_group.find_subpath('Sources', true)
views_group = sources_group.find_subpath('Views', true)

# 创建 Settings 组结构
settings_group = views_group.find_subpath('Settings', true)
components_group = settings_group.find_subpath('Components', true) 
categories_group = settings_group.find_subpath('Categories', true)
editors_group = settings_group.find_subpath('Editors', true)

# 添加文件到项目
new_files.each do |file_path|
  file_ref = nil
  
  if file_path.include?('Components/')
    file_ref = components_group.new_file(file_path)
  elsif file_path.include?('Categories/')
    file_ref = categories_group.new_file(file_path)
  elsif file_path.include?('Editors/')
    file_ref = editors_group.new_file(file_path)
  else
    file_ref = settings_group.new_file(file_path)
  end
  
  # 添加到构建阶段
  main_target.add_file_references([file_ref])
  
  puts "添加文件: #{file_path}"
end

# 保存项目
project.save

puts "所有设置界面文件已成功添加到 Xcode 项目!"