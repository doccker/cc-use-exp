---
applyTo: "**/*.rs,**/Cargo.toml,**/Cargo.lock"
---

Rust 相关任务遵守以下约定（聚焦后端 Web，Axum + Tokio 路线）：

- 模块按职责拆 `.rs` 文件（api/db/service/models/error/config），不堆 `lib.rs`；`pub(crate)` 优先于 `pub`。
- 错误：库用 `thiserror`，二进制应用用 `anyhow`，跨边界统一 `AppError` 并实现 `IntoResponse`。
- 生产代码禁止 `.unwrap()` / `.expect()` / `panic!()`；配置 `clippy::unwrap_used = deny`。
- 异步：阻塞调用必须 `tokio::task::spawn_blocking`；跨 `.await` 的锁用 `tokio::sync::Mutex`，不用 `std::sync::Mutex`。
- `tokio::select!` 分支必须取消安全；不确定时把状态保存到 `select!` 外部。
- 默认 `edition = "2024"`，老项目保持 2021 不强迁；TLS 选 `rustls`。
- 业务代码原则禁用 `unsafe`；必须用时块前补 `// SAFETY:` 注释说明不变量。
