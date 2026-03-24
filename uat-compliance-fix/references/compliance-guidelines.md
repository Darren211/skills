# UAT 代码库结构合规准则

**文档编号:** SEC-STD-001  
**适用范围:** 所有 Exchange 平台服务（auth-service、wallet-core、front-app 等）  
**生效条件:** UAT 分支标准 = 生产（PRD）标准  
**版本:** v1.0  
**日期:** 2026-02-09  

---

## 目录

- [一、总则](#一总则)
- [二、文件分类与准入准则](#二文件分类与准入准则)
- [三、禁止入库清单](#三禁止入库清单)
- [四、必须入库清单](#四必须入库清单)
- [五、.gitignore 规范](#五gitignore-规范)
- [六、.dockerignore 规范](#六dockerignore-规范)
- [七、配置管理规范](#七配置管理规范)
- [八、Dockerfile 规范](#八dockerfile-规范)
- [九、CI/CD 配置规范](#九cicd-配置规范)
- [十、泄露防护机制](#十泄露防护机制)
- [十一、Git 历史合规](#十一git-历史合规)
- [十二、标准目录结构模板](#十二标准目录结构模板)
- [十三、合规检查清单](#十三合规检查清单)
- [十四、违规处理](#十四违规处理)

---

## 一、总则

### 1.1 核心原则

| 原则 | 说明 |
|------|------|
| **零信任入库** | 默认不信任任何文件——凡含敏感信息的文件，不得进入版本控制 |
| **UAT 即 PRD** | UAT 分支的所有标准与生产环境完全一致，审查 UAT 等同于审查 PRD |
| **安全默认值** | 仓库中的配置必须以安全状态为默认值（debug=false、日志级别=warn） |
| **环境差异外部化** | 环境间的差异通过环境变量/Secrets Manager 注入，不通过不同文件或分支体现 |
| **可审计性** | 所有变更可追溯，测试代码受版本控制，变更有记录 |

### 1.2 适用标准参考

- ISO 27001:2022 — 信息安全管理（A.8.4 源代码访问控制）
- SOC 2 Type II — CC6.1 逻辑访问控制
- CIS Docker Benchmark v1.6 — 容器安全基线
- OWASP ASVS v4.0 — 应用安全验证标准
- PCI DSS v4.0 — 6.2.2 软件开发安全

---

## 二、文件分类与准入准则

所有文件按敏感程度分为四级：

| 级别 | 分类 | 示例 | 是否允许入库 |
|------|------|------|-------------|
| **L1 秘密** | 凭据、密钥、证书私钥 | 数据库密码、API Key、.netrc、*.pem（私钥）、.env | **绝对禁止** |
| **L2 敏感** | 基础设施地址、内网拓扑 | 内网 IP、VPN 配置、Registry 地址、Nomad/K8s 端点 | **禁止硬编码** |
| **L3 受控** | 部署配置、构建参数 | Dockerfile、CI 配置、Argo/Helm 配置 | **允许，但不含 L1/L2 信息** |
| **L4 公开** | 业务代码、测试、文档 | *.go、*_test.go、README.md | **必须入库** |

### 判定流程

```
文件准入检查 ──► 是否含凭据/密钥？ ──Yes──► 🔴 禁止入库
                      │
                     No
                      │
               是否含内网IP/地址？ ──Yes──► 🟡 改用占位符/环境变量
                      │
                     No
                      │
               是否为构建/部署配置？ ──Yes──► 🟢 允许（审查后入库）
                      │
                     No
                      │
               ✅ 正常入库
```

---

## 三、禁止入库清单

### 3.1 绝对禁止（L1）

以下文件/内容**在任何情况下不得出现在 Git 仓库中**（包括 Git 历史）：

| 类型 | 文件模式 | 说明 |
|------|---------|------|
| 环境变量文件 | `.env`、`.env.*`（非 `.env.example`） | 可能含数据库密码、API Key |
| 凭据文件 | `.netrc`、`credentials.json`、`serviceAccount.json` | Git/云服务凭据 |
| 私钥文件 | `*.pem`（私钥）、`*.key`、`*.p12`、`*.pfx`、`*.jks` | 加密私钥 |
| 数据库连接串 | 含 `password=xxx` 或 `user:pass@` 格式的任何文件 | 数据库凭据 |
| Token/Secret | 含 `token`、`secret`、`apikey` 值的配置文件 | 访问令牌 |
| 私有配置目录 | `data/private/`、`config/secrets/` | 私有配置整个目录 |
| SSH 密钥 | `id_rsa`、`id_ed25519`、`known_hosts` | SSH 认证 |

### 3.2 禁止硬编码（L2）

以下信息**不得以明文硬编码**形式出现，必须使用环境变量或配置中心：

| 类型 | 错误示例 | 正确做法 |
|------|---------|---------|
| 内网 IP | `risk_grpc_url = "10.1.9.121:9015"` | `risk_grpc_url = "${RISK_GRPC_URL}"` |
| 容器仓库地址 | `FROM 324037306079.dkr.ecr...` | `FROM ${ECR_REGISTRY}/ops/ubuntu:24.0` |
| 编排系统地址 | `-address=http://10.2.9.70:4646` | `-address=${NOMAD_ADDR}` |
| Docker Registry | `DOCKER_REGISTRY ?= registry.894568.xyz` | `DOCKER_REGISTRY ?= ${DOCKER_REGISTRY}` |
| 数据库地址 | `dsn_rw = "root:pass@tcp(10.x.x.x:3306)/..."` | 通过 Secrets Manager 注入 |

### 3.3 不应入库

| 类型 | 说明 |
|------|------|
| 安全审计报告 | `*_Code_Review_Report.*` — 含漏洞详情，应存于安全管理平台 |
| 编译产物 | `main`、`*.exe`、`*.out`、`vendor/`（Go）、`build/`（Java） |
| IDE 配置 | `.idea/`、`.vscode/`（个人偏好，非团队标准） |
| 调试日志 | `*.log`、`debug/output/` |
| 临时文件 | `*.tmp`、`*.swp`、`.DS_Store` |

---

## 四、必须入库清单

以下文件**必须存在于仓库中**，缺失将被审计标记：

### 4.1 安全与合规文件

| 文件 | 用途 | 必要性 |
|------|------|--------|
| `README.md` | 项目说明、安全开发指引、本地环境搭建指南 | **强制** |
| `SECURITY.md` | 安全漏洞上报流程、负责人联系方式 | **强制** |
| `CHANGELOG.md` | 版本变更记录（审计追溯） | **强制** |
| `LICENSE` | 开源许可证声明（即使是私有仓库） | 推荐 |

### 4.2 配置安全文件

| 文件 | 用途 | 必要性 |
|------|------|--------|
| `.gitignore` | 版本控制忽略规则（见[第五章](#五gitignore-规范)） | **强制** |
| `.dockerignore` | Docker 构建上下文排除（见[第六章](#六dockerignore-规范)） | **强制** |
| `.gitleaks.toml` | 秘钥泄露扫描规则 | **强制** |
| `.pre-commit-config.yaml` | 提交前检查钩子 | **强制** |

### 4.3 配置模板文件

| 文件 | 用途 | 必要性 |
|------|------|--------|
| `config.example.toml` 或 `.env.example` | 配置项说明（值为空或占位符） | **强制** |
| `docker-compose.yml`（开发用） | 标准化本地开发环境 | 推荐 |

### 4.4 测试文件

| 规则 | 说明 |
|------|------|
| `*_test.go`（Go）、`*Test.java`（Java）、`*_test.dart`（Flutter） | **必须纳入版本控制** |
| `.gitignore` 中**禁止**出现 `*_test.go` 等测试文件忽略规则 | 测试是质量的证据 |

---

## 五、.gitignore 规范

### 5.1 标准模板（Go 项目）

```gitignore
# ========================================
# L1: 秘密文件（绝对禁止入库）
# ========================================
.env
.env.*
!.env.example
.netrc
*.pem
*.key
*.p12
*.pfx
*.jks
credentials.json
serviceAccount.json
data/private/

# ========================================
# L2: 敏感配置
# ========================================
.nomad.hcl

# ========================================
# 构建产物
# ========================================
main
/vendor/
*.exe
*.out
*.bin
*.tar.gz

# ========================================
# 审计报告（不入库，存安全平台）
# ========================================
*_Code_Review_Report.*

# ========================================
# IDE & 系统文件
# ========================================
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# ========================================
# 扫描产物
# ========================================
.scannerwork/

# ========================================
# ⚠️ 注意：以下文件不得忽略
# ========================================
# *_test.go          ← 禁止！测试必须入库
# go.sum             ← 禁止！依赖锁定必须入库
# Dockerfile         ← 禁止！构建定义必须入库
```

### 5.2 标准模板（Java/Spring Boot 项目）

```gitignore
# L1: 秘密文件
.env
.env.*
!.env.example
.netrc
*.pem
*.key
src/main/resources/application-local.yml
src/main/resources/application-dev.yml
**/secrets/

# 构建产物
target/
build/
*.jar
*.war
*.class

# IDE
.idea/
*.iml
.vscode/
.settings/
.classpath
.project

# 审计报告
*_Code_Review_Report.*
```

### 5.3 标准模板（Flutter 项目）

```gitignore
# L1: 秘密文件
.env
.env.*
*.jks
*.keystore
key.properties
google-services.json
GoogleService-Info.plist

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.iml

# IDE
.idea/
.vscode/
*.swp
```

---

## 六、.dockerignore 规范

```dockerignore
# Git 元数据
.git
.gitignore

# 秘密文件
data/private/
.env
.env.*
.netrc
*.pem
*.key

# 文档与报告
*.md
*.pdf
LICENSE
CHANGELOG.md

# 构建与部署配置
Makefile
.argo.yaml
.gitlab-ci.yml
.nomad.hcl
docker-compose*.yml

# IDE
.idea/
.vscode/

# 测试（生产镜像不需要）
*_test.go
**/*_test.go
**/testdata/

# 系统文件
.DS_Store
```

---

## 七、配置管理规范

### 7.1 三层配置架构

```
┌─────────────────────────────────────────┐
│  第三层：Secrets Manager / Vault        │  ← 凭据（数据库密码、API Key）
│  （运行时注入，代码库中零痕迹）           │
├─────────────────────────────────────────┤
│  第二层：环境变量                        │  ← 环境差异（IP、端口、开关）
│  （CI/CD 平台 / K8s ConfigMap 注入）     │
├─────────────────────────────────────────┤
│  第三层：代码库中的配置文件               │  ← 安全默认值（不含敏感信息）
│  （config.toml / application.yml）       │
└─────────────────────────────────────────┘
```

### 7.2 配置文件入库规则

| 配置类型 | 入库要求 | 示例 |
|----------|---------|------|
| **默认配置** | 允许入库，值必须为安全默认 | `debug = false`, `log_level = "warn"` |
| **配置模板** | 允许入库，值为空或占位符 | `dsn_rw = ""`, `api_key = "${API_KEY}"` |
| **环境私有配置** | **禁止入库** | `data/private/*.toml`, `.env` |
| **凭据配置** | **绝对禁止入库** | 数据库密码、token |

### 7.3 安全默认值标准

仓库中的配置文件必须采用以下**安全默认值**：

```toml
# ✅ 正确：安全默认值（适用于生产）
[debug]
debug = false
gin_debug = false
request_log = false
response_log = false
db_log = false
log_min_level = "warn"
swagger = false

# ✅ 正确：连接参数（不含凭据）
[db]
migrate_db = "false"
max_idle = 10
max_open = 20
```

```toml
# 🔴 错误：调试默认值（当前 UAT 现状）
[debug]
debug = true            # ← 禁止
gin_debug = true        # ← 禁止
log_min_level = "trace" # ← 禁止
```

### 7.4 AWS 凭证配置模板

**安全审计要求**：生产环境优先使用 IAM 角色，禁止在配置/模板中写入长期 Access Key；使用 AWS Secrets Manager 时通过 `SECRET_NAME` 注入，不在代码库中留痕。

| 场景 | 推荐方式 | 禁止方式 |
|------|----------|----------|
| ECS/EKS 上运行 | 使用任务角色/Pod IAM Role，无需配置 Access Key | 在环境变量中配置 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |
| 本地/CI 需访问 AWS | 使用 `aws configure` 或临时凭证（SSO/AssumeRole），不提交凭证文件 | 在 `.env` 或配置文件中写死 AK/SK |
| 应用读取 DB 密码等 | 通过 Secrets Manager：设置 `SECRET_NAME`，运行时从该 Secret 拉取 JSON 并覆盖环境变量 | 在配置模板中写 `password=xxx` 或占位符密码 |

**配置模板示例（.env.example）**：

```bash
# AWS 凭证：生产环境使用 IAM 角色，不在此配置 AK/SK
# AWS_ACCESS_KEY_ID=          # 仅本地开发临时使用，禁止提交
# AWS_SECRET_ACCESS_KEY=      # 仅本地开发临时使用，禁止提交
AWS_REGION=ap-east-1

# 通过 Secrets Manager 注入的配置（运行时由平台设置）
SECRET_NAME=
```

**代码侧**：应用启动时若 `SECRET_NAME` 非空，则从 AWS Secrets Manager 拉取配置并合并到环境变量；不在此处写任何真实凭证。

### 7.5 Docker Registry 凭证模板

**安全审计要求**：Registry 地址与登录凭据不得硬编码，须通过环境变量或 CI/CD Secret Variables 注入。

**CI 变量（GitLab：Settings → CI/CD → Variables）**：

| 变量名 | 说明 | Masked |
|--------|------|--------|
| `AWS_ACCOUNT_ID` | ECR 所属账号（若用 ECR） | 否 |
| `AWS_REGION` | ECR 区域 | 否 |
| `DOCKER_REGISTRY` | 通用 Registry 地址，如 `$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com` | 否 |
| 登录密码 | ECR 使用 `aws ecr get-login-password`，其他 Registry 使用 CI 的 Secret Variable | 是 |

**CI 内登录示例（ECR）**：

```yaml
# 使用 CI 变量，不硬编码账号/区域
- aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
- docker tag $ECR_REPOSITORY:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
- docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
```

**Makefile 示例**：

```makefile
DOCKER_REGISTRY ?= $(DOCKER_REGISTRY)
IMAGE_NAME     ?= $(IMAGE_NAME)
IMAGE_TAG      ?= $(IMAGE_TAG)
# 禁止：DOCKER_REGISTRY ?= registry.example.com
```

### 7.6 私钥安全处理规范

**安全审计要求**：RSA/ECDSA 等私钥不得通过配置文件路径明文传入；优先从环境变量或 Secrets Manager 读取，使用后尽量从内存中清除敏感字节。

| 要求 | 说明 |
|------|------|
| 不通过配置文件传入私钥 | 禁止在 `application.yml` / `config.toml` 中配置 `private_key_path` 或私钥内容供生产使用 |
| 来源优先级 | 环境变量（如 `SIGNING_PRIVATE_KEY`）或 Secrets Manager / Vault → 运行时注入 |
| 内存安全 | 使用 `[]byte` 或可清零结构（如 Java 的 `char[]`），用毕清零；避免长期以 `string` 形式保存 |
| 日志与错误 | 禁止将私钥或完整 PEM 写入日志；错误信息中仅可包含“加载失败”等脱敏描述 |

**Go 示例（从环境变量读取并清零）**：

```go
func loadPrivateKeyFromEnv(envKey string) ([]byte, error) {
    raw := os.Getenv(envKey)
    if raw == "" {
        return nil, fmt.Errorf("private key not set (%s)", envKey)
    }
    block, _ := pem.Decode([]byte(raw))
    if block == nil {
        return nil, fmt.Errorf("invalid PEM")
    }
    key := make([]byte, len(block.Bytes))
    copy(key, block.Bytes)
    // 使用完毕后调用: clearBytes(key)
    return key, nil
}
func clearBytes(b []byte) { for i := range b { b[i] = 0 } }
```

**配置模板中仅占位说明**：

```bash
# 私钥由 Secrets Manager 或运行时环境注入，不在此填写
# SIGNING_PRIVATE_KEY=
```

---

## 八、Dockerfile 规范

### 8.1 核心原则

| 规则 | 说明 |
|------|------|
| **UAT 与 PRD 使用同一个 Dockerfile** | 禁止 `Dockerfile-uat`、`Dockerfile-prod` 等环境专用文件 |
| **凭据使用 BuildKit Secrets** | `RUN --mount=type=secret,id=xxx`，禁止 `COPY .netrc` |
| **非 root 用户运行** | `USER` 指令必须在 `ENTRYPOINT` 之前 |
| **最小化镜像** | 使用多阶段构建，生产镜像不含构建工具 |
| **不硬编码镜像地址** | 基础镜像通过 `ARG` 参数化 |

### 8.2 标准 Dockerfile 模板（Go）

```dockerfile
# === 构建阶段 ===
FROM golang:1.24-bullseye AS builder

ARG GOPROXY=https://goproxy.cn,direct

RUN useradd -m builder
WORKDIR /src

RUN go env -w GOPRIVATE=gitlab.finex18.com
RUN go env -w GOPROXY=${GOPROXY}

# 使用 BuildKit secrets（不将 .netrc 写入镜像层）
RUN --mount=type=secret,id=netrc \
    if [ -f /run/secrets/netrc ]; then \
        cp /run/secrets/netrc /home/builder/.netrc && \
        chown builder:builder /home/builder/.netrc && \
        chmod 600 /home/builder/.netrc; \
    fi

COPY go.mod go.sum ./
COPY . .

RUN chown -R builder:builder /src
USER builder
RUN go build -a -o main .

# === 运行阶段 ===
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tzdata ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m exchange

WORKDIR /www
COPY --from=builder --chown=root:root /src/data/config ./data/config/
COPY --from=builder --chown=root:root /src/main .

RUN chmod -R a-w ./data/config && chmod a-w ./main
RUN chown -R exchange:exchange .

# USER 必须在 ENTRYPOINT 之前
USER exchange

ENTRYPOINT ["./main"]
```

### 8.3 禁止做法

```dockerfile
# 🔴 禁止：直接复制凭据文件
COPY .netrc /home/builder/.netrc

# 🔴 禁止：硬编码 ECR/Registry 地址
FROM 324037306079.dkr.ecr.ap-east-1.amazonaws.com/ops/ubuntu:24.0

# 🔴 禁止：以 root 运行（USER 在 ENTRYPOINT 之后无效）
ENTRYPOINT ["./main"]
USER exchange

# 🔴 禁止：复制私有配置到镜像
COPY data/private/ ./data/private/
```

---

## 九、CI/CD 配置规范

### 9.1 CI 中的凭据管理

| 规则 | 说明 |
|------|------|
| 使用 CI 平台的 Secret Variables | GitLab CI: Settings → CI/CD → Variables (Masked + Protected) |
| 禁止在 `.gitlab-ci.yml` 中硬编码凭据 | 使用 `$CI_REGISTRY_PASSWORD` 等内置变量 |
| 禁止在构建日志中打印凭据 | 避免 `echo $PASSWORD` |

### 9.2 Makefile 规范

```makefile
# ✅ 正确：使用环境变量
DOCKER_REGISTRY ?= $(DOCKER_REGISTRY)
NOMAD_ADDR      ?= $(NOMAD_ADDR)

# 🔴 错误：硬编码地址
# DOCKER_REGISTRY ?= registry.894568.xyz
# -address=http://10.2.9.70:4646
```

---

## 十、泄露防护机制

### 10.1 Pre-commit Hooks（强制）

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files
        args: ['--maxkb=500']
```

### 10.2 Gitleaks 配置（强制）

```toml
# .gitleaks.toml
title = "Exchange Platform Gitleaks Config"

[allowlist]
  description = "Allowed patterns"
  paths = [
    '''\.env\.example$''',
    '''private\.toml\.example$''',
  ]

[[rules]]
  id = "database-dsn"
  description = "Database connection string with password"
  regex = '''(?i)(dsn|database_url|db_url)\s*=\s*["']?\w+:\w+@'''
  tags = ["database", "credential"]

[[rules]]
  id = "private-ip"
  description = "Private IP address"
  regex = '''(?:10|172\.(?:1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.\d{1,3}'''
  tags = ["infrastructure"]

[[rules]]
  id = "api-token"
  description = "API Token/Key"
  regex = '''(?i)(api[_-]?key|api[_-]?token|access[_-]?token)\s*[:=]\s*["']?[a-zA-Z0-9_\-]{20,}'''
  tags = ["token"]
```

### 10.3 CI Pipeline 集成扫描

```yaml
# .gitlab-ci.yml 中增加
gitleaks-scan:
  stage: test
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --verbose
  allow_failure: false
```

---

## 十一、Git 历史合规

### 11.1 历史凭据清理

如果 Git 历史中已包含凭据，必须进行清理：

```bash
# 方式一：BFG Repo-Cleaner（推荐）
bfg --delete-files "private.toml" --no-blob-protection
bfg --replace-text passwords.txt --no-blob-protection
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# 方式二：git filter-repo
git filter-repo --path data/private/ --invert-paths
```

### 11.2 清理后验证

```bash
# 验证历史中不再含凭据
git log --all -p | grep -E "(password|dsn_rw|secret|token)" | head -20
# 应返回空

# 使用 gitleaks 扫描全历史
gitleaks detect --source . --log-opts="--all"
```

### 11.3 注意事项

- 历史清理后需要 **force push**，团队需同步
- 已泄露的凭据必须 **立即轮换**（更换密码/Token）
- 清理不能替代轮换——假设已被读取

---

## 十二、标准目录结构模板

### 12.1 Go 微服务

```
exchange-xxx-service/
├── .dockerignore                  # Docker 构建排除
├── .gitignore                     # Git 忽略（遵循第五章规范）
├── .gitleaks.toml                 # 秘钥泄露扫描配置
├── .gitlab-ci.yml                 # CI 配置
├── .pre-commit-config.yaml        # Pre-commit 钩子
├── CHANGELOG.md                   # 变更记录
├── Dockerfile                     # 唯一的 Dockerfile（UAT+PRD 通用）
├── Makefile                       # 构建脚本（无硬编码地址）
├── README.md                      # 项目说明 + 安全指引
├── SECURITY.md                    # 安全漏洞上报流程
├── go.mod
├── go.sum
├── main.go
├── cmd/                           # 入口命令
├── component/                     # 组件
├── consts/                        # 常量
├── core/                          # 核心注入
├── data/
│   ├── config/
│   │   └── config.toml            # 安全默认配置（debug=false）
│   └── config.example/
│       └── private.toml.example   # 配置模板（值为空/占位符）
├── db/                            # 数据库层
├── service/                       # 业务逻辑
│   ├── xxx_service.go
│   └── xxx_service_test.go        # 测试文件（必须入库）
└── deploy/                        # 部署描述（可选）
    ├── .argo.yaml
    └── k8s/
```

### 12.2 Java/Spring Boot 微服务

```
exchange-xxx-core/
├── .dockerignore
├── .gitignore
├── .gitleaks.toml
├── .gitlab-ci.yml
├── .pre-commit-config.yaml
├── CHANGELOG.md
├── Dockerfile                     # 唯一
├── README.md
├── SECURITY.md
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/
│   │   ├── proto/
│   │   └── resources/
│   │       ├── application.yml    # 安全默认配置
│   │       └── application.yml.example  # 配置模板
│   └── test/                      # 测试（必须入库）
└── deploy/
```

### 12.3 Flutter 移动端

```
exchange-front-app/
├── .dockerignore                  # 如有 CI 构建
├── .gitignore
├── .gitleaks.toml
├── CHANGELOG.md
├── README.md
├── SECURITY.md
├── android/
│   └── app/
│       └── proguard-rules.pro     # 混淆规则（必须启用）
├── lib/                           # 业务代码
├── test/                          # 测试（必须入库）
└── pubspec.yaml
```

---

## 十三、合规检查清单

### 13.1 代码审计前自查表

每次提交审计前，项目负责人必须完成以下检查：

| # | 检查项 | 通过标准 | ✓/✗ |
|---|--------|---------|-----|
| 1 | 仓库中无凭据文件 | `data/private/`、`.env`、`.netrc` 不在版本控制中 | |
| 2 | Git 历史无泄露 | `gitleaks detect --log-opts="--all"` 通过 | |
| 3 | `.gitignore` 合规 | 包含所有 L1/L2 文件规则，不包含 `*_test.*` | |
| 4 | `.dockerignore` 存在 | 排除敏感文件和非必要文件 | |
| 5 | Dockerfile 唯一 | 无 `Dockerfile-uat`、`Dockerfile-prod` 等变体 | |
| 6 | Dockerfile 安全 | 使用 BuildKit secrets、非 root 运行 | |
| 7 | 配置安全默认值 | `debug=false`、`log_level=warn`、`swagger=false` | |
| 8 | 无硬编码地址 | Makefile/配置中无内网 IP、Registry 地址 | |
| 9 | 测试文件入库 | `*_test.go` / `*Test.java` 受版本控制 | |
| 10 | 安全文档完整 | `README.md`、`SECURITY.md`、`CHANGELOG.md` 存在 | |
| 11 | Pre-commit 钩子 | `.pre-commit-config.yaml` 包含 gitleaks | |
| 12 | CI 含安全扫描 | Pipeline 包含 gitleaks 扫描步骤 | |
| 13 | 无审计报告入库 | `*_Code_Review_Report.*` 不在仓库中 | |
| 14 | 依赖锁定 | `go.sum` / `pom.xml` lock / `pubspec.lock` 已提交 | |

### 13.2 自动化检查脚本

```bash
#!/bin/bash
# audit-check.sh — 代码库合规快速检查

echo "=== Exchange 代码库合规检查 ==="
FAIL=0

# 检查 1: 凭据文件
for f in .env .netrc data/private/private.toml; do
  if git ls-files --error-unmatch "$f" 2>/dev/null; then
    echo "🔴 FAIL: 凭据文件 $f 在版本控制中"
    FAIL=1
  fi
done

# 检查 2: .gitignore 存在且不忽略测试
if [ ! -f .gitignore ]; then
  echo "🔴 FAIL: .gitignore 不存在"
  FAIL=1
elif grep -q '\*_test\.go' .gitignore; then
  echo "🔴 FAIL: .gitignore 忽略了测试文件"
  FAIL=1
fi

# 检查 3: .dockerignore 存在
if [ ! -f .dockerignore ]; then
  echo "🟡 WARN: .dockerignore 不存在"
fi

# 检查 4: 无环境专用 Dockerfile
for f in Dockerfile-uat Dockerfile-prod Dockerfile-dev; do
  if [ -f "$f" ]; then
    echo "🔴 FAIL: 存在环境专用 $f"
    FAIL=1
  fi
done

# 检查 5: 配置安全默认值
if grep -q 'debug = true' data/config/config.toml 2>/dev/null; then
  echo "🔴 FAIL: config.toml 中 debug=true"
  FAIL=1
fi

# 检查 6: 安全文档
for f in README.md SECURITY.md CHANGELOG.md; do
  if [ ! -f "$f" ]; then
    echo "🟡 WARN: $f 不存在"
  fi
done

# 检查 7: 硬编码 IP
if grep -rn '10\.\|172\.1[6-9]\.\|172\.2[0-9]\.\|172\.3[01]\.\|192\.168\.' \
   Makefile *.yaml *.yml data/config/ 2>/dev/null | grep -v '.git'; then
  echo "🟡 WARN: 发现硬编码内网 IP"
fi

if [ $FAIL -eq 0 ]; then
  echo "✅ 所有强制检查通过"
else
  echo "❌ 存在不合规项，请修复后再提交审计"
  exit 1
fi
```

---

## 十四、违规处理

### 14.1 违规分级

| 级别 | 描述 | 处理时限 | 示例 |
|------|------|---------|------|
| **Critical** | 生产凭据泄露 | **立即**（2小时内轮换凭据 + 清理历史） | 数据库密码入库 |
| **High** | 敏感配置入库 | 24 小时 | 内网 IP 硬编码、debug=true 作为默认值 |
| **Medium** | 缺失安全机制 | 1 周 | 无 .dockerignore、无 pre-commit |
| **Low** | 文档缺失 | 2 周 | 无 SECURITY.md、无 CHANGELOG.md |

### 14.2 凭据泄露应急流程

```
发现凭据泄露
    │
    ├──► 1. 立即轮换凭据（更换密码/Token/Key）
    │
    ├──► 2. 从 Git 历史中清理（BFG/filter-repo）
    │
    ├──► 3. Force push 并通知团队同步
    │
    ├──► 4. 检查访问日志（凭据是否已被利用）
    │
    └──► 5. 填写安全事件报告
```

---

## 附录：与当前项目的差距对照

| 准则要求 | exchange-auth-service 现状 | 差距 |
|----------|--------------------------|------|
| 零凭据入库 | `data/private/private.toml` 含 DB 密码 | 🔴 不合规 |
| .gitignore 不忽略测试 | `*_test.go` 在忽略列表中 | 🔴 不合规 |
| 唯一 Dockerfile | 存在 `Dockerfile` + `Dockerfile-uat` | 🔴 不合规 |
| 安全默认配置 | `debug=true`, `log_min_level=trace` | 🔴 不合规 |
| 无硬编码地址 | Makefile 含 Registry 和 Nomad IP | 🔴 不合规 |
| .dockerignore 存在 | 不存在 | 🔴 不合规 |
| 安全文档完整 | 无 README/SECURITY/CHANGELOG | 🔴 不合规 |
| Pre-commit 钩子 | 不存在 | 🔴 不合规 |
| CI 安全扫描 | 不存在 | 🔴 不合规 |
| Git 历史干净 | 历史中有 DB 密码 | 🔴 不合规 |
| 审计报告不入库 | PDF/MD 报告在仓库中 | 🟡 不合规 |

---

**文档维护人:** 安全团队  
**下次审查日期:** 每季度审查一次  
**变更记录:** v1.0 — 初始版本（2026-02-09）
