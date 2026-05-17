# Async + Axum 实战

> 配合 `SKILL.md` 使用。本文是 Tokio + Axum 后端栈的踩坑手册和模板代码。

---

## Tokio 运行时配置

```rust
// main.rs
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let state = AppState::new().await?;
    let app = build_router(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    tracing::info!("listening on {}", listener.local_addr()?);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.expect("install ctrl_c handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    tracing::info!("shutdown signal received");
}
```

**features 选择**：

```toml
tokio = { version = "1", features = ["macros", "rt-multi-thread", "signal"] }
```

- `rt-multi-thread`：多线程运行时（生产默认）
- 单测可用 `rt`（单线程，更确定）

---

## Axum 路由组织

**按模块拆 `fn routes()`，main 仅做组合**：

```rust
// src/user/mod.rs
pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/", get(list_users).post(create_user))
        .route("/:id", get(get_user).put(update_user).delete(delete_user))
}

// src/main.rs
let app = Router::new()
    .nest("/api/users", user::routes())
    .nest("/api/orders", order::routes())
    .layer(TraceLayer::new_for_http())
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .with_state(state);
```

---

## State 一律 Arc 包装

```rust
#[derive(Clone)]
pub struct AppState {
    pub db: Arc<sqlx::SqlitePool>,
    pub http: Arc<reqwest::Client>,
    pub cfg: Arc<Config>,
}

// handler 提取
async fn list_users(State(state): State<AppState>) -> Result<Json<Vec<User>>, AppError> {
    let users = sqlx::query_as::<_, User>("SELECT * FROM users")
        .fetch_all(state.db.as_ref())
        .await?;
    Ok(Json(users))
}
```

**不要**：克隆裸结构体；用 `Arc<Mutex<AppState>>`（State 本身只读，内部字段各自决定并发策略）。

---

## 错误统一 IntoResponse

```rust
// src/error.rs
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};

#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("db error: {0}")]
    Db(#[from] sqlx::Error),
    #[error("not found")]
    NotFound,
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, msg) = match &self {
            AppError::Db(e) if matches!(e, sqlx::Error::RowNotFound) => {
                (StatusCode::NOT_FOUND, "not found".to_string())
            }
            AppError::Db(_) | AppError::Other(_) => {
                tracing::error!(error = ?self, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".to_string())
            }
            AppError::NotFound => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::BadRequest(_) => (StatusCode::BAD_REQUEST, self.to_string()),
        };
        (status, Json(serde_json::json!({ "error": msg }))).into_response()
    }
}
```

**关键点**：
- 5xx 错误**只在 server 端记日志，不把内部细节回给客户端**
- 4xx 错误可以把原因回给客户端
- `#[from]` 让 `?` 自动转换

---

## spawn_blocking 边界

**判定标准**：调用预期耗时 > 10ms，或调用了同步 IO，必须 `spawn_blocking`：

```rust
// ❌ 阻塞整个 worker
async fn parse_big_csv(path: &str) -> Result<Vec<Row>, AppError> {
    let content = std::fs::read_to_string(path)?;   // 同步 IO
    Ok(csv::parse(&content))                          // CPU 密集
}

// ✅
async fn parse_big_csv(path: String) -> Result<Vec<Row>, AppError> {
    tokio::task::spawn_blocking(move || {
        let content = std::fs::read_to_string(&path)?;
        Ok(csv::parse(&content))
    })
    .await
    .map_err(|e| AppError::Other(e.into()))?
}
```

**规模阈值**：`spawn_blocking` 默认线程池上限 512，不适合海量调用，海量 CPU 任务用 `rayon`。

---

## `tokio::select!` 取消安全

**取消安全方法**（可以放心放在 `select!` 任一分支）：

- `tokio::time::sleep` / `tokio::time::timeout`
- `tokio::sync::mpsc::Receiver::recv`
- `tokio::sync::broadcast::Receiver::recv`
- `tokio::signal::ctrl_c`
- `AsyncRead::read` / `AsyncWrite::write`（标记为取消安全的部分）

**取消不安全**：

- 自己写的 `async fn`（不知道内部状态机能否安全恢复）
- `tokio::io::AsyncReadExt::read_exact`（部分读取后取消，已读字节会丢）

**安全模式**：状态保存在 `select!` 外部，分支只处理事件：

```rust
let mut buf = Vec::new();
loop {
    tokio::select! {
        // ✅ 状态在循环外，每次循环重新进入分支
        msg = rx.recv() => {
            let Some(msg) = msg else { break; };
            buf.push(msg);
        }
        _ = tokio::time::sleep(Duration::from_secs(1)) => {
            flush(&mut buf).await?;
        }
    }
}
```

---

## Mutex 选择

| 类型 | 何时用 |
|------|--------|
| `std::sync::Mutex` | 极短临界区（< 1µs），不跨 `.await` |
| `tokio::sync::Mutex` | 跨 `.await` 持锁，或临界区涉及 IO |
| `tokio::sync::RwLock` | 读多写少，读取也跨 `.await` |
| `parking_lot::Mutex` | 高性能同步锁，但同样不能跨 `.await` |
| `arc-swap` / `ArcSwap` | 只读快照配置/路由表，无锁读取 |

**陷阱**：

```rust
// ❌ 跨 await 持有 std Mutex，编译能过但等价同步阻塞
let guard = std_mutex.lock().unwrap();
db.query().await?;     // 整个 worker 卡住等锁

// ✅ tokio Mutex
let guard = tokio_mutex.lock().await;
db.query().await?;
```

---

## 超时与限流

```rust
use tower_http::{
    timeout::TimeoutLayer,
    limit::RequestBodyLimitLayer,
    cors::CorsLayer,
};

let app = Router::new()
    .merge(api_routes())
    .layer(TimeoutLayer::new(Duration::from_secs(30)))    // 全局请求超时
    .layer(RequestBodyLimitLayer::new(2 * 1024 * 1024))   // body 2MB 限制
    .layer(CorsLayer::permissive())
    .layer(TraceLayer::new_for_http());
```

**handler 内部超时**：

```rust
match tokio::time::timeout(Duration::from_secs(5), upstream.fetch()).await {
    Ok(Ok(data)) => Ok(data),
    Ok(Err(e)) => Err(e.into()),
    Err(_) => Err(AppError::BadRequest("upstream timeout".into())),
}
```

---

## 客户端复用

**`reqwest::Client` 一次创建全局复用**：连接池在内部，复用才有意义。

```rust
// AppState 持有
pub struct AppState {
    pub http: Arc<reqwest::Client>,
}

// 创建时配置默认值
let http = reqwest::Client::builder()
    .timeout(Duration::from_secs(10))
    .pool_max_idle_per_host(20)
    .user_agent("app-store-price/0.1")
    .build()?;
```

**禁止**：每次请求 `reqwest::Client::new()`（连接池失效）。

---

## 后台任务

```rust
// 应用启动时 spawn 后台任务
let handle = tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(60));
    loop {
        interval.tick().await;
        if let Err(e) = sync_data(&state).await {
            tracing::error!(error = ?e, "background sync failed");
        }
    }
});
```

**注意**：
- 后台任务 panic 不会传播到主线程，必须 `tracing::error!` 记录
- `JoinHandle` 不持有时任务继续运行，需要停止时用 `tokio::sync::oneshot` 或 cancellation token
- 优雅停机配合 `tokio_util::sync::CancellationToken`

---

## 日志（tracing）

```rust
// 初始化
tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
    .with_target(false)
    .json()              // 生产用 json，开发用默认
    .init();

// handler 内带上下文
#[tracing::instrument(skip(state), fields(user_id = %id))]
async fn get_user(State(state): State<AppState>, Path(id): Path<i64>) -> Result<Json<User>, AppError> {
    tracing::debug!("fetching user");
    // ...
}
```

**level 用法**：
- `error!`：需要人工介入
- `warn!`：可恢复异常
- `info!`：关键业务事件
- `debug!`：调试期细节
- `trace!`：极详细，默认关

---

## 测试 Axum

```rust
use axum::body::Body;
use http_body_util::BodyExt;
use tower::ServiceExt;

#[tokio::test]
async fn list_users_returns_200() {
    let app = build_router(test_state().await);

    let resp = app
        .oneshot(
            axum::http::Request::builder()
                .uri("/api/users")
                .body(Body::empty())
                .unwrap()
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);
    let body = resp.into_body().collect().await.unwrap().to_bytes();
    let users: Vec<User> = serde_json::from_slice(&body).unwrap();
    assert!(!users.is_empty());
}
```

**端到端**：直接用 `tokio::net::TcpListener::bind("127.0.0.1:0")` 启真实端口，配合 `reqwest` 测试。

---

## 常见编译错误速查

| 错误 | 原因 | 修复 |
|------|------|------|
| `cannot be sent between threads safely` | 跨 await 持有非 Send 类型（Rc/RefCell/MutexGuard） | 改 Arc/tokio::sync::Mutex，或缩小作用域 |
| `borrowed value does not live long enough` | 借用跨过持有者的作用域 | 改成 owned，或用 `Arc` |
| `cannot move out of borrowed content` | 在借用上调 owned 方法 | `.clone()` 或重构数据流 |
| `the trait `Future` is not implemented` | 忘了 `.await` 或拿了 `async fn` 当普通函数 | 加 `.await` |
| `mismatched types: expected `Pin<Box<...>>`` | 早期 async-trait 风格未启用 edition 2024 | 升级 edition 或加 `#[async_trait]` |
