# /cache-patch - Claude Code 1h 缓存补丁

> **参数说明**：`$ARGUMENTS` 由 Claude Code 自动传递，对应用户输入的参数部分（如 `/cache-patch status` 中的 `status`）。

**立即执行以下命令，不做任何检测、搜索或判断：**

```bash
cp ~/.claude/templates/cache-patch/claude-1h-cache-patch.js ./claude-1h-cache-patch.js && node claude-1h-cache-patch.js $ARGUMENTS && rm claude-1h-cache-patch.js
```

## 参数映射

| 用户输入 | $ARGUMENTS |
|---------|-----------|
| `/cache-patch` | `patch` |
| `/cache-patch status` | `status` |
| `/cache-patch restore` | `restore` |

## 禁止事项

- ❌ 检测 Node.js 是否安装
- ❌ 搜索 Claude Code 安装目录
- ❌ 手动修改任何文件
- ❌ 自行编写补丁逻辑

## 唯一允许的操作

✅ 执行上面的 bash 命令（一条命令，用 && 连接）

## 说明

脚本会自动：
- 检测当前 Claude Code 是否已应用补丁
- 如果已生效，显示状态信息
- 如果未生效，应用 1h 缓存补丁
- 支持还原到原始状态
