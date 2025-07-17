#!/usr/bin/env python3
"""
正确修复 Xcode 项目文件中的文件路径引用
"""

import re

def fix_correct_paths():
    project_path = "/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_path, 'r') as f:
        content = f.read()
    
    # 修复路径：将 Sources/ 替换为 CapsWriter-mac/Sources/
    # 这些是需要修复的路径映射
    path_fixes = {
        'path = "Sources/Core/DIContainer.swift";': 'path = "CapsWriter-mac/Sources/Core/DIContainer.swift";',
        'path = "Sources/Configuration/ConfigurationManager.swift";': 'path = "CapsWriter-mac/Sources/Configuration/ConfigurationManager.swift";',
        'path = "Sources/Controllers/VoiceInputController.swift";': 'path = "CapsWriter-mac/Sources/Controllers/VoiceInputController.swift";',
        'path = "Sources/States/AudioState.swift";': 'path = "CapsWriter-mac/Sources/States/AudioState.swift";',
        'path = "Sources/States/RecognitionState.swift";': 'path = "CapsWriter-mac/Sources/States/RecognitionState.swift";',
        'path = "Sources/States/AppState.swift";': 'path = "CapsWriter-mac/Sources/States/AppState.swift";'
    }
    
    # 执行路径修复
    for old_path, new_path in path_fixes.items():
        if old_path in content:
            content = content.replace(old_path, new_path)
            print(f"✅ 修复了路径: {old_path} -> {new_path}")
    
    # 备份原文件
    backup_path = project_path + ".correct_fix_backup"
    with open(backup_path, 'w') as f:
        f.write(open(project_path, 'r').read())
    
    # 写入修复后的文件
    with open(project_path, 'w') as f:
        f.write(content)
    
    print(f"✅ 正确的路径修复已完成")
    print(f"✅ 备份保存到: {backup_path}")
    print("✅ 现在所有文件路径都正确指向 CapsWriter-mac/Sources/... 目录")

if __name__ == "__main__":
    fix_correct_paths()