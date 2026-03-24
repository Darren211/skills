# Docker Registry 凭证模板

## 安全要求

- Registry 地址与登录凭据**不得硬编码**，须通过环境变量或 CI/CD Secret Variables 注入。
- 禁止在仓库中写入真实密码或 token。

## GitLab CI 变量（Settings → CI/CD → Variables）

| 变量名 | 说明 | Masked | Protected |
|--------|------|--------|-----------|
| `AWS_ACCOUNT_ID` | ECR 账号 ID（使用 ECR 时） | 否 | 按需 |
| `AWS_REGION` | ECR 区域 | 否 | 否 |
| `DOCKER_REGISTRY` | 通用 Registry 地址 | 否 | 否 |
| 登录密码 | ECR 用 get-login-password；其他 Registry 用单独 Secret Variable | **是** | 是 |

## ECR 登录与推送（示例片段）

```yaml
# 使用 CI 变量，不硬编码账号/区域
push_to_ecr:
  script:
    - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    - docker tag $ECR_REPOSITORY:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
    - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
```

## 通用 Registry（非 ECR）

```yaml
# 用户名/密码来自 CI Secret Variables，例如 DOCKER_REGISTRY_USER / DOCKER_REGISTRY_PASSWORD
- echo "$DOCKER_REGISTRY_PASSWORD" | docker login --username "$DOCKER_REGISTRY_USER" --password-stdin "$DOCKER_REGISTRY"
```

## Makefile

```makefile
DOCKER_REGISTRY ?= $(DOCKER_REGISTRY)
IMAGE_NAME     ?= $(IMAGE_NAME)
IMAGE_TAG      ?= $(IMAGE_TAG)
# 禁止：DOCKER_REGISTRY ?= registry.example.com
```
