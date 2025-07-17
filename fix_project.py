#!/usr/bin/env python3
"""
自动将 Sources/Core 目录下的文件添加到 Xcode 项目中
"""

import os
import uuid
import re

def generate_uuid():
    """生成24位的十六进制UUID（Xcode格式）"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_xcode_project():
    project_path = "/Users/xzn/Desktop/code-project/CapsWriter-Offline-mac/CapsWriter-mac/CapsWriter-mac.xcodeproj/project.pbxproj"
    
    # 需要添加的文件
    files_to_add = [
        "Sources/Core/DIContainer.swift",
        "Sources/Core/ErrorHandler.swift", 
        "Sources/Core/AppEvents.swift",
        "Sources/Core/EventBus.swift",
        "Sources/Core/StateManager.swift",
        "Sources/Core/ErrorHandlerIntegration.swift",
        "Sources/Core/EventBusAdapter.swift"
    ]
    
    # 读取项目文件
    with open(project_path, 'r') as f:
        content = f.read()
    
    # 为每个文件生成UUID
    file_refs = {}
    build_files = {}
    
    for file_path in files_to_add:
        file_name = os.path.basename(file_path)
        file_refs[file_path] = generate_uuid()
        build_files[file_path] = generate_uuid()
    
    # 添加文件引用到 PBXFileReference 部分
    fileref_section = ""
    for file_path, file_uuid in file_refs.items():
        file_name = os.path.basename(file_path)
        fileref_section += f"\t\t{file_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{file_name}\"; sourceTree = \"<group>\"; }};\n"
    
    # 查找 PBXFileReference 部分并添加文件引用
    pbx_fileref_pattern = r"(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)"
    match = re.search(pbx_fileref_pattern, content, re.DOTALL)
    if match:
        old_section = match.group(1)
        new_section = old_section.replace("/* End PBXFileReference section */", 
                                         f"{fileref_section}\t/* End PBXFileReference section */")
        content = content.replace(old_section, new_section)
    
    # 添加构建文件到 PBXBuildFile 部分
    buildfile_section = ""
    for file_path, build_uuid in build_files.items():
        file_name = os.path.basename(file_path)
        file_ref_uuid = file_refs[file_path]
        buildfile_section += f"\t\t{build_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n"
    
    # 查找 PBXBuildFile 部分并添加构建文件
    pbx_buildfile_pattern = r"(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)"
    match = re.search(pbx_buildfile_pattern, content, re.DOTALL)
    if match:
        old_section = match.group(1)
        new_section = old_section.replace("/* End PBXBuildFile section */",
                                         f"{buildfile_section}\t/* End PBXBuildFile section */")
        content = content.replace(old_section, new_section)
    
    # 找到Sources/Core组并添加文件引用
    # 首先需要找到或创建 Sources/Core 组
    sources_core_group_uuid = generate_uuid()
    
    # 查找现有的Sources组
    sources_group_pattern = r"([A-F0-9]{24}) /\* Sources \*/ = \{[^}]*children = \([^)]*\);"
    match = re.search(sources_group_pattern, content)
    if match:
        # 在Sources组中添加Core组引用
        sources_group_def = match.group(0)
        if "Sources/Core" not in sources_group_def:
            new_sources_def = sources_group_def.replace(
                ");",
                f"\t\t\t\t{sources_core_group_uuid} /* Core */,\n\t\t\t);"
            )
            content = content.replace(sources_group_def, new_sources_def)
    
    # 创建Core组定义
    core_group_children = ""
    for file_path, file_uuid in file_refs.items():
        file_name = os.path.basename(file_path)
        core_group_children += f"\t\t\t\t{file_uuid} /* {file_name} */,\n"
    
    core_group_def = f"""		{sources_core_group_uuid} /* Core */ = {{
			isa = PBXGroup;
			children = (
{core_group_children}			);
			path = "Sources/Core";
			sourceTree = "<group>";
		}};"""
    
    # 在PBXGroup部分添加Core组
    pbx_group_pattern = r"(/\* Begin PBXGroup section \*/.*?/\* End PBXGroup section \*/)"
    match = re.search(pbx_group_pattern, content, re.DOTALL)
    if match:
        old_section = match.group(1)
        new_section = old_section.replace("/* End PBXGroup section */",
                                         f"{core_group_def}\n\t/* End PBXGroup section */")
        content = content.replace(old_section, new_section)
    
    # 将构建文件添加到Sources构建阶段
    sources_build_pattern = r"([A-F0-9]{24}) /\* Sources \*/ = \{[^}]*files = \([^)]*\);"
    match = re.search(sources_build_pattern, content)
    if match:
        sources_build_def = match.group(0)
        for file_path, build_uuid in build_files.items():
            file_name = os.path.basename(file_path)
            if build_uuid not in sources_build_def:
                new_build_def = sources_build_def.replace(
                    ");",
                    f"\t\t\t\t{build_uuid} /* {file_name} in Sources */,\n\t\t\t);"
                )
                content = content.replace(sources_build_def, new_build_def)
                sources_build_def = new_build_def
    
    # 备份原文件
    backup_path = project_path + ".backup"
    with open(backup_path, 'w') as f:
        f.write(open(project_path, 'r').read())
    
    # 写入修改后的文件
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("✅ 已将Sources/Core文件添加到Xcode项目")
    print(f"✅ 原项目文件已备份到: {backup_path}")
    print("✅ 现在可以尝试重新编译项目")

if __name__ == "__main__":
    add_files_to_xcode_project()