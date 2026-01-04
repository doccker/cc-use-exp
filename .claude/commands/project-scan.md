---
description: 扫描已有项目并生成 CLAUDE.md 配置
allowed-tools: Read, Glob, Grep, Bash(ls:*), Bash(cat:*), Bash(head:*)
---

扫描当前项目，自动识别技术栈并生成 `.claude/CLAUDE.md` 配置。

## 扫描步骤

### 1. 识别项目类型

检查以下文件确定技术栈：

| 文件 | 技术栈 |
|------|--------|
| `go.mod` | Go |
| `pom.xml` | Java + Maven |
| `build.gradle` | Java + Gradle |
| `package.json` | Node.js / 前端 |
| `requirements.txt` | Python |
| `Cargo.toml` | Rust |

### 2. 识别框架

**Go 项目**：
- 检查 `go.mod` 中的依赖：`gin`、`echo`、`fiber`、`gorm` 等

**Java 项目**：
- 检查 `pom.xml` 或 `build.gradle` 中的依赖：`spring-boot`、`mybatis` 等

**前端项目**：
- 检查 `package.json` 中的依赖：`vue`、`react`、`element-plus`、`ant-design` 等

### 3. 识别目录结构

扫描项目根目录，识别：
- 源码目录：`src/`、`internal/`、`pkg/`、`web/`
- 配置文件：`config/`、`.env`、`application.yml`
- 测试目录：`test/`、`tests/`、`__tests__/`
- 脚本文件：`restart.sh`、`Makefile`、`docker-compose.yml`

### 4. 识别启动方式

按优先级检查：
1. `restart.sh` → `./restart.sh`
2. `docker-compose.yml` → `docker-compose up`
3. `Makefile` → 检查 `run` 或 `dev` 目标
4. `package.json` scripts → `npm run dev`
5. `go.mod` → `go run main.go`
6. `pom.xml` → `mvn spring-boot:run`

### 5. 生成配置

基于扫描结果，生成 `.claude/CLAUDE.md`：

```markdown
# [项目名] 项目配置

作者：wwj

## 项目概述

[根据 README.md 或目录结构推断]

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| [识别到的技术栈] |

## 目录结构

[扫描到的目录结构]

## 项目定制

| 约定 | 说明 |
|------|------|
| 启动方式 | [识别到的启动方式] |
| [其他识别到的约定] |

## 与 Claude Code 协作

[标准模板]
```

## 输出

1. 显示扫描结果摘要
2. 生成 `.claude/CLAUDE.md` 文件
3. 提示用户检查并调整

## 注意

- 如果已存在 `.claude/CLAUDE.md`，先询问是否覆盖
- 无法识别的部分用 `[待补充]` 标记
- 生成后提示用户检查技术栈版本是否正确
