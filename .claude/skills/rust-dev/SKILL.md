---
name: rust-dev
description: Rust 开发规范（聚焦 Axum + Tokio 后端栈），覆盖工具链、错误处理、异步陷阱、模块组织、依赖管理与测试规范
version: v1.0
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---

# Rust 开发规范

> 参考来源：Rust API Guidelines、Rust Async Book、tokio.rs、Axum 官方示例、Effective Rust

**适用范围**：后端 Web 服务（Axum + Tokio 路线）。CLI/wasm/嵌入式不在本规范覆盖范围内。

---

## 工具链

```bash
# 格式化
cargo fmt --all
# 静态检查，warning 当 error
cargo clippy --all-targets -- -D warnings
# 测试
cargo test --all-features
# CVE 扫描（独立安装）
cargo audit
# 许可证/重复依赖检查（独立安装）
cargo deny check
# 检测未使用依赖
cargo machete
```

**edition**：新项目默认 `edition = "2024"`，老项目保持 `2021` 不强迁。

**版本基线**（写死，避免重复决策）：
- Tokio `1.x`，Axum `0.8`，tower-http `0.6`
- serde `1`、tracing `0.1`、tracing-subscriber `0.3`
- DB：sqlx `0.8`（runtime-tokio-rustls）

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 模块/文件 | snake_case | `user_service.rs` |
| 函数/变量 | snake_case | `fetch_user`, `db_pool` |
| 类型/Trait/Enum | UpperCamelCase | `UserRepo`, `AppError` |
| 常量/静态 | SCREAMING_SNAKE_CASE | `MAX_RETRY` |
| 泛型 | 单大写或 UpperCamelCase | `T`, `Req`, `Resp` |
| 生命周期 | 短小写 | `'a`, `'ctx` |

**禁止**：`common`、`util`、`helper`、`base` 等无意义模块名。模块按职责命名（`api`、`db`、`service`）。

---

## 模块组织

参照 `apple-store-price-rs` / `org-site-backend` 的实证拆分，按职责切文件，**不堆 `lib.rs`**：

```
src/
├── main.rs          # 仅 bootstrap：日志初始化、读配置、建路由、启服务
├── config.rs        # 配置加载（env / toml）
├── error.rs         # AppError + IntoResponse impl
├── db.rs            # 数据库连接池/迁移
├── api.rs           # 路由聚合 + handler
├── service/         # 业务逻辑（无副作用层）
│   └── user.rs
└── models.rs        # 领域类型 + serde 派生
```

**可见性**：`pub(crate)` 优先于 `pub`。只在确实要对外暴露时才用 `pub`。

---

## 错误处理（核心）

**分场景选边**：

| 场景 | 选择 | 理由 |
|------|------|------|
| 库 crate | `thiserror` | 调用方需要按变体匹配 |
| 二进制应用顶层 | `anyhow` | 只关心"成功/失败 + 上下文" |
| 跨边界（handler / 公共 API） | 自定义 `AppError` + `IntoResponse` | 控制对外错误形态 |

**禁止**生产代码出现：
- `.unwrap()` / `.expect()`（仅测试和 `const` 上下文可用）
- `panic!()`（仅用于"逻辑上不可达"且带 SAFETY 注释）

clippy 配置（在 `Cargo.toml` 或 `clippy.toml`）：

```toml
[lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
```

**错误传播用 `?`**，跨类型用 `From` 实现自动转换：

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

详见 `references/async-axum.md` 的 `IntoResponse` 实现。

---

## 异步编程红线

**1. 阻塞调用必须丢到 `spawn_blocking`**

```rust
// ❌ 在 async fn 里直接调用阻塞 API
let data = std::fs::read("big.bin")?;

// ✅
let data = tokio::task::spawn_blocking(|| std::fs::read("big.bin")).await??;
```

判定标准：CPU 密集 > 10ms、`std::fs`、`std::thread::sleep`、同步 DB driver、`reqwest::blocking` —— 都必须 `spawn_blocking`。

**2. 不要跨 `.await` 持有 `std::sync::Mutex`**

```rust
// ❌ 编译能过，运行时死锁/性能崩溃
let g = std_mutex.lock().unwrap();
do_async().await;

// ✅ 用 tokio::sync::Mutex
let g = tokio_mutex.lock().await;
do_async().await;
```

**3. `Rc` / `RefCell` 不能跨 `.await`**：违反 `Send` 边界，编译报错，改用 `Arc` / `Mutex`。

**4. `tokio::select!` 分支必须取消安全**

- 取消安全 ✅：`tokio::time::sleep`、`channel.recv`、`tokio::io::AsyncRead` 标记方法
- 取消不安全 ❌：自己实现的 `async fn`（取消时可能丢数据）

不确定时，把状态保存到 `select!` 外部变量，分支只读写本地变量。

**5. 优雅停机**：用 `tokio::signal::ctrl_c()` + `axum::serve(...).with_graceful_shutdown()`。

更多陷阱见 `references/async-axum.md`。

---

## 所有权与借用最小集

**函数参数**：

| 想要 | 用 | 不要用 |
|------|------|------|
| 只读字符串 | `&str` | `&String` |
| 只读切片 | `&[T]` | `&Vec<T>` |
| 路径 | `&Path` | `&PathBuf` / `&str` |
| 字符串入参可能多种来源 | `impl AsRef<str>` | 多个重载 |

**共享决策树**：

```
需要跨线程共享？
├── 否 → 用 Box<T> 或值传递
└── 是 → Arc<T>
        ├── 不可变共享 → Arc<T>
        ├── 读多写少 → Arc<RwLock<T>>
        └── 读写均衡 → Arc<Mutex<T>>
```

**`Clone` 不是坏事**，但循环内 `Clone` 大对象要警觉，考虑 `Arc` 或 `Cow<'_, T>`。

---

## Axum 实战要点

```rust
type AppState = Arc<InnerState>;

let app = Router::new()
    .nest("/api/users", user::routes())     // 按模块拆 + nest
    .layer(TraceLayer::new_for_http())       // 日志中间件
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .with_state(state);
```

- **State 一律 `Arc` 包装**，不要克隆裸结构体
- **Handler 错误类型实现 `IntoResponse`**，统一对外形态（status + json body）
- **路由按模块拆 `fn routes() -> Router<AppState>`**，避免 `main.rs` 膨胀
- **中间件走 `tower-http`**：CORS / 超时 / 限流 / 日志 / 静态文件

详见 `references/async-axum.md`。

---

## 依赖管理

**版本指定**：`Cargo.toml` 默认 caret（`"1"` 等价 `^1`），不要锁死 `=1.2.3` 除非有兼容性问题。

**features 显式声明**，禁止盲依赖默认值：

```toml
# ✅ 显式开启需要的 feature
tokio = { version = "1", features = ["macros", "rt-multi-thread", "signal"] }
reqwest = { version = "0.12", default-features = false, features = ["json", "rustls-tls"] }
```

**TLS 选 `rustls`**，避免 `openssl`（跨平台编译麻烦）。

**升级前先 dry-run**：

```bash
cargo update --dry-run
# 独立安装
cargo outdated
```

`Cargo.lock` 二进制项目必须提交，库项目不提交。

---

## 测试规范

```rust
// 异步测试用 #[tokio::test]
#[tokio::test]
async fn fetches_user() {
    let svc = test_service().await;
    let user = svc.find(1).await.unwrap();   // 测试代码可以 .unwrap()
    assert_eq!(user.name, "alice");
}

// 表驱动：可选用 rstest crate
#[rstest::rstest]
#[case(1, 2, 3)]
#[case(-1, 1, 0)]
fn adds(#[case] a: i32, #[case] b: i32, #[case] expected: i32) {
    assert_eq!(a + b, expected);
}
```

- **单元测试**：`#[cfg(test)] mod tests { ... }` 紧贴被测代码
- **集成测试**：`tests/` 顶层目录，每个文件独立 crate
- **测试中允许 `.unwrap()`**（失败即测试失败，正是预期）

---

## unsafe 红线

**业务代码原则禁用 `unsafe`**。

如必须使用（FFI / 极端性能场景）：
1. 块前必须有 `// SAFETY: ...` 注释，说明保持的不变量
2. 缩小 `unsafe` 块到最小范围
3. 优先封装成 safe API 对外暴露
4. 走 code review，单独标记审查

---

## 性能要点

| 陷阱 | 解决 |
|------|------|
| 循环内 `format!` / 字符串拼接 | 用 `String::with_capacity` + `write!` |
| Vec 频繁扩容 | `Vec::with_capacity(n)` |
| 循环内 `.clone()` 大对象 | 借用或 `Arc` |
| `Box<dyn Trait>` 滥用 | 优先泛型 `<T: Trait>`（静态分发） |
| `String` 当 key | 优先 `&str` 或 `Cow<'static, str>` |
| 阻塞 IO 在 async 里 | `spawn_blocking`（见异步章节） |

性能分析：

```bash
cargo build --release
# 火焰图（独立安装）
cargo flamegraph
# criterion 基准测试
cargo bench
```

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/rust-style.md` | 命名细则、`From`/`TryFrom` 规范、newtype 模式、迭代器优先 |
| `references/async-axum.md` | spawn_blocking 边界、select! 取消安全、tower 中间件组合、IntoResponse 模式、shutdown 信号 |

---

> 📋 本回复遵循：`rust-dev` - [具体章节]
