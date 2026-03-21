---
name: bash-style
description: >-
  Bash 编写规范。当用户操作 .sh、Dockerfile、Makefile、.yml、.yaml 文件，
  或在 Markdown 中编写 bash/shell 代码块时触发。
  包含注释规范、文件写入方式、Heredoc 引号规则、权限路径、脚本规范等。
---

# Bash 编写规范

---

## 1. 注释规范

### 禁止行尾注释

- ❌ **禁止行尾注释**（如 `command # 注释`）
- ✅ 注释应独占一行，放在代码上方

```bash
# ❌ 错误：行尾注释
curl -X POST https://api.example.com/data # 发送请求

# ✅ 正确：注释独占一行
# 发送请求
curl -X POST https://api.example.com/data
```

---

## 2. 文件写入方式

### 推荐方式：tee 命令

```bash
# ✅ 推荐：简洁、无嵌套引号
sudo tee /etc/myapp/config.yml > /dev/null << 'EOF'
server:
  port: 8080
EOF
```

### 方式对比

| 方式 | 优点 | 缺点 | 推荐场景 |
|------|------|------|---------|
| `sudo tee` | 简洁、无嵌套 | 需 `> /dev/null` 抑制输出 | **首选** |
| `sudo bash -c 'cat >'` | 无需 tee | 嵌套引号复杂 | 不推荐 |

---

## 3. Heredoc 引号规则

| 场景 | 用法 | 原因 |
|------|------|------|
| 配置文件 | `<< 'EOF'` | 避免意外展开 |
| 模板生成 | `<< EOF` | 需要插入变量 |
| 不确定时 | `<< 'EOF'` | 更安全 |

---

## 4. 权限与路径

```bash
# ✅ 正确：tee 配合 sudo
echo 'content' | sudo tee /etc/xxx

# ❌ 错误：重定向在 sudo 之外，权限不足
sudo echo 'content' > /etc/xxx
```

---

## 5. 脚本规范

### 文件头

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### set 选项说明

| 选项 | 作用 |
|------|------|
| `-e` | 命令失败时退出 |
| `-u` | 使用未定义变量时报错 |
| `-o pipefail` | 管道中任一命令失败则整体失败 |

### 变量使用

```bash
# ✅ 推荐：使用 ${} 包裹
echo "Hello, ${name}"
db_host="${DB_HOST:-localhost}"

# ❌ 避免：裸变量
echo "Hello, $name_suffix"
```

---

## 6. 常用模式

```bash
# 检查命令是否存在
if ! command -v docker &> /dev/null; then
    echo "docker 未安装"
    exit 1
fi

# 安全删除
rm -rf "${dir:?}"/*
```
