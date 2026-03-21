---
name: /project-scan
id: project-scan
category: 初始化
description: 扫描项目生成全套配置（Cursor rules / restart.sh / ignore / Docker）
---

扫描当前项目，自动识别技术栈并生成全套配置文件。

## 必须生成以下所有文件

| 序号 | 文件 | 用途 |
|------|------|------|
| 1 | `.cursor/rules/project.mdc` | 项目级 Cursor 规则 |
| 2 | `restart.sh` | 前后端打包+启动脚本 |
| 3 | `.gitignore` | Git 忽略 |
| 4 | `.dockerignore` | Docker 忽略 |
| 5 | `Dockerfile` | 容器构建 |
| 6 | `docker-compose.yml` | 容器编排 |
| 7 | `README.md` | 项目说明（如不存在或用户选择覆盖） |

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

检测数据库依赖（在配置文件或代码中搜索 sqlite/mysql/postgres/redis）。

### 步骤 2：显示扫描结果并确认

```
## 项目扫描结果

**项目类型**: [检测结果]
**数据库**: [检测结果]
**前后端分离**: [是/否]

即将生成 7 个文件，是否继续？[Y/n]
```

### 步骤 3：逐个生成文件

对于每个文件：
1. 检查是否存在
2. 如已存在 → 询问用户：覆盖 / 跳过
3. 如不存在 → 根据项目类型生成

### 步骤 4：设置执行权限

```bash
chmod +x restart.sh
```

### 步骤 5：输出摘要

```
## 生成完成

已生成文件：
✅ .cursor/rules/project.mdc
✅ restart.sh
✅ .gitignore
✅ .dockerignore
✅ Dockerfile
✅ docker-compose.yml
✅ README.md

下一步：
1. 检查生成的文件是否符合项目实际情况
2. 修改 docker-compose.yml 中的默认密码
3. 测试 ./restart.sh 是否正常工作
```

---

## README.md 生成规范

### 增量更新原则

**如果 README.md 已存在**：
1. 读取现有内容，识别 `<!-- AUTO:xxx -->` 标记的区块
2. 只更新标记区块内的内容，保留区块外的手写内容
3. 无标记区块时，询问用户选择：全量覆盖 / 追加标记区块 / 跳过

### 可用的标记区块

| 标记 | 内容 |
|------|------|
| `<!-- AUTO:tech-stack -->` | 技术栈表格 |
| `<!-- AUTO:directory -->` | 项目结构 |
| `<!-- AUTO:quick-start -->` | 快速开始 |
| `<!-- AUTO:docker -->` | Docker 部署 |
