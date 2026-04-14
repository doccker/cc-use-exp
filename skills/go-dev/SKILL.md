---
name: go-dev
description: Go 开发规范，包含命名约定、错误处理、并发编程、测试规范等
version: v3.0
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---

# Go 开发规范

> 参考来源: Effective Go、Go Code Review Comments、uber-go/guide

---

## 工具链

```bash
goimports -w .                    # 格式化并整理 import
go vet ./...                      # 静态分析
golangci-lint run                 # 综合检查
go test -v -race -cover ./...     # 测试（含竞态检测和覆盖率）
```

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 包名 | 小写单词，不用下划线 | `user`, `orderservice` |
| 变量/函数 | 驼峰命名，缩写词一致大小写 | `userID`, `HTTPServer` |
| 常量 | 导出用驼峰，私有可驼峰或全大写 | `MaxRetryCount` |
| 接口 | 单方法用方法名+er | `Reader`, `Writer` |

**禁止**: `common`, `util`, `base` 等无意义包名

---

## import 顺序

```go
import (
    "context"           // 标准库
    "fmt"

    "github.com/gin-gonic/gin"  // 第三方库

    "project/internal/model"     // 项目内部
)
```

---

## 错误处理

**必须处理错误**，不能忽略：

```go
// ✅ 好：添加上下文
if err != nil {
    return fmt.Errorf("failed to query user %d: %w", userID, err)
}

// ❌ 差：忽略错误
result, _ := doSomething()
```

**错误包装**: 使用 `%w` 保留错误链，用 `errors.Is()` / `errors.As()` 检查

---

## 并发编程

**基本原则**:
- 优先使用 channel 通信
- 启动 goroutine 前考虑：谁来等待它？怎么停止它？
- 使用 `context.Context` 控制生命周期

```go
// ✅ 好：使用 context 控制
func process(ctx context.Context) error {
    done := make(chan error, 1)
    go func() { done <- doWork() }()

    select {
    case err := <-done:
        return err
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

**数据竞争**: 使用 `go test -race` 检测

---

## 测试规范

```go
// 表驱动测试
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"zero", 0, 0, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

---

## 性能优化

| 陷阱 | 解决方案 |
|------|---------|
| 循环中拼接字符串 | 使用 `strings.Builder` |
| 未预分配 slice | `make([]T, 0, cap)` |
| N+1 查询 | 批量查询 + 预加载 |
| 无限制并发 | 使用 semaphore 或 worker pool |
| Raw SQL 别名用了保留字 | 避免 `year_month`/`order`/`status`/`rank` 等 MySQL 保留字做别名 |

```bash
# 性能分析
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof
```

---

## 项目结构

```
project/
├── cmd/                    # 可执行文件入口
├── internal/               # 私有代码
│   ├── handler/
│   ├── service/
│   ├── repository/
│   └── model/
├── pkg/                    # 公共代码
├── go.mod
└── go.sum
```

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/go-style.md` | 命名约定、错误处理、并发、测试、性能 |
| `references/date-time.md` | 日期加减、账期计算、AddDate 溢出处理 |

---

> 📋 本回复遵循：`go-dev` - [具体章节]
