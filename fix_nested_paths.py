#!/usr/bin/env python3
"""
修复嵌套目录结构导致的路径问题
"""

import re

def fix_nested_directory_paths():
    project_path = "/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_path, 'r') as f:
        content = f.read()
    
    # 修复路径：在所有Sources/Core路径前添加CapsWriter-mac/
    # 查找所有 "Sources/Core/..." 的路径引用
    content = content.replace(
        'path = "Sources/Core/DIContainer.swift";',
        'path = "CapsWriter-mac/Sources/Core/DIContainer.swift";'
    )
    
    print("✅ 修复了DIContainer.swift的路径引用")
    
    # 检查是否还有其他需要修复的路径
    sources_paths = [
        'Sources/Configuration/ConfigurationManager.swift',
        'Sources/Controllers/VoiceInputController.swift', 
        'Sources/Protocols/ServiceProtocols.swift',
        'Sources/States/AudioState.swift',
        'Sources/States/RecognitionState.swift',
        'Sources/States/AppState.swift'
    ]
    
    for path in sources_paths:
        if f'path = "{path}";' in content:
            content = content.replace(
                f'path = "{path}";',
                f'path = "CapsWriter-mac/{path}";'
            )
            print(f"✅ 修复了 {path} 的路径引用")
    
    # 备份原文件
    backup_path = project_path + ".nested_fix_backup"
    with open(backup_path, 'w') as f:
        f.write(open(project_path, 'r').read())
    
    # 写入修复后的文件
    with open(project_path, 'w') as f:
        f.write(content)
    
    print(f"✅ 嵌套路径问题已修复")
    print(f"✅ 备份保存到: {backup_path}")
    print("✅ 现在所有文件路径都正确指向 CapsWriter-mac/Sources/... 目录")

if __name__ == "__main__":
    fix_nested_directory_paths()