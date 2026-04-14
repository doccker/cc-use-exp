---
description: 检查 ToolSearch（WebSearch）是否可用
---

验证当前 Claude Code 环境是否支持 ToolSearch 工具。

## 执行步骤

### 1. 尝试调用 WebSearch

使用 WebSearch 工具搜索关键词 `Claude Code CLI`。

### 2. 获取本机版本

使用 Bash 执行 `claude --version` 获取用户当前安装的 Claude Code 版本号。

### 3. 判断结果

**如果搜索成功返回结果**：

```
✅ ToolSearch 可用

搜索功能正常，你的 Claude Code 已支持 WebSearch/ToolSearch。

好处：
- 大幅减少 token 占用（工具定义不再内嵌上下文）
- 模型表现更好（上下文更干净，注意力不被稀释）
- 对话轮次更多（同样的上下文窗口可以增加数轮对话）

当前 Claude Code 版本为 {claude --version 的输出}。
```

**如果搜索失败或报错**：

```
❌ ToolSearch 不可用

可能原因：
1. 使用第三方中转地址，域名未通过白名单检查
2. Claude Code 版本不支持

解决方案：
  python tools/patch-toolsearch.py 或者
  python3 tools/patch-toolsearch.py

脚本会自动检测安装位置并解除域名限制，执行后重启 claude 即可。
```
