## Daylight 架构设计（Swift 版）

### 1. 目标与范围
- 面向 iOS 客户端，Swift + SwiftUI + MVVM/Coordinator，支持 MVP（匿名、本地存储、提醒）并为登录/同步/订阅/主题等未来功能预留。
- 架构防回头：分层清晰、接口先行、模型可迁移、API 版本化。

### 2. 技术栈假设
- UI：SwiftUI，导航用 Coordinator/Router，将路由从 View 解耦。
- 并发：`async/await`，必要时使用 `actor` 保护共享状态。
- 网络：`URLSession` + `Codable` DTO；所有接口走 `/v1/...`。
- 存储：MVP 可用 JSON + FileManager（带 schemaVersion）；后续可替换 CoreData/Realm/SQLite。
- DI：轻量工厂/Service Locator（可升级 Swinject/Resolver）。

### 3. 分层架构
- Presentation：SwiftUI View + ViewModel（ObservableObject），不直接碰数据源；状态与事件通过 Intent 输入，用 `@Published` 输出 UI 状态；导航用 Coordinator/Router。
- Domain：UseCase（业务编排）、Entity（领域模型）、Repository 协议（User/DayRecord/Settings/Subscription/Auth），无平台依赖；FeatureGate 也放在 Domain。
- Data：RepositoryImpl 组合 LocalDataSource + RemoteDataSource，负责缓存/合并策略与错误映射；Local 负责持久化与迁移，Remote 负责网络调用与 DTO 转换。

#### 3.1 数据流示例（Today / 灯链）
- View → Intent：用户点击“点亮”。
- ViewModel → UseCase：调用 `SetDayCommitment` 或 `ConfirmSleep`。
- UseCase → Repository：`DayRecordRepository.save(record)`，可同时触发本地写入和远端同步。
- Repository → Local：写 JSON/数据库；→ Remote：POST `/v1/day-records`（可异步并行，失败时标记待同步）。
- Repository 返回 Domain Model → ViewModel 更新状态 → View 渲染。错误统一映射为 DomainError，并在 ViewModel 转为 UI 消息。

### 4. 设计系统（DesignSystem 模块）
- Colors/Typo/Spacing/Radius/Motion 统一定义，Theme 协议预留多主题/会员权益；View 仅消费 Theme，不直接写 hex/字号。
- 组件层级：原子（按钮/文本/卡片）→ 复合组件（Banner/Sheet）→ 页面；动画参数集中定义（入场/渐显/弹性）。
- 资源命名：颜色 `clr.daylightGold`，字号 `font.titleLarge`，间距 `space.16`；禁止在页面写 magic number。

### 5. 领域模型与 UseCase（示例）
- Entity（带 `version`/`schemaVersion`）：`User`（匿名 ID 也作为主键）、`Subscription`、`Entitlement`、`DayRecord`、`Settings`。
- 字段要点：
  - User：`id`、`deviceId`、`createdAt`、`lastActiveAt`、`locale`、`timezone`；预留 `email/phone/appleId`。
  - DayRecord：`date`、`commitmentText`、`dayLightStatus`、`nightLightStatus`、`sleepConfirmedAt`、`nightRejectCount`、`version`。
  - Settings：`dayReminderTime`、`nightReminderStart`、`nightReminderEnd`、`nightReminderInterval`、`nightReminderEnabled`、`version`。
- UseCase 示例（输入/输出/副作用）：
  - `SetDayCommitment(date, text)`：写 DayRecord；若启用提醒，更新通知计划。
  - `ConfirmSleep(date, timestamp)`：更新 nightLightStatus/sleepConfirmedAt；触发 streak 重算。
  - `GetStreak()`：基于 DayRecord 序列计算；可缓存结果。
  - `UpdateSettings(settings)`：写入本地 + 远端；下发通知调度。
  - `GetUserEntitlements()`：读取 Subscription/Entitlement；返回 `isPro` 与 feature map。
- FeatureGate：`checkFeature(featureKey: EntitlementKey)` 由 Domain 提供，UI 只问 Domain，不直接判断 plan。

### 6. 数据层设计
- LocalDataSource：
  - MVP：JSON 文件（`day_records.json`、`settings.json`）、Keychain（匿名 token/userId）。
  - 提供 `schemaVersion` 读写、迁移钩子 `migrate(from:to:)`；写入使用后台队列或 actor 保护。
  - 存储格式：`{ "schemaVersion": 1, "items": [...] }`，便于未来字段扩展。
- RemoteDataSource：
  - `URLSession` + `async/await`，集中配置 baseURL、版本前缀、超时、重试策略（如 3 次指数退避）。
  - DTO 与 Domain Model 分离；错误转换为 DomainError（如网络超时、认证失效、服务器错误）。
  - 主要接口：`POST /v1/auth/anonymous`、`GET/POST /v1/day-records`、`GET/POST /v1/settings`、(预留) `/v1/subscriptions` `/v1/entitlements`。
- RepositoryImpl：
  - 读：先本地缓存 → 可后台刷新远端，成功后合并落盘并回调 UI；无网时返回本地。
  - 写：本地立即落盘；远端失败则记录待同步队列（如 `pending_ops.json`），下次有网重试。
  - 冲突策略：以 `updatedAt` 或版本号为准；必要时保留本地/远端差异日志。

### 7. 并发与线程
- View 层禁止直接开全局 Task 处理业务，统一经 ViewModel 内部方法调用 UseCase。
- 本地写入与迁移放后台队列/actor；UI 状态发布回主线程。
- 数据同步可用后台 Task；需支持 App 进入前台时触发一次拉取，避免 UI 冻结。

### 8. DI 与装配
- `AppDelegate/SceneDelegate`（或 `DaylightApp`）阶段创建 CompositionRoot：装配 DataSource → RepositoryImpl → UseCase → ViewModel。
- 工厂例：`makeTodayViewModel()` 内注入 `DayRecordRepository`、`GetStreak`、`SetDayCommitment` 等，实现集中装配。
- 需要可测试性：Repository 协议注入 stub，ViewModel 可用内存假实现单测；UseCase 层不依赖 UIKit/SwiftUI，便于测试。

### 9. 错误、日志、配置
- 错误分层：NetworkError/DataError/DomainError；在 RepositoryImpl 统一映射，ViewModel 再转为 UI 文案。
- 重试与降级：网络失败走离线数据；认证失败触发匿名刷新；数据损坏触发迁移/回滚。
- 日志：OSLog；关键路径（迁移、支付、登录）需要可观测性埋点，可上传匿名故障事件。
- 配置：环境配置（dev/stage/prod）集中在 Config；API 版本前缀常量集中；敏感配置不写死在代码（使用 xcconfig）。

### 10. 测试策略
- 单测：UseCase + Repository 协议（stub）；ViewModel 用假数据源验证状态机（含错误分支）。
- 集成：本地存储迁移、序列化/反序列化、网络 DTO 映射；待同步队列的重试逻辑。
- UI：SwiftUI Snapshot/UITest 针对关键流程（今日之灯、夜间守护）；导航/深链测试。
- 性能：冷启动（30fps+）、列表滚动、文件读写；观察主线程阻塞。

### 11. 项目目录建议（对应 Xcode 组）
```
Daylight/
  App/                 # 入口、DI、Coordinator
  Features/
    Today/
      TodayView.swift
      TodayViewModel.swift
    Streak/
    Settings/
  DesignSystem/        # Colors/Typo/Spacing/Theme/Components
  Domain/
    Models/
    UseCases/
    Repositories/      # 协议定义
  Data/
    Local/             # JSON/CoreData/Realm 实现
    Remote/            # API 客户端、DTO、Endpoints
    Repositories/      # RepositoryImpl
  Core/                # Utils/Error/Logging/Config/Extensions
  Resources/           # Assets/Strings
  Tests/
    Unit/
    Integration/
  UITests/
```

### 12. 演进路线映射
- MVP：匿名、DayRecord/Settings 本地存储 + 简单推送；Remote 可选“云备份”接口。
- 1.0：接入 AuthRepository（手机号/邮箱/Apple ID）、SubscriptionRepository、云同步；Theme 多样化通过 Entitlement 控制。
- 2.0：行为分析、内容库、分享；可将更多 FeatureGate 放入 Domain，不破坏 UI 和现有 UseCase。

### 13. 迁移与同步策略（补充）
- 迁移：启动时读取本地 `schemaVersion`，有差异则按序执行迁移脚本（纯 Swift 函数）；迁移失败记录日志并尝试回滚备份文件。
- 同步：写操作落盘后入列待同步；前台/网络恢复时触发批量上传；上传成功后删除队列项。
- 时间戳/冲突：以 `updatedAt` + `version` 解决，必要时保守选择“最新写入覆盖”并记录冲突事件。
