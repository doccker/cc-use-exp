---
name: cc-rust-dev
description: Rust 开发规范（Axum + Tokio 后端栈），适用于 Rust 源码、模块组织、错误处理、异步编程和测试相关任务；不负责 review、debug 或运维流程。
---

# CC Rust Dev

在编辑或审查 Rust 代码时使用本技能，重点处理 idiomatic Rust、模块拆分、错误处理（thiserror/anyhow）、Tokio 异步陷阱、Axum 路由组织与测试。

不要用于：

- 正式 review 或 fix/debug 工作流
- 运维风险判断
- 与 Rust 无关的通用改动边界
- wasm / CLI / 嵌入式场景（本技能聚焦后端 Web）

## 核心规则

- 模块按职责拆 `.rs` 文件，不堆 `lib.rs`；`pub(crate)` 优先于 `pub`。
- 错误：库用 `thiserror`，应用用 `anyhow`，跨边界统一 `AppError + IntoResponse`。
- 生产代码禁止 `.unwrap()` / `.expect()` / `panic!()`；配置 clippy deny。
- 异步：阻塞调用必须 `tokio::task::spawn_blocking`；跨 `.await` 的锁用 `tokio::sync::Mutex`。
- `tokio::select!` 分支必须取消安全；不确定时把状态保存到 `select!` 外部。
- 默认 `edition = "2024"`，TLS 选 `rustls`；业务代码原则禁用 `unsafe`。

## 按需展开

- 风格：`references/style.md`
- 错误处理：`references/errors.md`
- 异步与 Axum：`references/async.md`
- 测试：`references/testing.md`
- 项目结构：`references/project-shape.md`
