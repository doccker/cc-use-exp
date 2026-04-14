---
name: storage-url-safety
description: 当使用 MinIO/OSS/S3 等对象存储、设计文件上传下载功能时触发。提供存储 URL 策略选择规范，防止 URL 过期、访问失败等问题。
---

# 存储 URL 策略选择规范

当使用 MinIO/OSS/S3 等对象存储时，正确选择 URL 生成策略。

---

## 陷阱 #1: 头像等长期资源使用预签名 URL

**场景**: 头像、Logo、商品图等需要长期访问的资源

### 问题根因

预签名 URL 有时效限制（MinIO/S3 最大 7 天），头像等长期资源会过期导致无法访问。

### 错误示例

```java
// ❌ 错误: 预签名 URL 最大 7 天，头像会过期
String avatarUrl = minioService.getPresignedUrl(filePath, 60 * 24 * 365);
// IllegalArgumentException: expiry must be minimum 1 second to maximum 7 days

// ❌ 错误: 即使设置 7 天，头像也会在 7 天后失效
String avatarUrl = minioService.getPresignedUrl(filePath, 60 * 24 * 7);
// 7 天后用户头像显示"图片加载失败"
```

### 正确做法

```java
// ✅ 方案1: 公开 URL（需配置 bucket 公开读）
public String getPublicUrl(String filePath) {
    String endpoint = minioConfig.getEndpoint();
    if (endpoint.endsWith("/")) {
        endpoint = endpoint.substring(0, endpoint.length() - 1);
    }
    return endpoint + "/" + minioConfig.getBucketName() + "/" + filePath;
}

String avatarUrl = minioService.getPublicUrl(filePath);
// 返回: http://minio:9000/bucket/avatars/xxx.jpeg

// ✅ 方案2: CDN URL（生产环境推荐）
String avatarUrl = cdnService.getCdnUrl(filePath);
// 返回: https://cdn.example.com/avatars/xxx.jpeg
```

---

## URL 策略选择表

| 资源类型 | 推荐策略 | 有效期 | 适用场景 | 示例 |
|---------|---------|-------|---------|------|
| 头像/Logo | 公开 URL / CDN | 永久 | 需长期访问 | 用户头像、企业 Logo |
| 商品图片 | 公开 URL / CDN | 永久 | 需长期访问 | 电商商品图、文章配图 |
| 公开文档 | 公开 URL / CDN | 永久 | 需长期访问 | 用户手册、API 文档 |
| 临时文件 | 预签名 URL | 1h-7d | 下载凭证 | 导出的 Excel、临时分享 |
| 私密文档 | 预签名 URL | 15min-1h | 临时授权 | 合同、财务报表 |
| 上传凭证 | 预签名 URL | 5min-30min | 客户端直传 | 前端直传 OSS |

---

## 陷阱 #2: 公开 URL 的 Bucket 未配置公开读

**场景**: 使用公开 URL 但 bucket 策略未配置

### 错误示例

```java
// ✅ 代码正确生成公开 URL
String avatarUrl = minioService.getPublicUrl(filePath);
// 返回: http://minio:9000/bucket/avatars/xxx.jpeg

// ❌ 但 bucket 未配置公开读，访问返回 403 Forbidden
```

### 正确做法

**MinIO 配置公开读**:

```bash
# 方案1: 使用 mc 命令配置（推荐）
mc anonymous set download minio/bucket/avatars

# 方案2: 使用 bucket policy
mc admin policy attach minio readonly --user=public
```

**Bucket Policy 示例**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::bucket/avatars/*"]
    }
  ]
}
```

**阿里云 OSS 配置**:

```bash
# 设置 bucket 公共读
ossutil64 set-acl oss://bucket-name public-read

# 或只设置特定目录
ossutil64 set-acl oss://bucket-name/avatars/ public-read --recursive
```

---

## 陷阱 #3: 预签名 URL 的有效期设置不当

**场景**: 临时文件下载链接有效期过长或过短

### 规范

| 场景 | 推荐有效期 | 说明 |
|------|-----------|------|
| 客户端直传凭证 | 5-30 分钟 | 上传时间通常很短 |
| 临时分享链接 | 1-24 小时 | 用户可能稍后下载 |
| 导出文件下载 | 1-7 天 | 用户可能多次下载 |
| 私密文档查看 | 15-60 分钟 | 安全性要求高 |

### 错误示例

```java
// ❌ 错误: 客户端直传凭证有效期 7 天，安全风险高
String uploadUrl = minioService.getPresignedUrl(filePath, 60 * 24 * 7);

// ❌ 错误: 导出文件下载链接只有 5 分钟，用户可能来不及下载
String downloadUrl = minioService.getPresignedUrl(filePath, 5);
```

### 正确做法

```java
// ✅ 客户端直传凭证: 15 分钟
String uploadUrl = minioService.getPresignedUrl(filePath, 15);

// ✅ 导出文件下载: 24 小时
String downloadUrl = minioService.getPresignedUrl(filePath, 60 * 24);

// ✅ 私密文档查看: 30 分钟
String viewUrl = minioService.getPresignedUrl(filePath, 30);
```

---

## 陷阱 #4: 前端直传时未校验文件类型和大小

**场景**: 前端直传 OSS，后端生成上传凭证

### 错误示例

```java
// ❌ 错误: 未校验文件类型和大小，任何文件都能上传
@PostMapping("/upload/token")
public ApiResponse<String> getUploadToken(@RequestParam String filename) {
    String uploadUrl = minioService.getPresignedUrl("uploads/" + filename, 15);
    return ApiResponse.success(uploadUrl);
}
```

### 正确做法

```java
// ✅ 后端校验文件类型和大小
@PostMapping("/upload/token")
public ApiResponse<UploadToken> getUploadToken(
    @RequestParam String filename,
    @RequestParam String contentType,
    @RequestParam Long fileSize) {

    // 校验文件类型
    List<String> allowedTypes = Arrays.asList("image/jpeg", "image/png", "image/gif");
    if (!allowedTypes.contains(contentType)) {
        return ApiResponse.error("不支持的文件类型");
    }

    // 校验文件大小（5MB）
    if (fileSize > 5 * 1024 * 1024) {
        return ApiResponse.error("文件大小不能超过 5MB");
    }

    // 生成安全的文件名（防止路径遍历）
    String safeFilename = UUID.randomUUID() + getExtension(filename);
    String filePath = "avatars/" + LocalDate.now() + "/" + safeFilename;

    String uploadUrl = minioService.getPresignedUrl(filePath, 15);
    return ApiResponse.success(new UploadToken(uploadUrl, filePath));
}
```

---

## 陷阱 #5: CDN 回源配置错误

**场景**: 使用 CDN 加速但回源配置不正确

### 错误示例

```java
// ✅ 代码正确返回 CDN URL
String avatarUrl = "https://cdn.example.com/avatars/xxx.jpeg";

// ❌ 但 CDN 回源配置错误:
// 1. 回源 Host 未设置为 MinIO endpoint
// 2. 回源协议未设置为 HTTP
// 3. 回源路径未包含 bucket 名称
// 导致 CDN 返回 404 或 403
```

### 正确做法

**阿里云 CDN 回源配置**:

```
回源 Host: minio.example.com
回源协议: HTTP
回源地址: minio.example.com:9000
回源路径: /bucket${uri}
```

**腾讯云 CDN 回源配置**:

```
源站类型: 自有源
源站地址: minio.example.com:9000
回源协议: HTTP
回源 Host: minio.example.com
回源路径: /bucket${uri}
```

---

## 检查清单（存储 URL 策略）

**URL 策略选择**:
- [ ] 头像/Logo 是否使用公开 URL 或 CDN
- [ ] 临时文件是否使用预签名 URL
- [ ] 预签名 URL 的有效期是否 ≤ 7 天
- [ ] 预签名 URL 的有效期是否符合业务场景

**Bucket 配置**:
- [ ] 公开 URL 的 bucket 是否配置了公开读策略
- [ ] 公开读策略是否只针对特定目录（如 avatars/）
- [ ] 是否配置了 CORS（前端直传需要）

**CDN 配置**:
- [ ] 生产环境是否使用 CDN 加速
- [ ] CDN 回源 Host 是否正确
- [ ] CDN 回源路径是否包含 bucket 名称
- [ ] CDN 是否配置了缓存规则

**安全性**:
- [ ] 前端直传是否校验文件类型和大小
- [ ] 文件名是否使用 UUID 防止路径遍历
- [ ] 私密文件是否使用预签名 URL 而非公开 URL

---

## 适用范围

- MinIO
- 阿里云 OSS
- 腾讯云 COS
- AWS S3
- 七牛云 Kodo
- 华为云 OBS

---

## 规则溯源

```
> 📋 本回复遵循：`storage-url-safety` - 存储 URL 策略选择规范
```
