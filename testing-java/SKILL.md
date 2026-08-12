---
name: testing-java
description: Java 测试生成流程 — 根据业务代码系统性生成单元测试和集成测试
---

# 测试生成 SOP（Standard Operating Procedure）

> 当用户提出"写测试"、"生成单元测试"、"给 XXX 写测试用例"等测试相关请求时，严格按以下流程执行。

---

## 前置：需求澄清（强制）

> ⚠️ **必须先执行 `requirement-clarify-java` Skill 中的澄清协议，通过后方可进入正式执行流程。**
> 
> 对照 `requirement-clarify-java` 中「testing 专属问题清单」的 🔴 必问项（T-01 ~ T-02）进行信息充分度自检，
> 缺失项必须向用户追问，**禁止跳过此环节直接写测试代码**。

---

## 步骤 1：分析目标代码

### 1.1 理解业务逻辑
- 阅读待测试的类/方法，理解其业务功能
- 识别所有公开方法（public methods）
- 梳理每个方法的：
  - 正常执行路径
  - 异常分支（抛出异常的条件）
  - 边界条件（空值、极值、临界值）

### 1.2 识别依赖关系
- 识别需要 Mock 的外部依赖（数据库、HTTP 调用、消息队列等）
- 识别需要 Stub 的配置项
- 确定测试类型：
  - **单元测试**：纯逻辑，Mock 所有外部依赖
  - **集成测试**：需要启动 Spring 上下文或连接数据库

---

## 步骤 2：设计测试用例（必须先输出）

在写测试代码前，**先输出测试用例设计表**，等待用户确认后再编码：

```markdown
## 测试用例设计

### 目标类：XxxServiceImpl

| 用例编号 | 目标方法 | 场景分类 | 测试场景描述 | 预期结果 |
|:---:|----------|:---:|------------|----------|
| TC-001 | createUser | 正常 | 正常创建用户 | 返回用户ID，数据库有记录 |
| TC-002 | createUser | 异常 | 用户名已存在 | 抛出 BusinessException(100001) |
| TC-003 | createUser | 边界 | 用户名长度为最大值(50字符) | 正常创建 |
| TC-004 | createUser | 空值 | 入参 DTO 为 null | 抛出 IllegalArgumentException |
| TC-005 | getUserById | 正常 | 用户存在 | 返回用户信息 |
| TC-006 | getUserById | 异常 | 用户不存在 | 抛出 BusinessException(100002) |
| TC-007 | getUserById | 边界 | ID 为 0 或负数 | 抛出参数校验异常 |

### 覆盖率目标
- 行覆盖率: ≥ 80%
- 分支覆盖率: ≥ 70%
```

**等待用户确认后再编写测试代码。**

---

## 步骤 3：编写测试代码

### 3.1 技术栈约定

| 组件 | 技术选型 |
|------|----------|
| 测试框架 | JUnit 5 (`@Test`, `@DisplayName`, `@ParameterizedTest`) |
| Mock 框架 | Mockito (`@Mock`, `@InjectMocks`, `when().thenReturn()`) |
| 断言库 | AssertJ (`assertThat().isEqualTo()`) 或 JUnit 原生 |
| Spring 测试 | `@SpringBootTest`（集成测试时使用，尽量少用） |
| 数据库测试 | `@DataJpaTest` / H2 内存数据库 |

### 3.2 文件与命名规范

- 测试文件路径: `src/test/java/` 下与源码同包
- 测试类名: `XxxServiceTest` / `XxxControllerTest`
- 测试方法名: `should_预期行为_when_前置条件`
  - 示例: `should_throwException_when_usernameAlreadyExists`
  - 示例: `should_returnUserInfo_when_userExists`
- 测试类添加 `@DisplayName("XxxService 单元测试")` 注解

### 3.3 代码结构规范

每个测试方法严格遵循 **Given-When-Then** 三段式结构：

```java
@Test
@DisplayName("用户名已存在时应抛出业务异常")
void should_throwException_when_usernameAlreadyExists() {
    // Given - 准备测试数据和 Mock 行为
    CreateUserReqDTO req = new CreateUserReqDTO();
    req.setUsername("existingUser");
    when(userRepository.existsByUsername("existingUser")).thenReturn(true);

    // When & Then - 执行并验证
    BusinessException exception = assertThrows(BusinessException.class,
        () -> userService.createUser(req));
    
    assertThat(exception.getCode()).isEqualTo(100001);
    assertThat(exception.getMessage()).contains("用户名已存在");
    
    // Verify - 验证交互（可选）
    verify(userRepository, never()).save(any());
}
```

### 3.4 测试覆盖要求

| 代码层 | 覆盖要求 | 说明 |
|--------|----------|------|
| Service 层 | 行覆盖 ≥ 80% | 核心业务逻辑，重点测试 |
| 工具类 | 行覆盖 ≥ 90% | 纯函数，容易覆盖 |
| Controller 层 | 验证入参和响应格式 | 使用 MockMvc 测试 |
| Repository 层 | 关键查询语句 | 使用 `@DataJpaTest` + H2 |

### 3.5 必须覆盖的场景类型

- ✅ **正常路径 (Happy Path)**: 输入合法，流程正常完成
- ✅ **异常路径 (Error Path)**: 业务规则不满足，抛出业务异常
- ✅ **边界值 (Boundary)**: 最大值、最小值、临界值
- ✅ **空值/无效值 (Null/Invalid)**: null、空字符串、空集合
- ✅ **权限场景 (Authorization)**: 无权限操作应被拒绝（如适用）

---

## 步骤 4：输出交付

测试代码完成后，输出以下信息：

### 4.1 测试完成摘要

输出格式：

#### 生成的测试文件

| 文件路径 | 测试数量 | 覆盖方法 |
|----------|:---:|----------|

#### 覆盖情况

- 总测试用例数: X 个
- 正常路径: X 个
- 异常路径: X 个
- 边界值: X 个
- 空值: X 个

### 4.2 运行方式

```bash
# 运行全部测试
mvn test -pl [module]

# 运行单个测试类
mvn test -pl [module] -Dtest=XxxServiceTest
```

---

### 步骤 5：生成任务交付文档

> ⚠️ **必须在所有步骤完成后执行**，使用 Write 工具将文档写入 `docs/` 目录。

文件命名规则：`docs/{YYYY-MM-DD}-test-{测试模块简称}.md`（模块简称用英文小写短横线分隔，如 `user-service-test`、`order-utils-test`）。

文档模板如下（按实际情况填写，无变更的章节保留标题并标注"无"）：

```markdown
# 任务交付文档

## 基本信息
- **任务类型**: 测试生成
- **执行日期**: YYYY-MM-DD
- **执行 Skill**: testing

---

## 一、任务描述
[本次测试生成的背景和目的，测试的业务模块说明]

## 二、测试方案

### 2.1 测试策略
- **测试类型**: [单元测试 / 集成测试 / 混合]
- **技术栈**: [JUnit 5 + Mockito + AssertJ 等]
- **覆盖率目标**: 行覆盖率 ≥ X%，分支覆盖率 ≥ X%

### 2.2 测试用例设计
| 用例编号 | 目标方法 | 场景分类 | 测试场景描述 | 预期结果 |
|:---:|----------|:---:|------------|----------|

## 三、变更清单

### 3.1 文件变更
| 文件路径 | 变更类型 | 变更说明 |
|----------|:---:|----------|

### 3.2 配置变更（测试配置）
| 配置项 | 变更类型 | 值/默认值 | 说明 |
|--------|:---:|----------|------|

### 3.3 依赖变更（测试依赖）
| GroupId | ArtifactId | 版本 | 变更类型 | 用途 |
|---------|------------|------|:---:|------|

## 四、测试覆盖统计
- **总测试用例数**: X 个
- **正常路径**: X 个
- **异常路径**: X 个
- **边界值**: X 个
- **空值/无效值**: X 个

## 五、运行方式
[列出运行测试的命令]

## 六、风险评估
- **覆盖盲区**: [哪些场景未覆盖，原因]
- **Mock 局限性**: [Mock 无法模拟的真实场景]
- **环境依赖**: [是否依赖特定环境才能运行]

## 七、后续建议
- [需要后续跟进的事项，如补充集成测试、性能测试、提升覆盖率等]
```
