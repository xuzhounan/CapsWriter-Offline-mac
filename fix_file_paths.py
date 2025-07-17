#!/usr/bin/env python3
"""
修复 Xcode 项目文件中的文件路径引用
"""

import re

def fix_file_paths():
    project_path = "/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_path, 'r') as f:
        content = f.read()
    
    # 需要修复的文件路径映射
    path_fixes = {
        'DIContainer.swift': 'Sources/Core/DIContainer.swift',
        'ErrorHandler.swift': 'Sources/Core/ErrorHandler.swift',
        'AppEvents.swift': 'Sources/Core/AppEvents.swift',
        'EventBus.swift': 'Sources/Core/EventBus.swift',
        'StateManager.swift': 'Sources/Core/StateManager.swift',
        'ErrorHandlerIntegration.swift': 'Sources/Core/ErrorHandlerIntegration.swift',
        'EventBusAdapter.swift': 'Sources/Core/EventBusAdapter.swift'
    }
    
    # 修复 PBXFileReference 中的路径
    for filename, correct_path in path_fixes.items():
        # 查找当前的文件引用
        pattern = f'path = "{re.escape(filename)}";'
        replacement = f'path = "{correct_path}";'
        content = content.replace(pattern, replacement)
        
        print(f"✅ 修复了 {filename} 的路径引用")
    
    # 备份原文件
    backup_path = project_path + ".path_fix_backup"
    with open(backup_path, 'w') as f:
        f.write(open(project_path, 'r').read())
    
    # 写入修复后的文件
    with open(project_path, 'w') as f:
        f.write(content)
    
    print(f"✅ 项目文件路径已修复")
    print(f"✅ 备份保存到: {backup_path}")

if __name__ == "__main__":
    fix_file_paths()