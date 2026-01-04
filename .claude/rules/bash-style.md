# Bash 编写规范

版本：v1.0
作者：wwj
更新：2025-12

> **部署位置**: `~/.claude/rules/bash-style.md`
> **生效范围**: Shell 脚本及相关配置文件

---
paths:
  - "**/*.sh"
  - "**/Dockerfile"
  - "**/Makefile"
  - "**/*.yml"
  - "**/*.yaml"
  - "**/*.md"
---

## 适用说明

本规范定义了 Bash 脚本和命令的编写风格，目的是提高可读性、减少复制粘贴错误。

---

## 1. 文件写入方式

### 推荐方式：tee 命令

```bash
# ✅ 推荐：简洁、无嵌套引号
sudo tee /etc/fail2ban/jail.d/docker-nginx.local > /dev/null << 'EOF'
[docker-nginx]
enabled = true
filter = docker-nginx
logpath = /var/log/nginx/access.log
maxretry = 5
EOF
```

### 追加内容

```bash
# ✅ 追加到文件
sudo tee -a /etc/hosts > /dev/null << 'EOF'
192.168.1.100 myserver
EOF

# ✅ 单行追加
echo '192.168.1.100 myserver' | sudo tee -a /etc/hosts
```

### 避免的写法

```bash
# ❌ 避免：嵌套引号复杂，易出错
sudo bash -c 'cat > /etc/xxx << EOF
content
EOF'

# ❌ 避免：需要转义内容中的特殊字符
sudo sh -c "echo 'line1\nline2' > /etc/xxx"
```

### 方式对比

| 方式 | 优点 | 缺点 | 推荐场景 |
|------|------|------|---------|
| `sudo tee` | 简洁、无嵌套 | 需 `> /dev/null` 抑制输出 | **首选** |
| `sudo bash -c 'cat >'` | 无需 tee | 嵌套引号复杂 | 不推荐 |
| 临时文件 + mv | 可先验证 | 步骤多 | 复杂配置 |

---

## 2. Heredoc 引号规则

### 禁止变量展开（推荐默认）

```bash
# ✅ 'EOF' 带引号：内容原样输出，不解析变量
sudo tee /etc/xxx > /dev/null << 'EOF'
$HOME 不会被展开
$(command) 不会被执行
EOF
```

### 需要变量展开

```bash
# EOF 不带引号：变量会被展开
sudo tee /etc/xxx > /dev/null << EOF
当前用户: $USER
当前目录: $(pwd)
EOF
```

### 选择原则

| 场景 | 用法 | 原因 |
|------|------|------|
| 配置文件 | `<< 'EOF'` | 避免意外展开 |
| 模板生成 | `<< EOF` | 需要插入变量 |
| 不确定时 | `<< 'EOF'` | 更安全 |

---

## 3. 权限与路径

### 需要 root 权限

```bash
# ✅ 正确：tee 配合 sudo
echo 'content' | sudo tee /etc/xxx

# ❌ 错误：重定向在 sudo 之外，权限不足
sudo echo 'content' > /etc/xxx
```

### 路径带空格

```bash
# ✅ 正确：双引号包裹路径
sudo tee "/etc/my config/file.conf" > /dev/null << 'EOF'
content
EOF
```

---

## 4. 脚本规范

### 文件头

```bash
#!/usr/bin/env bash
set -euo pipefail

# 脚本说明（一句话）
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

# ✅ 推荐：设置默认值
db_host="${DB_HOST:-localhost}"

# ❌ 避免：裸变量（易与后续字符混淆）
echo "Hello, $name_suffix"
```

---

## 5. 常用模式

### 检查命令是否存在

```bash
if ! command -v docker &> /dev/null; then
    echo "docker 未安装"
    exit 1
fi
```

### 检查文件/目录

```bash
# 文件存在
[[ -f /path/to/file ]] && echo "文件存在"

# 目录存在
[[ -d /path/to/dir ]] || mkdir -p /path/to/dir
```

### 安全删除

```bash
# ✅ 使用变量时防止误删
rm -rf "${dir:?}"/*

# ❌ 危险：变量为空时会删除根目录
rm -rf $dir/*
```

---

## 6. 文档中的代码块

在 Markdown 文档中编写 bash 命令时，同样遵循以上规范：

````markdown
## 安装配置

创建配置文件：

```bash
sudo tee /etc/myapp/config.yml > /dev/null << 'EOF'
server:
  port: 8080
  host: 0.0.0.0
EOF
```
````

---

## 规则溯源要求

当回复明确受到本规则约束时，在回复末尾声明：

```
> 📋 本回复遵循规则：`bash-style.md` - [具体章节]
```

---

## 参考资料

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [ShellCheck](https://www.shellcheck.net/)
