---
name: go-dev
description: Go 开发规范，包含命名约定、错误处理、并发编程、测试规范等。当操作 .go, go.mod, go.sum 文件时自动激活。
---
<instructions>

# Go 开发规范

> 参考来源: Effective Go、Go Code Review Comments、uber-go/guide

---

## 🛠️ 工具链

```bash
goimports -w .                    # 格式化并整理 import
go vet ./...                      # 静态分析
golangci-lint run                 # 综合检查（推荐）
go test -v -race -cover ./...     # 测试（含竞态检测和覆盖率）
```

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 包名 | 小写单词，不用下划线 | `user`, `orderservice` |
| 变量/函数 | 驼峰命名，缩写词一致大小写 | `userID`, `HTTPServer` |
| 接口 | 单方法用方法名+er | `Reader`, `Writer` |

**禁止**: `common`, `util`, `base` 等无意义包名。

---

## 错误处理

**必须处理错误**，严禁忽略：

```go
// ✅ 好：添加上下文包装
if err != nil {
    return fmt.Errorf("failed to query user %d: %w", userID, err)
}

// ❌ 差：忽略错误
result, _ := doSomething()
```

**错误包装**: 使用 `%w` 保留错误链，用 `errors.Is()` / `errors.As()` 检查。

---

## 并发编程核心原则

- 优先使用 channel 通信。
- 启动 goroutine 前必须明确：谁来等待它结束？如何通知它停止？
- 必须使用 `context.Context` 控制生命周期。

```go
// ✅ 使用 context 控制协程
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

---

## 性能优化建议

| 场景 | 解决方案 |
|------|---------|
| 循环中拼接字符串 | 使用 `strings.Builder` |
| 未预分配 slice | `make([]T, 0, cap)` |
| N+1 查询 | 批量查询 + 内存匹配 |
| 无限制并发 | 使用 semaphore 或 worker pool |

---

> 📋 本回复遵循：`go-dev` - [章节]

</instructions>