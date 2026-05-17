# Rust 异步与 Axum

- Tokio 1.x，features 显式声明 `["macros", "rt-multi-thread", "signal"]`。
- 阻塞调用（`std::fs`、同步 DB、CPU > 10ms）必须 `tokio::task::spawn_blocking`。
- 跨 `.await` 持锁用 `tokio::sync::Mutex`，不用 `std::sync::Mutex`；`Rc`/`RefCell` 不能跨 `.await`。
- `tokio::select!` 分支必须取消安全；不确定时把状态保存到 `select!` 外部，分支只读写本地变量。
- 优雅停机：`tokio::signal::ctrl_c()` + `axum::serve(...).with_graceful_shutdown()`。
- Axum 0.8：State 一律 `Arc` 包装；handler 错误实现 `IntoResponse`；路由按模块拆 `fn routes() -> Router<AppState>` + `Router::nest`。
- 超时/限流/CORS/日志走 tower-http 中间件（`TimeoutLayer`、`RequestBodyLimitLayer`、`CorsLayer`、`TraceLayer`）。
- `reqwest::Client` 全局复用（连接池在内部），禁止每次请求新建。
