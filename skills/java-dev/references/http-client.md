# 第三方 API HTTP 客户端选型

> 调用微信、支付宝等国内平台 API 时的 HTTP 客户端兼容性问题与解决方案

---

## 问题背景

Spring Boot 的 `RestTemplate` 默认使用 `HttpURLConnection` 作为底层 HTTP 客户端。该客户端在发送 POST 请求时，与部分国内平台（微信、支付宝等）的 CDN/WAF 层存在兼容性问题，已知会触发 HTTP 412（Precondition Failed）或 403。

**典型表现**：
- GET 请求正常（如 `code2Session`、`getAccessToken`）
- POST 请求返回 412/403，body 为空，Content-Length: 0
- Response headers 极简（只有 `Connection: keep-alive` + `Content-Length: 0`），缺少目标 API 的标准 headers

**根因**：`HttpURLConnection` 在 HTTPS POST 场景下的请求头、连接复用、chunked encoding 等行为与某些 CDN 的预期不一致，被 CDN 层直接拦截。

---

## 推荐方案

### 方案一：java.net.http.HttpClient（JDK 11+，推荐）

```java
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

HttpClient httpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build();

HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create(url))
        .timeout(Duration.ofSeconds(5))
        .header("Content-Type", "application/json")
        .header("Accept", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
        .build();

HttpResponse<String> response = httpClient.send(
        request, HttpResponse.BodyHandlers.ofString());

int statusCode = response.statusCode();
String body = response.body();
```

### 方案二：RestTemplate + Apache HttpClient

```xml
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
</dependency>
```

```java
@Bean
public RestTemplate restTemplate() {
    return new RestTemplateBuilder()
            .requestFactory(() -> new HttpComponentsClientHttpRequestFactory())
            .build();
}
```

---

## 诊断方法

当第三方 API 调用失败时，按以下顺序排查：

1. **检查 response body 和 headers**：如果 body 为空且 headers 极简，大概率是 CDN/WAF 层拦截，不是 API 本身的错误
2. **对比 GET 和 POST**：同一 API 的 GET 正常但 POST 异常 → HTTP 客户端兼容性问题
3. **检查 HTTP 客户端**：确认是否使用了 `HttpURLConnection`（RestTemplate 默认）
4. **换客户端验证**：切换到 `java.net.http.HttpClient` 或 Apache HttpClient 后重试

---

## 已知受影响的 API

| 平台 | 接口 | 方法 | 现象 |
|------|------|------|------|
| 微信 | `phonenumber.getPhoneNumber` | POST | 412 + 空 body |
| 微信 | 其他需要 POST 的服务端 API | POST | 可能触发 412/403 |

> 注：GET 类接口（如 `code2Session`、`getAccessToken`）不受影响。
