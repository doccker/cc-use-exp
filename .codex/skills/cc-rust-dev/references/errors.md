# Rust 错误处理

- 库 crate 用 `thiserror` 派生错误枚举。
- 二进制应用顶层用 `anyhow::Result`，保留上下文。
- 跨边界（HTTP handler、公共 API）自定义 `AppError` 并实现 `IntoResponse`。
- 生产代码禁止 `.unwrap()` / `.expect()` / `panic!()`，仅测试可用。
- clippy 配置 `unwrap_used = "deny"` / `expect_used = "deny"` / `panic = "deny"`。
- 错误传播用 `?`，跨类型用 `#[from]` 自动实现 `From`。
- 5xx 错误只在 server 端记日志，不把内部细节回给客户端；4xx 可回原因。
