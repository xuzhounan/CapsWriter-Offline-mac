# 🚀 CapsWriter-mac 项目上下文 Prompt

## 📋 项目快速上下文设定

你好！我需要你协助开发 **CapsWriter-mac** 项目。请先阅读以下上下文信息，然后执行我的具体任务。

### 🎯 项目基本信息

**项目名称**: CapsWriter-mac  
**项目类型**: macOS 原生语音输入应用  
**技术栈**: Swift + SwiftUI + Sherpa-ONNX  
**当前状态**: 功能原型 → 生产级应用重构中  

### 📁 项目结构概览

```
CapsWriter-Offline-mac/
├── CapsWriter-mac/              # macOS 原生应用
│   ├── Sources/                 # Swift 源代码
│   │   ├── Services/           # 业务服务层
│   │   ├── Views/              # SwiftUI 界面
│   │   ├── States/             # 状态管理
│   │   └── Core/               # 核心组件
│   ├── Models/                 # Sherpa-ONNX 模型
│   └── Frameworks/             # 动态库
├── Python 端 (参考架构)
│   ├── core_server.py          # WebSocket 服务端
│   ├── core_client.py          # 客户端实现
│   └── util/                   # 工具模块
├── CLAUDE.md                   # 📖 项目开发指南 (必读)
└── PROJECT_CONTEXT_PROMPT.md   # 本文件
```

### 🔧 核心技术架构

- **语音识别**: Sherpa-ONNX C API + Paraformer 模型
- **音频处理**: AVFoundation (16kHz 实时流)
- **键盘监听**: Carbon API (全局热键)
- **状态管理**: SwiftUI + Combine (MVVM)
- **权限管理**: 麦克风 + 辅助功能权限

### 📖 必要准备工作

**请按顺序执行以下步骤**:

1. **阅读项目文档**:
   ```
   请先阅读 ./CLAUDE.md 文件，了解完整的项目背景、架构设计和开发规范
   ```

2. **了解当前进度**:
   ```
   查看 CLAUDE.md 中的 "🚀 CapsWriter-mac 架构优化实施计划" 章节
   了解当前所处的开发阶段和待执行任务
   ```

3. **检查项目状态**:
   ```bash
   # 查看当前 Git 状态
   git status
   git log --oneline -5
   
   # 检查 macOS 项目结构
   ls -la CapsWriter-mac/
   ```

### 🎯 任务执行模式

**请按照以下模式执行任务**:

#### A. 任务开始前
- [ ] 使用 `TodoWrite` 工具创建任务列表
- [ ] 明确任务的验收标准和交付物
- [ ] 检查相关依赖和前置条件

#### B. 任务执行中
- [ ] 保持任务进度的实时更新 (`TodoWrite`)
- [ ] 遵循 CLAUDE.md 中的开发规范
- [ ] 确保代码符合 Swift API Design Guidelines
- [ ] 及时处理编译错误和警告

#### C. 任务完成后
- [ ] 验证功能正确性（编译、运行测试）
- [ ] 更新相关文档（如有API变化）
- [ ] 执行 Git 提交流程
- [ ] 标记所有 TODO 为完成状态

### 📝 Git 提交标准

**必须遵循以下提交规范**:

```bash
# 1. 添加修改文件
git add [文件列表]

# 2. 使用标准格式提交
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<optional body>

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**提交类型 (type)**:
- `feat`: 新功能
- `fix`: Bug 修复  
- `refactor`: 代码重构
- `docs`: 文档更新
- `test`: 测试相关
- `chore`: 构建/工具相关

**范围 (scope)**: `core`, `ui`, `service`, `config`, `test` 等

### ⚠️ 重要约束

**请务必遵守以下限制**:
- ❌ **不要修改 Sherpa-ONNX C API 接口**
- ❌ **不要替换 Swift 为其他语言**  
- ❌ **不要引入复杂外部依赖**
- ✅ **保持与原项目的功能对等**
- ✅ **确保 macOS 原生体验**
- ✅ **遵循既定的架构设计**

### 🔍 常用调试命令

```bash
# macOS 应用编译测试
cd CapsWriter-mac
xcodebuild -project CapsWriter-mac.xcodeproj -scheme CapsWriter-mac build

# 检查权限配置
plutil -p CapsWriter-mac/Info.plist | grep -i usage

# 查看 Sherpa-ONNX 集成状态
otool -L CapsWriter-mac/Frameworks/libsherpa-onnx-c-api.dylib
```

### 🎯 当前优先任务

**根据架构优化计划，当前重点关注**:
1. 配置管理系统重构
2. 状态管理分层设计  
3. 服务层解耦和协议化
4. 热词替换功能实现

---

## 🚨 任务执行检查清单

**在开始具体任务前，请确认**:
- [ ] 已完整阅读 `CLAUDE.md` 文件
- [ ] 了解当前项目状态和架构设计
- [ ] 明确本次任务的具体目标和验收标准
- [ ] 准备好使用 `TodoWrite` 工具跟踪进度
- [ ] 了解相关的 Git 提交规范

**准备完成后，请回复**:
> "✅ 项目上下文已载入，当前处于 [阶段名称]，准备执行: [具体任务描述]"

然后我会提供具体的任务指令。

---

## 📋 可复用 Prompt 模板

**当你需要在新对话中快速设定上下文时，请使用以下 prompt**:

```
请你协助开发 CapsWriter-mac 项目。

项目路径: /Users/xzn/Desktop/code-project/CapsWriter-Offline-mac

请先执行以下步骤:
1. 阅读 ./CLAUDE.md 文件了解项目背景和架构
2. 查看 ./PROJECT_CONTEXT_PROMPT.md 了解开发规范
3. 检查当前 Git 状态: git status && git log --oneline -5
4. 了解项目当前的开发阶段和待执行任务

完成上下文载入后，我将为你分配具体的开发任务。

请按照文档中的规范执行任务，并保持文档同步更新。
```

**然后提供具体任务**:
```
现在请执行以下任务:
[具体任务描述]

要求:
- 使用 TodoWrite 工具跟踪任务进度
- 遵循 CLAUDE.md 中的开发规范
- 完成后执行标准 Git 提交流程
- 更新相关文档记录
```