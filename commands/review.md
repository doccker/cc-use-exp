---
description: 代码审查（full/quick/security 三种模式），支持指定提交
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Bash(git rev-parse:*), Read, Glob, Grep
argument-hint: "[quick|security] [commit-hash] 默认 full 全量审查当前分支"
---

根据参数选择审查模式和审查目标：

**审查当前分支**：
- `/review` 或 `/review full` → 全量代码审查
- `/review quick` → 快速审查（一键 diff + 结论）
- `/review security` → 安全专项审查

**审查指定提交**：
- `/review <commit-hash>` → 审查单个提交（full 模式）
- `/review quick <commit-hash>` → 快速审查单个提交
- `/review security <commit-hash>` → 安全审查单个提交
- `/review <commit-hash> quick` → 参数顺序灵活

参数值：「$ARGUMENTS」

---

## 参数解析

首先解析参数，确定审查模式和目标：

```bash
# 解析参数
ARGS="$ARGUMENTS"
MODE="full"
TARGET=""

# 提取模式和目标
for arg in $ARGS; do
  case "$arg" in
    quick|security|full)
      MODE="$arg"
      ;;
    *)
      TARGET="$arg"
      ;;
  esac
done

# 如果指定了 commit，验证其有效性
if [ -n "$TARGET" ]; then
  if ! git rev-parse --verify "$TARGET^{commit}" >/dev/null 2>&1; then
    echo "❌ 错误：无效的 commit hash: $TARGET"
    echo ""
    echo "请检查："
    echo "1. commit hash 是否正确（可以是完整 hash 或短 hash）"
    echo "2. commit 是否存在于当前仓库"
    echo ""
    echo "提示：使用 'git log' 查看可用的 commit"
    exit 1
  fi

  # 获取完整 hash 和提交信息
  FULL_HASH=$(git rev-parse "$TARGET")
  COMMIT_MSG=$(git log -1 --pretty=format:"%s" "$TARGET")

  echo "### 审查范围"
  echo ""
  echo "**提交**: \`$FULL_HASH\`"
  echo "**信息**: $COMMIT_MSG"
  echo "**作者**: $(git log -1 --pretty=format:"%an <%ae>" "$TARGET")"
  echo "**时间**: $(git log -1 --pretty=format:"%ai" "$TARGET")"
  echo ""
fi
```

根据解析结果，执行对应模式的审查。

---

## 模式 1：full（默认）

你是一位资深的代码审查工程师，负责执行务实的代码审查。

核心原则：**净正向 > 完美**，只要变更整体上改善了代码质量，不要因小瑕疵阻塞。

### 变更信息

根据是否指定了 commit，使用不同的 Git 命令获取变更信息：

**如果指定了 commit（TARGET 非空）**：

```bash
# Git 状态（仅当前分支需要）
if [ -z "$TARGET" ]; then
  echo "!`git status`"
fi

# 变更文件
if [ -z "$TARGET" ]; then
  echo "!`git diff --name-only origin/HEAD...`"
fi

# 提交记录
if [ -n "$TARGET" ]; then
  echo "!`git show --no-patch $TARGET`"
else
  echo "!`git log --no-decorate origin/HEAD...`"
fi

# 变更内容
if [ -n "$TARGET" ]; then
  echo "!`git show $TARGET`"
else
  echo "!`git diff --merge-base origin/HEAD`"
fi
```

### 审查框架

按以下优先级顺序审查：

#### 1. 架构设计（关键）
- 是否符合现有架构模式和系统边界
- 模块性和单一职责原则
- 是否存在不必要的复杂度

#### 2. 功能正确性（关键）
- 业务逻辑是否正确实现
- 边界条件和异常处理
- 并发和状态管理

#### 3. 安全性（必须）
- 输入验证和转义
- 认证授权检查
- 敏感信息处理

#### 4. 可维护性（重要）
- 代码清晰度和命名
- 注释说明意图而非机制
- 错误信息是否便于调试

#### 5. 测试（重要）
- 测试覆盖关键路径
- 测试边界条件和错误场景

#### 6. 性能（注意）
- N+1 查询问题
- 不必要的内存分配
- 缓存策略

#### 7. 文件规模（注意）
- 检查 diff 涉及的每个文件总行数，对照语言阈值（Java 300 / Go 400 / Vue 200 / TSX/JSX 200 / TS/JS 300 / Python 300）
- 超限文件标记为 `[Improvement]`，给出具体拆分建议（按职责拆分、提取子组件、抽工具类等）
- 阈值详见 `rules/file-size-limit.md`

#### 8. 重构安全（注意）

检查是否存在重构风险：

**表格/列表重构**：
- 列数、列名、列顺序是否与原始代码一致
- 是否遗漏列或添加多余列
- 条件分支（if/else）是否都已正确处理

**数据结构重构**：
- 字段是否完整，没有遗漏
- 字段顺序是否一致（如果顺序重要）
- 字段类型是否一致

**条件分支重构**：
- 所有 if/else/switch 分支是否都已处理
- 是否存在"只处理一个分支，推测其他分支"的情况

**检查方法**：
1. 使用 `git show <commit>:<file>` 查看原始代码
2. 制作对比清单（列/字段/配置项）
3. 标记不一致项为 `[Critical]`

**依赖方向检查**（服务/模块拆分时）：
- 拆分后是否存在循环依赖（A → B → A）
- 子模块回调父模块的方法是否为纯工具方法（是 → 应提取到独立类）
- Spring Boot 3.x 构造器循环依赖会导致启动失败
- 标记循环依赖为 `[Critical]`

#### 9. 字段映射安全（注意）

检查是否存在字段映射错误：

**dataIndex 字段名**：
- 字段名是否与原始代码一致
- 是否使用了可选字段（优先使用必填字段）
- 注意字段名的细微差异（changedAt vs createdAt）

**枚举映射完整性**：
- 枚举映射是否完整（对照原始代码逐个检查）
- 是否遗漏枚举值（如只保留 3 个，实际有 10 个）
- 枚举值的拼写是否正确（UPLOAD vs Upload）

**防御性编程**：
- 是否有空值检查（if (!val) return '-'）
- 日期格式化是否有异常捕获
- 枚举映射是否有默认值

**rowKey 安全**：
- rowKey 是否使用了可选字段
- rowKey 是否唯一

**检查方法**：
1. 使用 `git show <commit>:<file>` 查看原始代码
2. 对比字段名、枚举映射
3. 检查 TypeScript 类型定义中的可选字段
4. 标记不一致项为 `[Critical]`

### 输出格式

```markdown
### 代码审查报告

**总体评估**：[简要说明变更的整体质量和主要发现]

### 问题发现

#### [Critical] 严重问题
- **文件:行号**：[问题描述和原因]

#### [Improvement] 建议改进
- **文件:行号**：[建议和原理]

#### [Nit] 细节建议
- Nit: **文件:行号**：[小建议]

### 结论

[通过 / 需修改后通过 / 需重新设计]
```

### 要求

- 提供具体、可操作的反馈
- 解释建议背后的工程原理
- 保持建设性，假设开发者有良好意图
- 使用简体中文输出

### 下一步操作

审查完成后，根据结论执行：

**结论为「通过」**：直接结束，不询问。

**结论为「需修改后通过」或「需重新设计」**：

使用 AskUserQuestion 询问用户，提供以下选项和风险说明：

```
请选择修复方式：

1. 只修复严重问题（推荐）
   仅修复 [Critical] 问题。范围最小，只改必须修的 bug，
   不会影响现有功能的正常运行。

2. 修复全部问题
   修复 [Critical] + [Improvement] 问题。改动范围较大，
   Improvement 属于建议性改进，修复过程中可能改变现有代码行为，
   存在引入新问题的风险。

3. 跳过
   不做任何修改，仅保留审查报告供参考。
```

用户选择后，调用 Skill 工具执行 `/fix`，参数格式：
```
[code-review] 根据代码审查结果修复以下问题：
1. [文件:行号] 问题描述
2. [文件:行号] 问题描述
...
```

注意：
- [Nit] 类问题不纳入自动修复范围
- 参数必须以 `[code-review]` 开头，触发 /fix 的变更范围约束

---

## 模式 2：quick

快速审查改动，直接输出问题和建议。

### 执行

根据是否指定了 commit，使用不同的命令获取改动：

**如果指定了 commit（TARGET 非空）**：
```bash
# 获取提交统计
git show --stat $TARGET

# 获取提交变更
git show $TARGET
```

**如果审查当前分支**：
```bash
# 获取改动统计
git diff --stat

# 获取改动内容
git diff
```

直接输出审查结果，不需要用户确认。

### 输出格式

```
## 改动概览
[文件列表和改动行数]

## 问题（必须修复）
- [ ] 问题1
- [ ] 问题2

## 建议（可选优化）
- 建议1
- 建议2

## 结论
✅ 可以提交 / ⚠️ 建议修复后提交 / ❌ 需要修复
```

不要啰嗦，直接给结论。

---

## 模式 3：security

对代码变更进行安全审查。

### 上下文信息

根据是否指定了 commit，使用不同的命令获取上下文：

**如果指定了 commit（TARGET 非空）**：

GIT STATUS: （跳过，单个 commit 不需要）

COMMIT INFO:
```
!`git show --no-patch $TARGET`
```

DIFF CONTENT:
```
!`git show $TARGET`
```

**如果审查当前分支**：

GIT STATUS:
```
!`git status`
```

FILES MODIFIED:
```
!`git diff --name-only origin/HEAD... 2>/dev/null || git diff --name-only HEAD~5`
```

DIFF CONTENT:
```
!`git diff --merge-base origin/HEAD 2>/dev/null || git diff HEAD~5`
```

### 审查目标

识别 **高置信度** 的安全漏洞，只报告 >80% 确信可被利用的问题。

### 审查范围

#### 输入验证漏洞
- SQL 注入、命令注入、路径遍历
- XSS（仅不安全的 innerHTML 赋值方法）

#### 认证与授权
- 认证绕过、权限提升、会话管理缺陷

#### 密钥与加密
- 硬编码密钥/密码、弱加密算法、证书验证绕过

#### 代码执行
- 反序列化漏洞、eval 注入、模板注入

### 排除项（不报告）

- DoS/资源耗尽、磁盘上的密钥文件、速率限制、日志污染
- 理论性/低影响漏洞、测试文件中的问题
- React/Vue 组件中的 XSS（框架已保护）

### 输出格式

```markdown
# 安全审查报告

## 发现的问题

### [严重程度] 漏洞类型: `文件:行号`

**描述**: [漏洞描述]
**利用场景**: [具体的攻击路径]
**置信度**: [8-10]/10
**建议修复**: [修复建议]

---

## 总结

- 高危: X 个
- 中危: X 个
- 总体评估: [安全/需要关注/存在风险]
```

### 严重程度定义

- **高危**: 直接可利用，导致 RCE、数据泄露、认证绕过
- **中危**: 需要特定条件，但影响显著

### 注意事项

- 只读审查，不修改任何代码
- 宁可漏报，不可误报
- 每个发现都需要具体的利用场景
