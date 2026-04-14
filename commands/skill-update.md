---
description: 更新 cc-use-exp 配置体系到最新版本
---

# cc-use-exp 更新器

更新已安装的 cc-use-exp 配置体系到最新版本。

---

## 执行步骤

### 第 1 步：检查安装状态

```bash
INSTALL_DIR="$HOME/.claude/external/cc-use-exp"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "❌ 未检测到安装"
  echo ""
  echo "请先执行 /skill-install 安装配置体系"
  exit 1
fi

echo "📦 检查更新..."
echo ""

cd "$INSTALL_DIR"

# 检查是否是 Git 仓库
if [ ! -d ".git" ]; then
  echo "❌ 错误：安装目录不是 Git 仓库"
  echo "建议重新安装：/skill-install"
  exit 1
fi
```

### 第 2 步：显示当前版本

```bash
echo "当前版本:"
git log -1 --pretty=format:"%h - %s (%ar)" 2>/dev/null
echo ""
echo ""

# 获取远程更新
git fetch origin main

# 检查是否有更新
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "✅ 已是最新版本，无需更新"
  exit 0
fi

echo "🔄 发现新版本，准备更新..."
echo ""
```

### 第 3 步：显示变更摘要

```bash
echo "📝 变更摘要:"
echo ""
git log --oneline HEAD..origin/main | head -10
echo ""

# 如果变更超过 10 条，显示提示
CHANGE_COUNT=$(git rev-list --count HEAD..origin/main)
if [ "$CHANGE_COUNT" -gt 10 ]; then
  echo "（共 $CHANGE_COUNT 个变更，仅显示最近 10 个）"
  echo ""
fi
```

### 第 4 步：拉取最新代码

```bash
echo "⬇️  拉取最新代码..."
echo ""

git pull origin main

if [ $? -ne 0 ]; then
  echo "❌ 更新失败"
  echo ""
  echo "可能原因："
  echo "  1. 网络连接问题"
  echo "  2. 本地有未提交的修改"
  echo "  3. 合并冲突"
  echo ""
  echo "建议："
  echo "  - 检查网络连接"
  echo "  - 或重新安装：/skill-install"
  exit 1
fi

echo "✓ 代码更新完成"
```

### 第 5 步：重新同步配置

```bash
echo ""
echo "🔧 重新同步配置..."
echo ""

if [ -f "./tools/sync-config.sh" ]; then
  ./tools/sync-config.sh
else
  echo "❌ 错误：找不到同步脚本"
  exit 1
fi
```

### 第 6 步：显示更新结果

```bash
echo ""
echo "✅ 更新完成！"
echo ""
echo "📝 新版本:"
git log -1 --pretty=format:"%h - %s (%ar)"
echo ""
echo ""
echo "🔄 配置已生效，无需重启"
echo ""
echo "💡 提示："
echo "  - 查看完整变更：cd $INSTALL_DIR && git log"
echo "  - 查看状态：/status"
echo ""
echo "📖 文档：https://github.com/doccker/cc-use-exp"
```

---

## 错误处理

**未安装**：
```bash
if [ ! -d "$INSTALL_DIR" ]; then
  echo "❌ 未检测到安装，请先执行："
  echo "  /skill-install"
  exit 1
fi
```

**网络错误**：
```bash
if ! git pull origin main; then
  echo "❌ 网络错误，请检查："
  echo "  1. 网络连接是否正常"
  echo "  2. 是否可以访问 GitHub"
  echo "  3. 是否需要配置代理"
  exit 1
fi
```

**本地修改冲突**：
```bash
# 如果有本地修改，提示用户
if ! git diff-index --quiet HEAD --; then
  echo "⚠️  检测到本地修改"
  echo ""
  echo "建议："
  echo "  1. 备份本地修改"
  echo "  2. 重新安装：/skill-install"
  exit 1
fi
```

---

## 注意事项

- 更新前会显示变更摘要
- 自动重新同步配置到 `~/.claude/`
- 如果本地有修改，建议重新安装
- 更新后配置立即生效，无需重启

---

## 规则溯源

```
> 📋 本回复遵循：`skill-update` - cc-use-exp 更新器
```
