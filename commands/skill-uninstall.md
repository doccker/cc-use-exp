---
description: 卸载 cc-use-exp 配置体系（仅 Plugin Marketplace 安装）
---

# cc-use-exp 卸载器

卸载通过 Plugin Marketplace 安装的 cc-use-exp 配置体系。

**注意**：此命令仅卸载 Plugin Marketplace 安装，不影响 external 方式安装。

---

## 执行步骤

### 第 1 步：检测安装

```bash
# 检查 Plugin Marketplace 安装位置
PLUGIN_CACHE=$(find "$HOME/.claude/plugins/cache" -name "cc-use-exp" -type d 2>/dev/null | head -1)
PLUGIN_INSTALLED="$HOME/.claude/plugins/installed/cc-use-exp@cc-use-exp"
PLUGIN_MARKETPLACE="$HOME/.claude/plugins/marketplaces/cc-use-exp"

if [ -z "$PLUGIN_CACHE" ] && [ ! -d "$PLUGIN_INSTALLED" ] && [ ! -d "$PLUGIN_MARKETPLACE" ]; then
  echo "❌ 未检测到 Plugin Marketplace 安装"
  echo ""
  echo "如果你是通过 external 方式安装，请手动删除："
  echo "  rm -rf ~/.claude/external/cc-use-exp"
  exit 1
fi

echo "✅ 检测到 Plugin Marketplace 安装"
echo ""
```

### 第 2 步：显示卸载内容 + 二次确认

```bash
echo "📋 将要删除以下内容："
echo ""

if [ -n "$PLUGIN_CACHE" ]; then
  echo "  - 插件缓存: $PLUGIN_CACHE"
fi

if [ -d "$PLUGIN_INSTALLED" ]; then
  echo "  - 已安装插件: $PLUGIN_INSTALLED"
fi

if [ -d "$PLUGIN_MARKETPLACE" ]; then
  echo "  - Marketplace 源: $PLUGIN_MARKETPLACE"
fi

echo ""
echo "✅ 将保留以下配置（不会删除）："
echo ""
echo "  - 用户配置: ~/.claude/CLAUDE.md"
echo "  - 规则文件: ~/.claude/rules/"
echo "  - 技能文件: ~/.claude/skills/"
echo "  - 命令文件: ~/.claude/commands/"
echo "  - 其他用户自定义配置"
echo ""
echo "⚠️  确认卸载？此操作不可恢复。"
echo ""
echo "请输入 'yes' 确认卸载，或输入 'no' 取消："
```

等待用户输入：
- 输入 `yes` → 继续执行卸载
- 输入其他内容 → 取消卸载，退出

### 第 3 步：执行卸载

```bash
echo ""
echo "🗑️  开始卸载..."
echo ""

# 删除插件缓存
if [ -n "$PLUGIN_CACHE" ]; then
  rm -rf "$PLUGIN_CACHE"
  if [ $? -eq 0 ]; then
    echo "✓ 已删除插件缓存"
  else
    echo "✗ 删除插件缓存失败"
  fi
fi

# 删除已安装插件
if [ -d "$PLUGIN_INSTALLED" ]; then
  rm -rf "$PLUGIN_INSTALLED"
  if [ $? -eq 0 ]; then
    echo "✓ 已删除已安装插件"
  else
    echo "✗ 删除已安装插件失败"
  fi
fi

# 删除 marketplace 源
if [ -d "$PLUGIN_MARKETPLACE" ]; then
  rm -rf "$PLUGIN_MARKETPLACE"
  if [ $? -eq 0 ]; then
    echo "✓ 已删除 Marketplace 源"
  else
    echo "✗ 删除 Marketplace 源失败"
  fi
fi

echo ""
echo "✅ 卸载完成"
```

### 第 4 步：重装提示

```bash
echo ""
echo "📝 如需重新安装，请执行："
echo ""
echo "  /plugin marketplace add doccker/cc-use-exp"
echo "  /plugin install cc-use-exp@cc-use-exp"
echo ""
echo "或访问项目主页："
echo "  https://github.com/doccker/cc-use-exp"
echo ""
```

---

## 注意事项

1. **仅卸载 Plugin Marketplace 安装**：不影响 external 方式安装
2. **保留用户配置**：不删除 `~/.claude/` 下的用户自定义配置
3. **需要二次确认**：防止误操作
4. **清理临时文件**：删除所有插件相关的缓存和临时文件

---

## 卸载后

卸载后，以下内容会被删除：
- `~/.claude/plugins/cache/cc-use-exp/`
- `~/.claude/plugins/installed/cc-use-exp@cc-use-exp/`
- `~/.claude/plugins/marketplaces/cc-use-exp/`

以下内容会保留：
- `~/.claude/CLAUDE.md`
- `~/.claude/rules/`
- `~/.claude/skills/`
- `~/.claude/commands/`
- 其他用户自定义配置
