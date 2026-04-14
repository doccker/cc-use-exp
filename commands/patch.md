# /patch - Claude Code 综合补丁

统一补丁入口，根据参数执行不同操作。

## 参数映射

| 用户输入 | 执行命令 |
|---------|---------|
| `/patch` | `python3 ~/.claude/tools/patch-claude.py --auto && node ~/.claude/templates/cache-patch/claude-1h-cache-patch.js patch && python3 tools/patch-toolsearch.py --auto` |
| `/patch status` | `python3 ~/.claude/tools/patch-claude.py --status` |
| `/patch restore` | `python3 ~/.claude/tools/patch-claude.py --auto --restore` |
| `/patch tui` | `python3 ~/.claude/tools/patch-claude.py` |
| `/patch toolsearch` | `python3 tools/patch-toolsearch.py --auto` |
| `/patch cache` | `cp ~/.claude/templates/cache-patch/claude-1h-cache-patch.js ./claude-1h-cache-patch.js && node claude-1h-cache-patch.js patch && rm claude-1h-cache-patch.js` |

## 执行规则

**立即执行对应的 bash 命令，不做任何检测、搜索或判断。**

## 禁止事项

- ❌ 检测 Python/Node.js 是否安装
- ❌ 搜索 Claude Code 安装目录
- ❌ 手动修改任何文件
- ❌ 自行编写补丁逻辑

## 说明

`/patch`（无参数）会依次执行三个工具，应用全部 6 项补丁：

由 `patch-claude.py` 管理（4 项）：
- Chrome 订阅检查绕过（/chrome 命令）
- Context Warning 禁用
- Auth conflict 警告抑制
- Read/Search 折叠禁用

由独立工具管理（2 项）：
- 1h Prompt Cache 启用（JS 脚本）
- ToolSearch 域名限制解除（Python 脚本）

`/patch status` 会展示全部 6 项补丁的当前状态。
