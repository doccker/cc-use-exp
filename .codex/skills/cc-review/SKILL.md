---
name: cc-review
description: 结构化代码审查工作流，适用于显式 quick/full/security review；不负责普通实现或 bug 修复流程。
---

# CC Review

当用户明确要求 review、quick review 或 security review 时，使用本技能。

不要用于：

- 普通编码实现
- 直接 bug 修复
- 语言细节规范
- 环境级风险判断

## 审查模式

用户可以指定审查目标：

- **审查当前分支**：`$cc-review`、`$cc-review quick`、`$cc-review security`
- **审查指定提交**：`$cc-review <commit-hash>`、`$cc-review quick <commit-hash>`、`$cc-review security <commit-hash>`

参数解析规则：
1. 优先匹配模式关键字（quick/security/full）
2. 其他参数视为 commit hash
3. 参数顺序灵活（`$cc-review quick abc123` 或 `$cc-review abc123 quick` 均可）

### Quick Review

面向当前 diff 或指定提交，快速给出高价值反馈。

**Git 命令**：
- 当前分支：`git diff --stat` + `git diff`
- 指定提交：`git show --stat <commit>` + `git show <commit>`

### Full Review

围绕受影响调用链、输入输出契约和回归面做更完整的审查。

**Git 命令**：
- 当前分支：`git diff --merge-base origin/HEAD`
- 指定提交：`git show <commit>`

### Security Review

重点检查认证授权、输入校验、命令执行、数据暴露和权限边界。

**Git 命令**：
- 当前分支：`git diff --merge-base origin/HEAD`
- 指定提交：`git show <commit>`

## 默认优先级

1. 错误行为和明显 bug
2. 回归风险
3. 缺失校验或错误处理
4. 安全问题
5. 缺失或薄弱测试
6. 可维护性问题

## Commit Hash 验证

当用户指定 commit hash 时，必须先验证其有效性：

```bash
# 验证 commit 是否存在
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
```

审查报告开头应包含审查范围信息：

```markdown
### 审查范围

**提交**: `<full-hash>`
**信息**: <commit-message>
**作者**: <author-name> <<author-email>>
**时间**: <commit-date>
```

## 输出要求

- 默认使用简体中文输出；只有用户明确要求英文或需要保留外部英文材料时才切换。
- 标题、严重度和结论使用中文命名，例如“发现的问题”“待确认问题”“残余风险”“总结”“高/中/低”。
- findings 优先，按严重度排序。
- 尽量带精确文件引用。
- 总结保持简短，放在 findings 之后。
- 若没有发现问题，要明确写出“未发现明确问题”，并说明残余风险或验证盲区。

## 按需展开

- 审查优先级：`references/review-priority.md`
- Quick Review：`references/quick-review.md`
- Full Review：`references/full-review.md`
- Security Review：`references/security-review.md`
