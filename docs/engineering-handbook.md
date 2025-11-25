# Daylight 工程师入口文档（MVP 本地版）

目标：让客户端工程师快速理解产品、需求、设计、架构与交付边界，直接开工。

## 1. 产品与范围
- 阶段：MVP，本地优先，不接后端。所有读写走本地存储（JSON + Keychain）；网络接口保留为未来同步预留，默认 stub/mock。
- 功能：今日之灯（白昼承诺）、夜间守护、灯链展示、提醒（本地通知）。

## 2. 必读文档地图
- 产品/架构总览：`docs/Daylight.md`
- 客户端架构（Swift）：`docs/Daylight-architecture-swift.md`（分层、数据流、同步/迁移策略、项目结构）
- 核心功能规格（MVP）：`docs/feature-spec-daylight-core.md`（时间/切日规则、流程/验收、通知、离线/冲突、QA用例、埋点）
- 设计稿与设计系统：`docs/ui/`（视觉稿 image1-4.png，设计 token 代码示例 `designtoken.md`，SwiftUI/Compose token 与组件接口）
- 文档结构索引：`docs/documentation-structure.md`（按需扩展/维护）

## 3. 开发思路（SwiftUI + MVVM）
- 分层：Presentation(View+ViewModel+Coordinator) / Domain(UseCase+Model+Repository协议) / Data(Local stub + Remote stub)。
- 时间规则：所有上传时间用 UTC ISO8601 毫秒；`date` 按本地时区日；夜间窗口跨日 22:30–00:30 归前一日；DST 按系统时间。
- 存储：MVP 用 JSON 文件 + Keychain（匿名 id/token）；待同步队列/重试逻辑可保留但默认不触网。
- 通知：本地通知；拒绝权限时前台弹窗兜底，重置点 03:00，夜间最多 4 次提醒。
- 设计系统：禁止写裸色值/字号/间距，使用 `docs/ui/designtoken.md` 中的 token（推荐拆成 Colors.swift / Typography.swift / Layout.swift 模块）。

## 4. 快速上手步骤
1) 阅读 `feature-spec-daylight-core.md` 的时间/流程/验收与 QA 用例。
2) 按 `Daylight-architecture-swift.md` 创建目录骨架与 DI 装配（DataSource→RepositoryImpl→UseCase→ViewModel）。
3) 将 `docs/ui/designtoken.md` 拆成 token 代码文件并引入，按视觉稿 image1-4.png 搭建 UI。
4) 实现本地存储（JSON + Keychain）、提醒调度、灯链展示；网络层保留接口但 stub。
5) 对照 QA 用例和埋点表自测；确认夜间跨日/时区/DST 行为。

## 5. 交付与验收
- 验收基准：`feature-spec-daylight-core.md` 中的 AC 与 QA 用例；埋点事件按表覆盖。
- 注意事项：尝试构建并处理编译错误xcodebuild -scheme Daylight -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build，新文件要编入xcode索引
- 性能：页面切换 <100ms，灯亮动效 60fps，灯链支持 30–60 天视图。
- 无障碍：文本对比度 ≥4.5:1；点击区域 ≥44x44pt；VoiceOver 可读灯状态。

## 6. 后续扩展占位
- 若接入后端：启用 RemoteDataSource，实现 `/v1/...` 批量上传/查询；开启重试/冲突处理。
- 会员/主题：FeatureGate 与 token 覆盖已有预留接口，UI 不直接判断 plan。***
