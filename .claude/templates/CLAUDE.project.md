# [项目名称] 项目配置

作者：wwj
版本：v1.0
日期：[当前日期]

<!--
使用说明：
1. 复制此文件到项目的 .claude/CLAUDE.md
2. 替换 [方括号] 中的内容
3. 删除不需要的章节
4. 删除所有注释
-->

---

## 项目概述

<!-- 一句话描述项目用途 -->

[项目名称] 是一个 [项目描述]。

---

## 技术栈

<!-- 根据实际技术栈修改 -->

| 层级 | 技术 | 版本 |
|------|------|------|
| 后端 | Go / Java / Node.js | x.x+ |
| Web 框架 | Gin / Spring Boot / Express | x.x+ |
| ORM | GORM / JPA / Prisma | x.x+ |
| 数据库 | SQLite / MySQL / PostgreSQL | x.x |
| 前端框架 | Vue / React | x.x+ |
| 前端语言 | TypeScript | x.x+ |
| UI 组件库 | Element Plus / Ant Design | x.x+ |
| 构建工具 | Vite / Webpack | x.x+ |

---

## 目录结构

<!-- 根据实际项目结构修改 -->

```
项目名/
├── main.go / src/main/java     # 入口文件
├── internal/ / src/            # 业务代码
│   ├── handler/ / controller/  # HTTP 处理器
│   ├── service/                # 业务逻辑
│   ├── repository/ / dao/      # 数据访问
│   └── model/ / entity/        # 数据模型
├── web/ / frontend/            # 前端代码（如有）
│   ├── src/
│   │   ├── components/         # 组件
│   │   ├── views/ / pages/     # 页面
│   │   ├── api/                # API 调用
│   │   └── stores/             # 状态管理
│   └── package.json
├── restart.sh                  # 重启脚本（如有）
└── go.mod / pom.xml / package.json
```

---

## 项目定制

<!-- 这是项目特定的约定，必须遵守 -->

### 开发约定

| 约定 | 说明 |
|------|------|
| 启动方式 | 使用 `./restart.sh` / `docker-compose up` / `npm run dev` |
| 数据库迁移 | GORM AutoMigrate / Flyway / 手动 SQL |
| 注释风格 | 不使用行尾注释，注释单独成行 |
| 作者署名 | 所有文档和代码署名使用 wwj |

<!-- 添加其他项目特定约定 -->

### API 规范

<!-- 如果是后端项目，定义 API 规范 -->

**统一响应格式**：

```go
// Go 示例
type Response struct {
    Code    int         `json:"code"`    // 0 成功，非 0 失败
    Message string      `json:"message"` // 提示信息
    Data    interface{} `json:"data,omitempty"`
}
```

```java
// Java 示例
public class Result<T> {
    private int code;
    private String message;
    private T data;
}
```

**错误码约定**：
- `0`: 成功
- `1xxx`: 参数错误
- `2xxx`: 业务错误
- `5xxx`: 系统错误

### 前端规范

<!-- 如果有前端，定义前端规范 -->

| 约定 | 说明 |
|------|------|
| UI 风格 | [Element Plus / Ant Design] 默认主题 |
| 设计原则 | 降低用户操作费力度，信息密度适中 |
| 避免 | 花哨装饰、渐变背景、复杂动效 |

---

## 常用操作

<!-- 项目常用命令 -->

### 启动/重启服务

```bash
# 重启服务（推荐）
./restart.sh

# 仅编译
go build -o server . / mvn package / npm run build

# 开发模式
cd web && npm run dev
```

### 数据库操作

```bash
# SQLite
sqlite3 data.db
.tables
.schema [表名]

# MySQL
mysql -u root -p [数据库名]
```

---

## 与 Claude Code 协作

### 期望你主动做的

- ✅ 发现代码中的类型错误和潜在 Bug
- ✅ 提示更优雅的写法
- ✅ 补充缺失的异常处理和日志

### 不希望你做的

- ❌ 不要过度重构已经工作的代码
- ❌ 不要添加未要求的功能
- ❌ 不要主动创建文档文件（除非明确要求）

### 禁止事项

<!-- 根据项目情况添加 -->

- ❌ 不要修改 `restart.sh` 的核心逻辑（除非明确要求）
- ❌ 不要直接操作生产数据库
- ❌ 不要在代码中硬编码敏感信息
