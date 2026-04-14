# 生成 Git Commit Message

分析未提交的代码变更，生成结构化的 commit message。

## 执行步骤

### 1. 获取变更内容

```bash
# 查看已暂存的变更
git diff --cached --stat
git diff --cached

# 如果没有暂存内容，查看所有变更
git diff --stat
git diff
```

### 2. 分析变更类型

根据变更内容判断类型：

| 类型 | 适用场景 |
|------|---------|
| feat | 新功能 |
| fix | 修复 bug |
| refactor | 重构（不改变功能） |
| style | 格式调整（不影响代码逻辑） |
| docs | 文档更新 |
| test | 测试相关 |
| chore | 构建、依赖、配置等 |

### 3. 生成 commit message

格式要求：
```
<type>: <subject>

<body>
```

规则：
- subject: 简洁描述，不超过 50 字符，中文
- body: 变更详情，用列表形式，中文
- 不要加 emoji
- 不要加 AI 生成声明
- 不要加 Co-Authored-By

### 4. 输出格式

```
## 建议的 Commit Message

---
<type>: <subject>

- <变更点1>
- <变更点2>
- <变更点3>
---

## 变更文件

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| file1 | 新增/修改/删除 | 简要说明 |

## 快速提交

复制以下命令手动执行（不要由 Claude Code 代执行）：
git add <文件列表> && git commit -m "<生成的message>"
```

---

参数说明：
- 无参数：分析已暂存的变更
- `$ARGUMENTS` 包含 "all"：分析所有变更（含未暂存）