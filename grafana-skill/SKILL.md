---
name: grafana-skill
description: >
  Grafana 日志与指标查询 Skill。支持通过 Grafana HTTP API 查询 Loki 日志、
  Prometheus 指标，以及直接使用 curl 调用 Loki/Prometheus API 进行日志分析。
  当用户说"帮我查一下日志"、"查 Grafana 日志"、"看一下 xxx 服务的日志/报错/异常"、
  "查一下指标"、"Prometheus 查询"等时触发此 skill。
  支持按服务名、时间范围、关键词、日志级别过滤；支持生成 LogQL/PromQL 查询语句。
metadata:
  openclaw:
    emoji: '📊'
        primaryEnv: 'GRAFANA_URL'
  security:
    credentials_usage: |
      此 skill 使用用户自配置的 Grafana URL 和 API Token，
      凭证仅发往用户自己的 Grafana 实例，不传输至任何第三方。
---

# grafana-skill

通过 Grafana 代理或直连 Loki HTTP API 查询日志，也支持 Prometheus 指标查询。

---

## 一、配置（首次使用必须完成）

支持两种模式：

- 模式 A：Grafana 代理（沿用现有方式）
- 模式 B：直连 Loki（不依赖 Grafana Token）

只要任一模式配置完成即可。

### 1.1 必填环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `GRAFANA_URL` | Grafana 实例地址（不加末尾 `/`） | `http://10.0.0.1:3000` |
| `GRAFANA_TOKEN` | Grafana Service Account Token | `glsa_xxxx` |
| `GRAFANA_LOKI_DS` | Loki 数据源 UID（可选，默认 `loki`） | `abc123de` |
| `GRAFANA_PROM_DS` | Prometheus 数据源 UID（可选，默认 `prometheus`） | `def456gh` |
| `LOKI_URL` | Loki 直连地址（不加末尾 `/`） | `http://10.0.0.2:3100` |
| `LOKI_TOKEN` | Loki 访问 Token（可选） | `xxxx` |
| `LOKI_TENANT_ID` | Loki 多租户 ID（可选） | `prod` |

### 1.2 配置文件存储（推荐）

在 Windows 下创建配置文件：

```powershell
# 创建配置目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\grafana"

# 写入配置（按实际值修改）
@"
GRAFANA_URL=http://10.0.0.1:3000
GRAFANA_TOKEN=glsa_your_token_here
GRAFANA_LOKI_DS=loki
GRAFANA_PROM_DS=prometheus
LOKI_URL=http://10.0.0.2:3100
LOKI_TOKEN=
LOKI_TENANT_ID=
"@ | Set-Content "$env:USERPROFILE\.config\grafana\config"
```

### 1.3 凭证预检脚本

在调用任何 API 前，先执行以下检查：

```powershell
# 加载配置（优先环境变量，其次配置文件）
$configFile = "$env:USERPROFILE\.config\grafana\config"
if (Test-Path $configFile) {
    Get-Content $configFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.+)$") {
            if (-not [System.Environment]::GetEnvironmentVariable($matches[1])) {
                [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim())
            }
        }
    }
}

$GRAFANA_URL    = $env:GRAFANA_URL
$GRAFANA_TOKEN  = $env:GRAFANA_TOKEN
$LOKI_DS        = if ($env:GRAFANA_LOKI_DS) { $env:GRAFANA_LOKI_DS } else { "loki" }
$PROM_DS        = if ($env:GRAFANA_PROM_DS) { $env:GRAFANA_PROM_DS } else { "prometheus" }
$LOKI_URL       = $env:LOKI_URL
$LOKI_TOKEN     = $env:LOKI_TOKEN
$LOKI_TENANT_ID = $env:LOKI_TENANT_ID

if ((-not $LOKI_URL) -and (-not $GRAFANA_URL -or -not $GRAFANA_TOKEN)) {
    Write-Error "❌ 未检测到可用配置：请配置 Loki 直连（LOKI_URL）或 Grafana 代理（GRAFANA_URL + GRAFANA_TOKEN）"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $GRAFANA_TOKEN"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

Write-Host "✅ Grafana 配置加载成功: $GRAFANA_URL"
if ($LOKI_URL) {
    Write-Host "✅ Loki 直连可用: $LOKI_URL"
}
```

### 1.4 一键直连 Loki（推荐）

可以直接用仓库脚本查询：

```powershell
powershell -ExecutionPolicy Bypass -File .agent/skills/grafana-skill/scripts/query-loki.ps1 -Service exchange-risk-service -Env prod -Keyword error -LastMinutes 30
```

---

## 二、查询日志（Loki）

### 2.1 查询入口：`/loki/api/v1/query_range`

```powershell
# 参数说明：
# $query  - LogQL 查询语句
# $start  - 开始时间（Unix 纳秒 或 RFC3339）
# $end    - 结束时间（Unix 纳秒 或 RFC3339）
# $limit  - 最多返回条数（默认 100）

function Query-LokiLogs {
    param(
        [string]$query,
        [string]$start = "",
        [string]$end   = "",
        [int]$limit    = 100,
        [string]$direction = "backward"  # backward=最新日志优先
    )

    # 默认查最近 30 分钟
    if (-not $start) {
        $start = [DateTimeOffset]::UtcNow.AddMinutes(-30).ToUnixTimeMilliseconds().ToString() + "000000"
    }
    if (-not $end) {
        $end = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString() + "000000"
    }

    $encodedQuery = [System.Uri]::EscapeDataString($query)
    $url = "$GRAFANA_URL/loki/api/v1/query_range?query=$encodedQuery&start=$start&end=$end&limit=$limit&direction=$direction"

    try {
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $resp
    } catch {
        Write-Error "查询失败: $_"
        return $null
    }
}
```

### 2.2 通过 Grafana 代理查询 Loki（推荐，支持权限隔离）

```powershell
# 使用 Grafana 的数据源代理接口，$LOKI_DS 是 Loki 数据源 UID
function Query-LokiViaGrafana {
    param(
        [string]$query,
        [string]$startRfc3339 = "",
        [string]$endRfc3339   = "",
        [int]$limit = 100
    )

    $now   = [DateTimeOffset]::UtcNow
    $start = if ($startRfc3339) { $startRfc3339 } else { $now.AddMinutes(-30).ToString("o") }
    $end   = if ($endRfc3339)   { $endRfc3339   } else { $now.ToString("o") }

    $encodedQuery = [System.Uri]::EscapeDataString($query)
    $url = "$GRAFANA_URL/api/datasources/proxy/uid/$LOKI_DS/loki/api/v1/query_range?query=$encodedQuery&start=$start&end=$end&limit=$limit&direction=backward"

    $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    return $resp
}
```

### 2.4 直连 Loki 查询（不经过 Grafana）

```powershell
function Query-LokiDirect {
    param(
        [string]$query,
        [string]$startRfc3339 = "",
        [string]$endRfc3339   = "",
        [int]$limit = 100
    )

    if (-not $env:LOKI_URL) {
        throw "缺少 LOKI_URL，无法直连 Loki"
    }

    $now   = [DateTimeOffset]::UtcNow
    $start = if ($startRfc3339) { $startRfc3339 } else { $now.AddMinutes(-30).ToString("o") }
    $end   = if ($endRfc3339)   { $endRfc3339   } else { $now.ToString("o") }

    $headers = @{ "Accept" = "application/json" }
    if ($env:LOKI_TOKEN) {
        $headers["Authorization"] = "Bearer $($env:LOKI_TOKEN)"
    }
    if ($env:LOKI_TENANT_ID) {
        $headers["X-Scope-OrgID"] = $env:LOKI_TENANT_ID
    }

    $encodedQuery = [System.Uri]::EscapeDataString($query)
    $url = "$($env:LOKI_URL)/loki/api/v1/query_range?query=$encodedQuery&start=$start&end=$end&limit=$limit&direction=backward"

    Invoke-RestMethod -Uri $url -Headers $headers -Method Get
}
```

### 2.3 格式化输出日志

```powershell
function Format-LokiResponse {
    param($response, [int]$maxLines = 50)

    if (-not $response -or -not $response.data.result) {
        Write-Host "没有找到匹配的日志"
        return
    }

    $total = 0
    foreach ($stream in $response.data.result) {
        $labels = ($stream.stream.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ", "
        Write-Host "`n【流标签】$labels" -ForegroundColor Cyan

        foreach ($entry in $stream.values) {
            if ($total -ge $maxLines) { Write-Host "... 已截断，共 $($stream.values.Count) 条"; break }
            $ts = [DateTimeOffset]::FromUnixTimeMilliseconds([long]($entry[0]) / 1000000).LocalDateTime
            Write-Host "[$ts] $($entry[1])"
            $total++
        }
    }
    Write-Host "`n共 $total 条日志" -ForegroundColor Green
}
```

---

## 三、LogQL 查询模板

根据用户意图，生成对应的 LogQL 语句：

### 3.1 按服务名查询

```logql
# 查询某个服务的所有日志（最近 N 分钟）
{service_name="exchange-risk-service"}

# 查询指定 namespace 下的服务
{namespace="production", app="exchange-kyc-service"}

# 包含关键词
{service_name="exchange-core-service"} |= "error"

# 过滤错误级别（JSON 日志）
{service_name="exchange-risk-service"} | json | level="error"

# 过滤特定 traceID
{namespace="production"} |= "trace_id=abc123"
```

### 3.2 按错误类型查询

```logql
# 查询 panic
{namespace="production"} |= "panic"

# 查询 5xx 错误（HTTP 日志）
{app="api-gateway"} | json | status >= 500

# 查询数据库错误
{service_name="exchange-core-service"} |~ "(?i)(sql|db|database).*(error|fail|timeout)"

# 查询超时
{namespace="production"} |~ "(?i)(timeout|timed out|deadline exceeded)"
```

### 3.3 统计日志量（Metric 查询）

```logql
# 每分钟错误日志量
sum by (service_name) (rate({namespace="production"} |= "error" [1m]))

# 各服务日志量对比
sum by (app) (count_over_time({namespace="production"}[5m]))
```

---

## 四、查询指标（Prometheus）

### 4.1 通过 Grafana 代理查询

```powershell
function Query-Prometheus {
    param(
        [string]$promql,
        [string]$time = ""  # RFC3339 或留空（默认 now）
    )

    $encodedQuery = [System.Uri]::EscapeDataString($promql)
    $timeParam = if ($time) { "&time=$time" } else { "" }
    $url = "$GRAFANA_URL/api/datasources/proxy/uid/$PROM_DS/api/v1/query?query=$encodedQuery$timeParam"

    $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    return $resp
}

function Query-PrometheusRange {
    param(
        [string]$promql,
        [string]$start = "",
        [string]$end   = "",
        [string]$step  = "60"  # 单位：秒
    )

    $now   = [DateTimeOffset]::UtcNow
    $start = if ($start) { $start } else { $now.AddHours(-1).ToString("o") }
    $end   = if ($end)   { $end   } else { $now.ToString("o") }

    $encodedQuery = [System.Uri]::EscapeDataString($promql)
    $url = "$GRAFANA_URL/api/datasources/proxy/uid/$PROM_DS/api/v1/query_range?query=$encodedQuery&start=$start&end=$end&step=$step"

    $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    return $resp
}
```

---

## 五、PromQL 查询模板

```promql
# 服务 QPS（每秒请求数）
sum(rate(http_server_requests_total{service="exchange-risk-service"}[1m]))

# 错误率
sum(rate(http_server_requests_total{service="exchange-risk-service", status=~"5.."}[1m]))
/ sum(rate(http_server_requests_total{service="exchange-risk-service"}[1m]))

# P99 延迟
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket{service="exchange-core-service"}[5m]))
)

# 内存使用
container_memory_working_set_bytes{namespace="production", pod=~"exchange-kyc.*"}

# CPU 使用率
sum(rate(container_cpu_usage_seconds_total{namespace="production", pod=~"exchange-.*"}[5m])) by (pod)

# RocketMQ 消息积压量
rocketmq_consumer_tps{consumerGroup="kyc-audit-group"}
```

---

## 六、执行流程

当用户请求查询日志时，按以下步骤执行：

### 步骤 1：理解意图

| 用户说 | 查询方向 |
|--------|---------|
| "看一下 XX 服务的报错" | Loki，`|= "error"` 或 `\| json \| level="error"` |
| "最近半小时有没有 panic" | Loki，`|= "panic"`，时间范围 -30m |
| "查一下 traceId=xxx 的日志" | Loki，`|= "traceId=xxx"` |
| "XX 服务的 QPS 是多少" | Prometheus，`rate(http_server_requests_total{...}[1m])` |
| "查一下数据库连接超时" | Loki，`|~ "(?i)(connection|db).*(timeout)"` |
| "P99 延迟有多高" | Prometheus，`histogram_quantile(0.99, ...)` |

### 步骤 2：生成查询语句

根据用户输入的服务名、时间范围、关键词，填充对应模板生成 LogQL / PromQL。

若用户未指定时间范围，默认查询**最近 30 分钟**。

### 步骤 3：执行查询

1. 执行 [凭证预检](#一配置首次使用必须完成) 代码块
2. 执行对应查询函数（`Query-LokiDirect` / `Query-LokiViaGrafana` / `Query-Prometheus`）
3. 使用 `Format-LokiResponse` 格式化日志输出

### 步骤 4：分析结果

- 如果日志量超过 200 条，先统计报错类型分布，再展示典型错误
- 提取关键信息：时间戳、服务名、错误消息、堆栈跟踪
- 给出初步诊断建议

---

## 七、数据源 UID 查询方法

如果不知道 Loki/Prometheus 的 UID，执行：

```powershell
# 列出所有数据源
$resp = Invoke-RestMethod -Uri "$GRAFANA_URL/api/datasources" -Headers $headers -Method Get
$resp | ForEach-Object { Write-Host "$($_.uid) - $($_.name) ($($_.type))" }
```

---

## 八、常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 401 Unauthorized | Token 无效或过期 | 在 Grafana → Administration → Service accounts 重新创建 Token |
| 404 数据源未找到 | LOKI_DS UID 错误 | 执行 [七、数据源 UID 查询方法](#七数据源-uid-查询方法) |
| 查询返回空 | 时间范围或标签不对 | 先在 Grafana UI 上 Explore 确认标签名 |
| PowerShell 5.1 乱码 | 编码问题 | 使用 `[System.Text.Encoding]::UTF8.GetBytes()` 发送请求体 |
| 日志太多，截断 | limit 默认 100 | 增大 `$limit` 参数，或加更多过滤条件 |

## 九、推荐调用方式

- 仅查日志且你有 Loki 地址：优先直连 Loki
- 你们通过 Grafana 做权限控制：用 Grafana 代理
- 你可以直接在聊天中说：
    - 直连 Loki 查 exchange-risk-service 在 prod 最近 30m 的 error
    - 用 Loki 接口查 requestId=xxx 的全链路日志
