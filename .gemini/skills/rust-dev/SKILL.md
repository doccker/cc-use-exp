---
name: rust-dev
description: Rust 开发规范（聚焦 Axum + Tokio 后端栈），包含错误处理、异步陷阱、模块组织、测试规范等。当操作 .rs、Cargo.toml、Cargo.lock 文件时自动激活。
---

# Rust 开发规范

> 参考来源: Rust API Guidelines、Rust Async Book、tokio.rs、Axum 官方示例

**适用范围**：后端 Web 服务（Axum + Tokio 路线）。CLI/wasm/嵌入式不在覆盖范围内。

---

## 🛠️ 工具链

```bash
# 格式化
cargo fmt --all
# 静态检查，warning 当 error
cargo clippy --all-targets -- -D warnings
# 测试
cargo test --all-features
```

**版本基线**（以 2026-05 为准，半年后重新校准）：edition 2024、Tokio 1.x、Axum 0.8、tower-http 0.6、sqlx 0.8。

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 模块/文件 | snake_case | `user_service.rs` |
| 函数/变量 | snake_case | `fetch_user`, `db_pool` |
| 类型/Trait/Enum | UpperCamelCase | `UserRepo`, `AppError` |
| 常量/静态 | SCREAMING_SNAKE_CASE | `MAX_RETRY` |

**禁止**: `common`、`util`、`helper`、`base` 等无意义模块名。

---

## 错误处理

**分场景选边**：库用 `thiserror`，二进制应用用 `anyhow`，跨边界（handler）用自定义 `AppError + IntoResponse`。

```rust
#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("db error: {0}")]
    Db(#[from] sqlx::Error),
    #[error("not found")]
    NotFound,
    #[error("bad request: {0}")]
    BadRequest(String),
}
```

**禁止**生产代码：`.unwrap()` / `.expect()` / `panic!()`（仅测试可用）。clippy 配置：

```toml
[lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
```

---

## 异步编程红线

- **阻塞调用必须 `spawn_blocking`**：CPU > 10ms、`std::fs`、同步 DB driver 都不能直接进 async fn
- **不要跨 `.await` 持有 `std::sync::Mutex`**：用 `tokio::sync::Mutex`
- **`Rc`/`RefCell` 不能跨 `.await`**：违反 Send 边界，改 `Arc` / 缩小作用域
- **`tokio::select!` 分支必须取消安全**：不确定时把状态保存到 `select!` 外部

```rust
// ✅ 阻塞调用包到 spawn_blocking
let data = tokio::task::spawn_blocking(|| std::fs::read("big.bin")).await??;
```

---

## Axum 实战要点

- **State 一律 `Arc` 包装**，不要克隆裸结构体
- **Handler 错误类型实现 `IntoResponse`**，统一对外 status + json
- **路由按模块拆 `fn routes() -> Router<AppState>`** + `Router::nest`
- **超时/限流/日志/CORS 走 tower-http 中间件**

---

## 性能优化建议

| 场景 | 解决方案 |
|------|---------|
| 循环内字符串拼接 | `String::with_capacity` + `push_str` |
| Vec 频繁扩容 | `Vec::with_capacity(n)` |
| 循环内 `.clone()` 大对象 | 借用或 `Arc<T>` |
| `Box<dyn Trait>` 滥用 | 优先泛型 `<T: Trait>` 静态分发 |
| 阻塞 IO 在 async 里 | `tokio::task::spawn_blocking` |

---

## unsafe 红线

业务代码原则禁用 `unsafe`。必须用时（FFI / 极端性能）：
- 块前必须有 `// SAFETY: ...` 注释，说明保持的不变量
- 缩小 `unsafe` 块到最小范围，封装成 safe API 对外暴露

---

> 📋 本回复遵循：`rust-dev` - [章节]
