---
description: 扫描项目生成配置（CLAUDE.md/restart.sh/ignore/Docker）
---

扫描当前项目，自动识别技术栈并生成全套配置文件。

## ⚠️ 必须生成以下所有文件

| 序号 | 文件 | 用途 | 模板位置 |
|------|------|------|---------|
| 1 | `.claude/CLAUDE.md` | 项目配置 | 直接生成 |
| 2 | `restart.sh` | 前后端打包+启动脚本 | 直接生成 |
| 3 | `.claudeignore` | Claude Code 忽略 | 直接生成 |
| 4 | `.geminiignore` | Gemini CLI 忽略 | **必须生成**，内容复制自 `.claudeignore` |
| 5 | `.gitignore` | Git 忽略 | 直接生成 |
| 6 | `.dockerignore` | Docker 忽略 | 直接生成 |
| 7 | `Dockerfile` | 容器构建 | 直接生成 |
| 8 | `docker-compose.yml` | 容器编排 | 直接生成 |
| 9 | `README.md` | 项目说明 | 直接生成（如不存在或用户选择覆盖） |

---

## 忽略文件内容规范

### .claudeignore / .geminiignore（必须包含）

```
# 依赖目录
node_modules/
vendor/

# 构建产物
dist/
build/
*.exe

# IDE 和编辑器
.idea/
.vscode/
*.swp

# 系统文件
.DS_Store
Thumbs.db

# 日志和临时文件
*.log
tmp/

# MCP 插件缓存
.playwright-mcp/

# 数据库文件（按需）
*.db
*.sqlite
```

### .gitignore（在上述基础上增加）

```
# 环境配置
.env
.env.local

# 敏感文件
*.pem
*.key
```

### .dockerignore（在上述基础上增加）

```
# Git
.git/
.gitignore

# 文档
*.md
LICENSE

# 测试
*_test.go
__tests__/
```

---

## 执行步骤

### 步骤 1：扫描项目类型

检测文件确定技术栈：

| 检测文件 | 项目类型 |
|---------|---------|
| `go.mod` | Go |
| `pom.xml` | Java + Maven |
| `build.gradle` | Java + Gradle |
| `package.json` | Node.js / 前端 |
| `web/` 或 `frontend/` 目录 | 前后端分离 |

检测数据库依赖（在 go.mod 或代码中搜索）：

| 关键词 | 依赖 |
|--------|------|
| `sqlite` | SQLite |
| `mysql` | MySQL |
| `postgres` | PostgreSQL |
| `redis`, `go-redis` | Redis |

### 步骤 2：显示扫描结果并确认

```
## 项目扫描结果

**项目类型**: [检测结果]
**数据库**: [检测结果]
**前后端分离**: [是/否]

即将生成 9 个文件，是否继续？[Y/n]
```

### 步骤 3：逐个生成文件

对于每个文件：

1. **检查是否存在**
2. **如已存在** → 询问用户：
   ```
   文件 [filename] 已存在，请选择：
   1. 覆盖
   2. 跳过
   ```
3. **如不存在** → 读取对应模板，根据项目类型调整后生成

**模板选择规则**：

| 项目类型 | restart.sh | Dockerfile | docker-compose.yml |
|---------|------------|------------|-------------------|
| Go | `restart-go.sh.tmpl` | `Dockerfile-go.tmpl` | 根据数据库选择 |
| Go + 前端 | `restart-go.sh.tmpl` | `Dockerfile-go-frontend.tmpl` | 根据数据库选择 |
| Java | `restart-java.sh.tmpl` | 自行生成 | 根据数据库选择 |

| 数据库 | docker-compose 模板 |
|--------|-------------------|
| SQLite | `docker-compose-sqlite.yml.tmpl` |
| MySQL | `docker-compose-mysql.yml.tmpl` |
| Redis | `docker-compose-redis.yml.tmpl` |
| MySQL + Redis | 合并两个模板 |

### 步骤 4：设置执行权限

```bash
chmod +x restart.sh
```

### 步骤 5：输出摘要

```
## 生成完成

已生成文件：
✅ .claude/CLAUDE.md
✅ restart.sh
✅ .claudeignore
✅ .geminiignore
✅ .gitignore
✅ .dockerignore
✅ Dockerfile
✅ docker-compose.yml
✅ README.md

跳过文件：
⏭️ [用户选择跳过的文件]

下一步：
1. 检查生成的文件是否符合项目实际情况
2. 修改 docker-compose.yml 中的默认密码
3. 测试 ./restart.sh 是否正常工作
```

---

## restart.sh 使用说明

```bash
# 默认管理员账密
./restart.sh

# 自定义管理员账密
ADMIN_USER=myuser ADMIN_PASS=mypass ./restart.sh
```

---

## 注意事项

- 生成后务必检查文件内容是否符合项目实际
- `docker-compose.yml` 中的密码应在生产环境修改
- 如项目结构特殊，可能需要手动调整模板

---

## README.md 生成规范

### ⚠️ 增量更新原则（重要）

**如果 README.md 已存在**，必须遵循以下规则：

1. **读取现有内容**，识别 `<!-- AUTO:xxx -->` 标记的区块
2. **只更新标记区块**内的内容，保留区块外的手写内容
3. **无标记区块时**，询问用户：
   ```
   README.md 已存在且无自动更新标记。请选择：
   1. 全量覆盖（推荐首次使用）
   2. 追加标记区块到文件末尾
   3. 跳过 README.md
   ```

### 可用的标记区块

| 标记 | 内容 | 说明 |
|------|------|------|
| `<!-- AUTO:tech-stack -->` | 技术栈表格 | 自动检测语言、框架、数据库版本 |
| `<!-- AUTO:directory -->` | 项目结构 | 扫描目录生成树形结构 |
| `<!-- AUTO:quick-start -->` | 快速开始 | 环境要求、启动命令 |
| `<!-- AUTO:docker -->` | Docker 部署 | docker-compose 命令 |

### 标记区块格式

```markdown
<!-- AUTO:tech-stack -->
## 技术栈
| 层级 | 技术 | 版本 |
|------|------|------|
| 框架 | Gin | 1.9 |
...
<!-- /AUTO:tech-stack -->
```

### 更新逻辑

```
1. 读取现有 README.md
2. 用正则匹配 <!-- AUTO:xxx --> ... <!-- /AUTO:xxx -->
3. 替换匹配区块内的内容
4. 保留区块外的所有手写内容
5. 写回文件
```

### 首次生成的章节模板

```markdown
# [项目名称]

## 项目概述

<!-- 手写区域：根据代码分析生成项目描述 -->

### 核心功能

- **功能1**: 描述
- **功能2**: 描述
...

<!-- AUTO:tech-stack -->
## 技术栈

### 后端

| 层级 | 技术 | 版本 |
|------|------|------|
| 框架 | [检测到的框架] | [版本] |
| 语言 | [Go/Java/...] | [版本] |
| ORM | [检测到的ORM] | [版本] |
| 数据库 | [检测到的数据库] | [版本] |
| 缓存 | [如有] | [版本] |
| 构建 | [Maven/Go/...] | - |

### 前端（如有）

| 层级 | 技术 | 版本 |
|------|------|------|
| 框架 | [Vue/React/...] | [版本] |
| 语言 | TypeScript | [版本] |
| UI 组件库 | [Element Plus/Ant Design/...] | [版本] |
| 构建 | Vite | [版本] |
<!-- /AUTO:tech-stack -->

<!-- AUTO:directory -->
## 项目结构

```
[项目名]/
├── [目录1]/                # 说明
├── [目录2]/                # 说明
└── ...
```
<!-- /AUTO:directory -->

<!-- AUTO:quick-start -->
## 快速开始

### 环境要求

- [语言] [版本]+
- [数据库] [版本]+
- Node.js 18+ (前端开发，如有)

### 后端启动

```bash
# 克隆项目
git clone <repository-url>
cd [项目名]

# [根据项目类型生成启动命令]
```

### 前端启动（如有）

```bash
cd [前端目录]
npm install
npm run dev
```

### 访问地址

| 服务 | 地址 |
|------|------|
| 前端 | http://localhost:[端口] |
| 后端 API | http://localhost:[端口]/api |
<!-- /AUTO:quick-start -->

<!-- AUTO:docker -->
## Docker 部署

```bash
# 启动
docker-compose up -d
```
<!-- /AUTO:docker -->

## 许可证

[LICENSE](./LICENSE)
```

### 生成原则

1. **版本号**：从 `go.mod`、`pom.xml`、`package.json` 中提取
2. **项目结构**：扫描实际目录生成，只列出主要目录
3. **端口号**：从配置文件中提取，或使用默认值
4. **功能描述**：根据代码结构和命名推断
