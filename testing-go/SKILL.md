---
name: testing-go
description: Go 测试生成流程。用于为 Go 包、函数、Handler 和 Service 设计并实现单元测试、接口测试或集成测试，优先采用表驱动风格。
---

# Go 测试生成 SOP

> 当用户提出“给这个 Go 包写测试”、“补 table-driven test”、“给 Handler/Service 加测试”等请求时使用。

## 前置：需求澄清

> 必须先执行 `requirement-clarify-go`，至少确认 `TG-01` ~ `TG-02`。

## 步骤 1：分析被测目标

### 1.1 理解职责
- 读懂包、函数或方法的核心职责。
- 找出正常路径、错误路径、边界条件。
- 对并发、超时、错误链、幂等等特殊行为单独标记。

### 1.2 识别依赖
- 哪些依赖可以 mock。
- 哪些依赖需要 fake/stub。
- 是否需要 `httptest`、临时文件、`testdata`、SQLite 或 `testcontainers-go`。

## 步骤 2：先输出测试设计
编码前先给出测试设计，等待用户确认：

```markdown
## 测试用例设计

### 目标
- 包/文件：
- 主要函数/方法：
- 测试类型：单元 / Handler / 集成 / 基准

### 用例表
| 用例编号 | 目标 | 场景分类 | 描述 | 预期 |
|:---:|------|:---:|------|------|

### Mock 策略
- 需要 mock 的依赖：
- 需要真实资源的依赖：

### 覆盖重点
- 错误路径：
- 边界条件：
- 并发 / context / 权限：
```

## 步骤 3：编写测试代码

### 3.1 风格约定
- 优先使用 Go 原生 `testing`。
- 推荐搭配 `testify/assert`、`testify/require`。
- 优先使用表驱动测试。
- 测试文件与源码同目录，命名为 `*_test.go`。

### 3.2 单元测试
- Service 层通过接口隔离依赖。
- mock 优先使用项目既有方案，如 `gomock` 或 `mockery`。
- 不在单元测试中连接真实数据库、Redis、MQ 或第三方服务。

### 3.3 Handler 测试
- 使用 `httptest.NewRecorder()` + 构造请求。
- 关注参数绑定、校验、状态码、响应体和错误分支。

### 3.4 集成测试
- 仅在必要时使用。
- 优先使用隔离环境，例如 SQLite、`testcontainers-go` 或项目现有测试基建。

### 3.5 必测场景
- 正常路径
- 错误路径
- 边界值
- 空值或非法值
- 并发与 context 超时（如适用）

## 步骤 4：输出交付结果

```markdown
## 测试完成摘要
- 测试文件：
- 用例数量：
- 覆盖方法/函数：
- Mock 依赖：
- 未覆盖场景：
```

建议同时给出运行命令，例如：

```bash
go test ./...
go test ./internal/service -run TestUserService_Create
go test ./... -cover
```

## 步骤 5：任务交付文档
在 `docs/` 下生成：`docs/{YYYY-MM-DD}-test-go-{模块简称}.md`

建议包含：
- 测试目标
- 用例设计
- 文件变更
- 覆盖统计
- 运行方式
- 风险与覆盖盲区
