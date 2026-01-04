---
description: 安全审查当前分支的代码变更
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git show:*), Read, Glob, Grep
---

对当前分支的代码变更进行安全审查。

## 上下文信息

GIT STATUS:
```
!`git status`
```

FILES MODIFIED:
```
!`git diff --name-only origin/HEAD... 2>/dev/null || git diff --name-only HEAD~5`
```

DIFF CONTENT:
```
!`git diff --merge-base origin/HEAD 2>/dev/null || git diff HEAD~5`
```

## 审查目标

识别 **高置信度** 的安全漏洞，只报告 >80% 确信可被利用的问题。

## 审查范围

### 输入验证漏洞
- SQL 注入
- 命令注入
- 路径遍历
- XSS（仅 dangerouslySetInnerHTML 等不安全方法）

### 认证与授权
- 认证绕过
- 权限提升
- 会话管理缺陷

### 密钥与加密
- 硬编码密钥/密码
- 弱加密算法
- 证书验证绕过

### 代码执行
- 反序列化漏洞
- eval 注入
- 模板注入

## 排除项（不报告）

- DoS/资源耗尽问题
- 磁盘上的密钥文件（由其他流程处理）
- 速率限制问题
- 日志污染
- 理论性/低影响漏洞
- 测试文件中的问题
- React/Vue 组件中的 XSS（框架已保护）

## 输出格式

```markdown
# 安全审查报告

## 发现的问题

### [严重程度] 漏洞类型: `文件:行号`

**描述**: [漏洞描述]

**利用场景**: [具体的攻击路径]

**置信度**: [8-10]/10

**建议修复**: [修复建议]

---

## 总结

- 高危: X 个
- 中危: X 个
- 总体评估: [安全/需要关注/存在风险]
```

## 严重程度定义

- **高危**: 直接可利用，导致 RCE、数据泄露、认证绕过
- **中危**: 需要特定条件，但影响显著
- **低危**: 防御纵深问题（不在本报告范围）

## 注意事项

- 只读审查，不修改任何代码
- 宁可漏报，不可误报
- 每个发现都需要具体的利用场景
