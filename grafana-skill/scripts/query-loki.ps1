param(
    [Parameter(Mandatory = $false)] [string]$Query,
    [Parameter(Mandatory = $false)] [string]$Service = "exchange-risk-service",
    [Parameter(Mandatory = $false)] [string]$Env = "prod",
    [Parameter(Mandatory = $false)] [string]$Keyword = "error",
    [Parameter(Mandatory = $false)] [int]$LastMinutes = 30,
    [Parameter(Mandatory = $false)] [int]$Limit = 100,
    [Parameter(Mandatory = $false)] [string]$Start,
    [Parameter(Mandatory = $false)] [string]$End,
    [Parameter(Mandatory = $false)] [switch]$Raw
)

$ErrorActionPreference = "Stop"

function Load-ConfigFileIfExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return
    }

    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)\s*$') {
            $name = $matches[1]
            $value = $matches[2]
            if (-not [string]::IsNullOrWhiteSpace($name) -and -not [Environment]::GetEnvironmentVariable($name)) {
                [Environment]::SetEnvironmentVariable($name, $value)
            }
        }
    }
}

Load-ConfigFileIfExists -Path "$env:USERPROFILE\.config\grafana\config"
Load-ConfigFileIfExists -Path "$env:USERPROFILE\.config\loki\config"

$lokiUrl = $env:LOKI_URL
if (-not $lokiUrl) {
    throw "LOKI_URL 未配置。请先设置环境变量，或写入 $env:USERPROFILE/.config/loki/config"
}

if (-not $Query) {
    $Query = "{service=\"$Service\", env=\"$Env\"} |= \"$Keyword\""
}

$startValue = $Start
$endValue = $End

if (-not $startValue) {
    $startValue = [DateTimeOffset]::UtcNow.AddMinutes(-1 * $LastMinutes).ToString("o")
}
if (-not $endValue) {
    $endValue = [DateTimeOffset]::UtcNow.ToString("o")
}

$headers = @{ "Accept" = "application/json" }
if ($env:LOKI_TOKEN) {
    $headers["Authorization"] = "Bearer $($env:LOKI_TOKEN)"
}
if ($env:LOKI_TENANT_ID) {
    $headers["X-Scope-OrgID"] = $env:LOKI_TENANT_ID
}

$encoded = [System.Uri]::EscapeDataString($Query)
$url = "$lokiUrl/loki/api/v1/query_range?query=$encoded&start=$startValue&end=$endValue&limit=$Limit&direction=backward"

$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
if ($Raw) {
    $response | ConvertTo-Json -Depth 10
    exit 0
}

if (-not $response -or -not $response.data -or -not $response.data.result -or $response.data.result.Count -eq 0) {
    Write-Host "No logs found for query: $Query"
    exit 0
}

$total = 0
foreach ($stream in $response.data.result) {
    $labels = ($stream.stream.PSObject.Properties | ForEach-Object { "{0}={1}" -f $_.Name, $_.Value }) -join ", "
    Write-Host "\n[stream] $labels" -ForegroundColor Cyan

    foreach ($entry in $stream.values) {
        $tsMs = [long]($entry[0]) / 1000000
        $ts = [DateTimeOffset]::FromUnixTimeMilliseconds($tsMs).LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        Write-Host "[$ts] $($entry[1])"
        $total++
    }
}

Write-Host "\nTotal lines: $total" -ForegroundColor Green
