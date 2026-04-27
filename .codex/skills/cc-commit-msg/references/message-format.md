# Message Format

默认检查顺序：

1. `git diff --cached --stat`
2. `git diff --cached`
3. 用户明确要求 `all` 时，再看 `git diff --stat` 和 `git diff`

输出结构：

```markdown
## 建议的 Commit Message

<type>: <subject>

- 变更点 1
- 变更点 2

## 变更文件

| 文件 | 说明 |
|------|------|
| path/to/file | 核心改动 |

## 快速提交（heredoc，强制）

git add <文件列表> && git commit -m "$(cat <<'EOF'
<type>: <subject>

- 变更点 1
- 变更点 2
EOF
)"
```

约束：

- `subject` 保持单一主题，**最长不超过 80 字符**
- `body` 只写用户真正关心的行为变化
- **必须**给出 heredoc 落盘命令，不允许只给 message 文本而不给命令
- **禁止** `git commit -m "feat: x\n- a\n- b"` 这类单行写法（shell 不解析 `\n`，body 会被吞）
- 如果 staged 为空且用户也没要求 `all`，先明确说明输入为空
