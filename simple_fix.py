#!/usr/bin/env python3
"""
简化修复：只添加 DIContainer.swift 到项目中
"""

import re
import uuid

def generate_uuid():
    """生成24位的十六进制UUID（Xcode格式）"""
    return uuid.uuid4().hex[:24].upper()

def simple_fix():
    project_path = "/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac.xcodeproj/project.pbxproj"
    
    # 恢复备份的原始项目文件
    backup_path = project_path + ".backup"
    try:
        with open(backup_path, 'r') as f:
            content = f.read()
        print("✅ 已恢复原始项目文件")
    except:
        with open(project_path, 'r') as f:
            content = f.read()
        print("⚠️ 使用当前项目文件")
    
    # 只添加 DIContainer.swift
    file_uuid = generate_uuid()
    build_uuid = generate_uuid()
    
    # 添加文件引用到 PBXFileReference 部分
    fileref_entry = f"\t\t{file_uuid} /* DIContainer.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"Sources/Core/DIContainer.swift\"; sourceTree = \"<group>\"; }};\n"
    
    # 查找 PBXFileReference 部分并添加文件引用
    pbx_fileref_pattern = r"(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)"
    match = re.search(pbx_fileref_pattern, content, re.DOTALL)
    if match:
        old_section = match.group(1)
        new_section = old_section.replace("/* End PBXFileReference section */", 
                                         f"{fileref_entry}\t/* End PBXFileReference section */")
        content = content.replace(old_section, new_section)
    
    # 添加构建文件到 PBXBuildFile 部分
    buildfile_entry = f"\t\t{build_uuid} /* DIContainer.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* DIContainer.swift */; }};\n"
    
    # 查找 PBXBuildFile 部分并添加构建文件
    pbx_buildfile_pattern = r"(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)"
    match = re.search(pbx_buildfile_pattern, content, re.DOTALL)
    if match:
        old_section = match.group(1)
        new_section = old_section.replace("/* End PBXBuildFile section */",
                                         f"{buildfile_entry}\t/* End PBXBuildFile section */")
        content = content.replace(old_section, new_section)
    
    # 将构建文件添加到Sources构建阶段
    sources_build_pattern = r"([A-F0-9]{24}) /\* Sources \*/ = \{[^}]*files = \([^)]*\);"
    match = re.search(sources_build_pattern, content, re.DOTALL)
    if match:
        sources_build_def = match.group(0)
        if build_uuid not in sources_build_def:
            new_build_def = sources_build_def.replace(
                ");",
                f"\t\t\t\t{build_uuid} /* DIContainer.swift in Sources */,\n\t\t\t);"
            )
            content = content.replace(sources_build_def, new_build_def)
    
    # 写入修改后的文件
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("✅ 已添加 DIContainer.swift 到项目")
    print("✅ 现在可以尝试编译项目")

if __name__ == "__main__":
    simple_fix()