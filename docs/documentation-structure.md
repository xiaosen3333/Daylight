## Daylight 文档目录结构设计

### 1. 目标
- 为 Swift 客户端与轻后端提供清晰、可扩展的文档导航；支持 MVP 到 1.0/2.0 的演进，不重复、不遗漏关键领域。

### 2. 推荐文档结构（存放于 docs/）
- `Daylight.md`：产品架构总览（现有）；包含阶段路线、核心原则、宏观模型。
- `Daylight-architecture-swift.md`：Swift 客户端分层架构；包含数据流示例、Repository 策略、并发与迁移策略、目录示例。
- `design-system.md`：颜色/字体/间距/主题接口；组件规范、命名规则、动效参数、无障碍（Dynamic Type/VoiceOver）要求。
- `data-models.md`：领域模型定义（User/Subscription/Entitlement/DayRecord/Settings）；字段说明、约束、默认值、version/schemaVersion 规则、演进示例。
- `storage-and-migration.md`：本地存储方案（JSON/CoreData/Realm 选型）、文件命名、schemaVersion、迁移步骤、回滚/容错、待同步队列格式。
- `api.md`：REST `/v1/...` 规范；认证（匿名/后续账号）、分页、错误码、DTO、请求示例、速率限制、重试策略。
- `auth-and-membership.md`：匿名登录预留、账号注册、订阅与权益（FeatureGate）；`isPro` 计算、付费墙策略、失败降级。
- `project-structure.md`：代码目录规范（App/Features/Domain/Data/DesignSystem/Core）；命名/依赖约定、模块边界、禁止事项（UI 直连数据源等）。
- `testing.md`：单测/集成/UI/性能测试策略，覆盖率目标、Mock 约定、关键用例清单。
- `release-and-config.md`：环境配置（dev/stage/prod）、证书/配置描述、CI/CD 流程、版本命名、打包脚本、发布 checklist。

### 3. 规划与维护
- 新功能上线前补充或更新对应文档；迁移/存储/API 变更必须同步更新。
- 每次发版前进行文档巡检（checklist 可放在 release-and-config.md）。

### 4. 贡献约定
- 新增模块需在 `project-structure.md` 说明目录与依赖。
- 新增接口需更新 `api.md`，并在对应 Feature 文档标记版本。
- 新的领域模型或字段变更需更新 `data-models.md` 与 `storage-and-migration.md`。

### 5. 后续可选
- `brand-assets.md`：品牌资产与规范。
- `analytics.md`：埋点方案、事件命名、数据字典。
- `content-and-voice.md`：文案/语气/AI 内容准则（如 2.0 行为分析与内容库）。
