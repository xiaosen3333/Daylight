# Daylight

[![iOS CI](https://github.com/xiaosen3333/Daylight/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/xiaosen3333/Daylight/actions/workflows/ios-ci.yml)

Daylight 是我独立设计和实现的 iOS 行为养成产品，目标是帮助用户降低熬夜频率。
这个仓库用于展示我的移动端工程能力：产品抽象、架构设计、可测试性、质量门禁、交付规范。

## What this project does

- 提供 `今日之灯 / 夜间守护 / 灯链` 三条核心体验。
- 以本地优先模式运行：离线可用，支持待同步队列回放。
- 使用可扩展分层架构，兼容后续接入真实后端与会员能力。

## What I owned

我在这个项目中负责了端到端工作：

- 产品定义：功能流程、MVP 范围、迭代节奏。
- 客户端实现：`SwiftUI + MVVM + UseCase + Repository`。
- 工程建设：本地存储迁移、通知调度、测试、Lint、CI。
- 文档体系：架构文档、规格文档、设计系统、工程手册。

## Quick start

### Requirements

- Xcode 16+
- iOS Simulator
- SwiftLint (`brew install swiftlint`)

### Run app

```bash
git clone https://github.com/xiaosen3333/Daylight.git
cd Daylight
open Daylight.xcodeproj
```

在 Xcode 直接运行 `Daylight` scheme。

### Run quality checks

```bash
make lint
make test
```

## Architecture

```mermaid
flowchart LR
    A["SwiftUI Views"] --> B["ViewModels (Presentation)"]
    B --> C["UseCases (Domain)"]
    C --> D["Repository Protocols"]
    D --> E["Local Data Sources\n(JSON + Keychain)"]
    D --> F["Remote Stub / Future API"]
    C --> G["Notification Scheduler"]
```

详细说明见：[docs/Daylight-architecture-swift.md](docs/Daylight-architecture-swift.md)

## Screenshots

| Main | Commitment | Night Guard | Light Chain |
|---|---|---|---|
| ![main](docs/ui/mainscreen.png) | ![daycommit](docs/ui/daycommit.png) | ![nightguard](docs/ui/nightguard.png) | ![lightchain](docs/ui/lightchains.png) |

## Engineering habits shown in this repo

- 明确分层目录与职责边界（`Presentation / Domain / Data / Core`）。
- 可重复执行的命令入口（`Makefile`）。
- 静态检查 + 单测 + GitHub Actions 质量门禁。
- 统一提交风格（Conventional Commits，见 `CONTRIBUTING.md`）。

## Repository structure

```text
Daylight/
├── Daylight/                 # App source
│   ├── App/
│   ├── Presentation/
│   ├── Domain/
│   ├── Data/
│   ├── Core/
│   └── DesignSystem/
├── DaylightTests/            # Unit tests
├── docs/                     # Product/architecture/design docs
├── .github/workflows/        # CI pipelines
├── Makefile
└── CONTRIBUTING.md
```

## CI

GitHub Actions workflow: `.github/workflows/ios-ci.yml`

- SwiftLint 严格模式
- iOS Simulator build + test (`xcodebuild test`)

## More docs

- [Engineering handbook](docs/engineering-handbook.md)
- [Feature spec](docs/feature-spec-daylight-core.md)
- [Design system](docs/design-system.md)
