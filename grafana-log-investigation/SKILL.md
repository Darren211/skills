---
name: grafana-log-investigation
description: >
  Grafana 日志排查 Skill。用于通过 Grafana/Loki/LogQL 协助定位线上问题、
  错误峰值、慢请求、异常用户行为和回归故障。
  当用户提到 "grafana"、"loki"、"logql"、"查日志"、"看日志"、"排查日志"、
   "报错定位"、"线上问题定位" 时触发。
   侧重排查流程、结论产出和项目内常见字段模板；如需直接调用 Grafana API，
   可配合使用 `grafana-skill`。
---

# Grafana Log Investigation

## 使用场景

- 线上报警后快速定位报错来源
- 按 traceId / requestId / userId 追踪请求链路
- 分析错误码分布和峰值时间段
- 验证发布前后是否出现异常回归

## 输入约定（优先收集）

如果用户没有给全，先补齐以下最小信息：

1. 环境：`dev` / `uat` / `prod`
2. 服务名：例如 `exchange-risk-service`
3. 时间范围：例如最近 `15m`、`1h`，或精确时间段
4. 关键线索：`traceId` / `requestId` / `userId` / 错误码 / 关键词
5. 预期行为：正常情况下应该发生什么

## 标准排查流程

1. 先确认时间窗口和时区，避免错查。
2. 从高信号关键词开始（`error`、`panic`、`timeout`、`exception`、业务错误码）。
3. 逐步收窄：服务 -> 实例 -> 关键词 -> traceId/requestId。
4. 对同一时间窗口做对比：
   - 错误日志量
   - 错误类型 TopN
   - 相关上游/下游依赖超时
5. 产出结论：
   - 现象（发生了什么）
   - 根因假设（为什么发生）
   - 证据（关键日志片段/统计）
   - 下一步动作（修复/回滚/加监控）

## 项目服务快捷清单

优先从以下服务名中选择，减少口头描述和真实 label 不一致的问题：

- `exchange-core-service`
- `exchange-kyc-service`
- `exchange-quoter-backend`
- `exchange-risk-service`
- `exchange-user-attribute-backend`
- `exchange-web_api-service`

## 项目字段别名

日志字段可能不是统一命名，排查时按以下顺序尝试：

- Trace 相关：`traceId` / `trace_id` / `x_trace_id`
- Request 相关：`requestId` / `request_id`
- 用户相关：`userId` / `user_id` / `uid`
- 错误码相关：`err_code` / `error_code` / `code`
- 级别相关：`level` / `severity`

## LogQL 查询模板

> 按实际 label 调整，如 `app`、`service`、`namespace`、`env`。

```logql
{service="exchange-risk-service", env="prod"} |= "error"
```

```logql
{service="exchange-risk-service", env="prod"} |= "panic" or "timeout"
```

```logql
{service="exchange-risk-service", env="prod"} |= "requestId=abcd-1234"
```

```logql
{service="exchange-web_api-service", env="prod"} |~ "(?i)(traceId|trace_id|x_trace_id)=abcd-1234"
```

```logql
{service="exchange-web_api-service", env="prod"} |~ "(?i)(requestId|request_id)=req-1234"
```

```logql
{service="exchange-risk-service", env="prod"} |~ "(?i)(err_code|error_code|code)"
```

```logql
sum by (level) (count_over_time({service="exchange-risk-service", env="prod"} |= "error" [5m]))
```

```logql
topk(10, sum by (err_code) (count_over_time({service="exchange-risk-service", env="prod"} | json | err_code != "" [15m])))
```

```logql
topk(10, sum by (service) (count_over_time({env="prod"} |~ "(?i)(error|panic|timeout|exception)" [10m])))
```

## 一句话调用模板

优先让用户按以下句式提问，能显著提升命中率：

- `帮我查 exchange-risk-service 在 prod 最近 30m 的 panic/timeout，先给错误类型 TopN 再给根因判断。`
- `帮我看 exchange-web_api-service 在 uat 最近 1h，requestId=req-1234 全链路日志。`
- `帮我排查 exchange-core-service 在 prod 10:00-10:30 的 error 峰值，按时间线总结。`

## 输出格式

每次排查按这个结构回复：

```text
【问题概述】
- 服务/环境：...
- 时间范围：...
- 现象：...

【关键发现】
- 发现1：...
- 发现2：...

【根因判断】
- 当前最可能根因：...
- 置信度：高/中/低

【建议动作】
1) 立即止血：...
2) 修复方案：...
3) 预防改进：...
```

## 注意事项

- 不要基于单条日志下结论，要看同时间窗口统计趋势。
- 若证据不足，明确标注为“假设”并给出补充采样方案。
- 涉及安全或资金风险时，优先建议降级/熔断/回滚。
