# Rust 测试

- 异步测试用 `#[tokio::test]`，测试代码允许 `.unwrap()`（失败即测试失败）。
- 单元测试：`#[cfg(test)] mod tests { ... }` 紧贴被测代码。
- 集成测试：`tests/` 顶层目录，每个文件独立 crate。
- 表驱动测试可用 `rstest` crate（`#[rstest::rstest]` + `#[case(...)]`）。
- Axum 测试：`tower::ServiceExt::oneshot` 直接打到 Router；或 `TcpListener::bind("127.0.0.1:0")` 启真实端口配合 `reqwest`。
- 数据竞争靠编译期 Send/Sync 检查；运行时并发问题用 `loom` 验证（必要时）。
