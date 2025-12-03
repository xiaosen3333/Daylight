# Daylight Design System v1.2.1

> **核心原则**：所有视觉样式通过 Design Tokens 统一管理，页面代码仅引用 Token，禁止硬编码样式值。

---

## 目录

1. [Colors 颜色](#1-colors-颜色)
2. [Typography 字体](#2-typography-字体)
3. [Radius 圆角](#3-radius-圆角)
4. [Text Opacity 文字透明度](#4-text-opacity-文字透明度)
5. [Gradients 渐变](#5-gradients-渐变)
6. [Components 组件](#6-components-组件)
7. [使用指南](#7-使用指南)

---

## 1. Colors 颜色

### 1.1 背景色

| Token | 值 | 用途 |
|-------|-----|------|
| `bgPrimary` | `#5D8C8D` | Today/Settings/LightChain 主背景 |
| `bgNight` | `#0C2740` | NightGuard 夜间背景 |

### 1.2 透明覆盖层 (白色 + 透明度)

| Token | 透明度 | 用途 |
|-------|--------|------|
| `bgOverlay08` | 8% | Settings 卡片/输入框背景 |
| `bgOverlay10` | 10% | 取消按钮背景 |
| `bgOverlay12` | 12% | 次级按钮、状态点背景 |
| `bgOverlay15` | 15% | 日历未完成格、Dev按钮 |
| `bgOverlay18` | 18% | 睡眠 CTA 按钮背景 (已废弃) |
| `bgOverlay25` | 25% | 装饰点 |
| `bgOverlay28` | 28% | 日历导航栏背景 |

### 1.3 交互色

| Token | 值 | 用途 |
|-------|-----|------|
| `actionPrimary` | `#467577` | 主按钮背景、输入框胶囊 |

### 1.4 高亮色

| Token | 值 | 用途 |
|-------|-----|------|
| `glowGold` | `#FFECAD` | 太阳/月亮核心、日历完成点、Toggle |
| `glowGold(opacity:)` | 动态 | 带透明度的灯光色 |

### 1.5 文字色 (深色背景上的浅色文字)

| Token | 值 | 用途 |
|-------|-----|------|
| `textOnGlow` | `#334F50` | 日历完成格的深色文字 |
| `textOnGlowAlt` | `#324B4B` | 日历选中日期的深色文字 |

### 1.6 状态色

| Token | 值 | 用途 |
|-------|-----|------|
| `statusSuccess` | `#87DC98` | 同步成功 |
| `statusError` | `#FFBAAD` | 同步失败 |
| `statusInfo` | `#BBD3FF` | 同步中 |

### 1.7 日历辅助色 (LightChain 浅色日历)

| Token | 值 | 用途 |
|-------|-----|------|
| `calendarArrow` | `#4A5C46` | 日历箭头 |
| `calendarMonth` | `#44553F` | 月份文字 |
| `calendarText` | `#ECF6E1` | 浅色背景上的文字 |

---

## 2. Typography 字体

### 2.1 标题层级

| Token | 大小 | 字重 | 用途 |
|-------|------|------|------|
| `hero` | 38pt | bold | Today 主标题 |
| `display` | 36pt | bold | LightChainPrimaryCard 大标题 |
| `title1` | 34pt | bold | NightGuard 主标题 |
| `title2` | 30pt | bold | DayCommitment 主标题 |
| `title3` | 26pt | bold | LightChain sunCard 标题 |

### 2.2 正文层级

| Token | 大小 | 字重 | 用途 |
|-------|------|------|------|
| `headline` | 22pt | semibold | 主按钮文字、卡片标题 |
| `subhead` | 20pt | regular | NightGuard 副标题 |
| `subheadSemibold` | 20pt | semibold | NightGuard 按钮 |
| `bodyLarge` | 19pt | regular | Today 副标题 |
| `callout` | 18pt | semibold | Settings 区块标题 |
| `body2` | 16pt | regular | 通用正文 |
| `body2Medium` | 16pt | medium | 正文加粗 |

### 2.3 辅助层级

| Token | 大小 | 字重 | 用途 |
|-------|------|------|------|
| `footnote` | 15pt | regular | 卡片描述、状态文字 |
| `footnoteMedium` | 15pt | medium | 卡片描述加粗 |
| `footnoteSemibold` | 15pt | semibold | 同步状态文字 |
| `caption1` | 14pt | semibold | 日历数字 |
| `caption1Medium` | 14pt | medium | 日历数字 medium |
| `caption2` | 13pt | semibold | 周几标题 |
| `caption2Regular` | 13pt | regular | 小字说明 |

### 2.4 特殊用途

| Token | 大小 | 字重 | 用途 |
|-------|------|------|------|
| `streakNumber` | 48pt | bold | 连续天数大数字 |
| `devTitle` | 24pt | bold | 开发者工具标题 |

---

## 3. Radius 圆角

| Token | 值 | 用途 |
|-------|-----|------|
| `xl` | 34pt | LightChainPrimaryCard |
| `lg` | 30pt | 日历卡片 |
| `button` | 28pt | 主按钮 |
| `cardLarge` | 26pt | LightChain 各类卡片 |
| `capsule` | 24pt | 输入框胶囊 |
| `md` | 22pt | DayRecordStatusCard |
| `devButton` | 18pt | 开发者按钮 |
| `sm` | 16pt | Settings 卡片 |
| `nav` | 14pt | 日历导航按钮 |
| `xs` | 12pt | Settings 输入框、小按钮 |
| `xxs` | 10pt | 同步重试按钮 |
| `pill` | 999pt | 圆形/胶囊 |

---

## 4. Text Opacity 文字透明度

用于 `.white.opacity(DaylightTextOpacity.xxx)` 构建文字颜色。

| Token | 值 | 用途 |
|-------|-----|------|
| `primary` | 0.9 | 主标题、按钮文字 |
| `secondary` | 0.8 | 副标题、描述 |
| `tertiary` | 0.7 | 辅助说明 |
| `muted` | 0.6 | 占位文字 |
| `disabled` | 0.5 | 禁用状态 |

---

## 5. Gradients 渐变

| Token | 方向 | 用途 |
|-------|------|------|
| `cardPrimary` | top → bottom | LightChainPrimaryCard |
| `cardCalendarDark` | top → bottom | 深色日历卡片 |
| `cardCalendarLight` | top → bottom | 浅色日历卡片 |
| `cardStreak` | top → bottom | Streak 卡片 |
| `cardDetail` | topLeading → bottomTrailing | Detail 卡片 |
| `cardSun` | top → bottom | Sun 卡片 |

---

## 6. Components 组件

### 6.1 DaylightCTAButton

统一 CTA 按钮入口，按 kind 切换日/夜/幽灵样式。

```swift
DaylightCTAButton(
    title: "开始今天",
    kind: .dayPrimary,    // .nightPrimary / .ghost
    isEnabled: true,      // 可选，默认 true
    isLoading: false,     // 可选，默认 false
    icon: "checkmark"     // 可选，夜间态可加 SF Symbol
) {
    // action
}
```

**样式与场景**：
- `.dayPrimary`：背景 `actionPrimary`、文字 `headline + white 90%`，用于 Today/DayCommitment 等浅色背景 CTA。
- `.nightPrimary`：背景 `bgOverlay12`、文字/图标 `subheadSemibold + glowGold 90%`，用于 NightGuard 或其他夜色/深色背景 CTA，支持 loading。
- `.ghost`：背景 `bgOverlay08`、文字 `white 90%`，用于开发者/轻量入口。
- 圆角：日/夜 `button (28pt)`，ghost `xs (12pt)`；内边距：日/夜 16pt，ghost 10pt；loading 显示内置 `ProgressView` 并阻断点击。
- 兼容：`DaylightPrimaryButton` / `DaylightSecondaryButton` / `DaylightGhostButton` 作为别名内部转调，推荐新代码直接使用 `DaylightCTAButton(kind:)`。

---

### 6.2 DaylightPrimaryButton（兼容别名）

```swift
DaylightPrimaryButton(
    title: "开始今天",
    isEnabled: true,      // 可选，默认 true
    isLoading: false      // 可选，默认 false
) {
    // action
}
```

> 内部调用 `DaylightCTAButton(kind: .dayPrimary)`，用于浅色背景主操作。

---

### 6.3 DaylightSecondaryButton（兼容别名）

```swift
DaylightSecondaryButton(
    title: "确认入睡",
    icon: "checkmark",    // 可选
    isEnabled: true,      // 可选
    isLoading: false      // 可选
) {
    // action
}
```

> 内部调用 `DaylightCTAButton(kind: .nightPrimary)`，用于夜空/深色背景 CTA。

---

### 6.4 DaylightGhostButton（兼容别名）

```swift
DaylightGhostButton(
    title: "触发日间通知",
    isEnabled: true,      // 可选
    isLoading: false      // 可选
) {
    // action
}
```

> 内部调用 `DaylightCTAButton(kind: .ghost)`，用于开发者或轻量操作。

---

### 6.5 GlowingSun / GlowingMoon

发光天体组件，用于 Today 和 NightGuard 页面。

```swift
GlowingSun(size: 140)
GlowingMoon(size: 120)
```

---

### 6.6 LightDot

光点组件，用于 Today 页面的 7 日连续记录展示。

```swift
LightDot(status: .full)    // .full / .half / .off
```

---

## 7. 使用指南

### 7.1 颜色使用

```swift
// 背景
.background(DaylightColors.bgPrimary)

// 透明覆盖
.background(DaylightColors.bgOverlay12)

// 带透明度的高亮色
.fill(DaylightColors.glowGold(opacity: 0.5))

// 文字颜色
.foregroundColor(.white.opacity(DaylightTextOpacity.primary))
```

### 7.2 字体使用

```swift
.font(DaylightTypography.headline)
.font(DaylightTypography.body2Medium)
```

### 7.3 圆角使用

```swift
.cornerRadius(DaylightRadius.button)
.cornerRadius(DaylightRadius.card)
```

### 7.4 渐变使用

```swift
.background(
    RoundedRectangle(cornerRadius: DaylightRadius.cardLarge)
        .fill(DaylightGradients.cardPrimary)
)
```

### 7.5 按钮使用

```swift
// 统一入口
DaylightCTAButton(title: "确认", kind: .dayPrimary) {
    // action
}
DaylightCTAButton(title: "入睡", kind: .nightPrimary, isLoading: true) {
    // action
}
DaylightCTAButton(title: "触发通知", kind: .ghost) {
    // action
}

// 兼容别名
DaylightPrimaryButton(title: "确认") { /* uses .dayPrimary */ }
DaylightSecondaryButton(title: "入睡") { /* uses .nightPrimary */ }
DaylightGhostButton(title: "触发通知") { /* uses .ghost */ }
```

### 7.6 文本统一入口（Text.daylight）

```swift
// 默认：白色 90%，防压缩 + 0.9 缩放
Text("主标题")
    .daylight(.hero, alignment: .center, lineLimit: 2)

// GlowGold 高亮
Text("高亮标题")
    .daylight(.headline, color: DaylightColors.glowGold)

// 次级/多行文案
Text("说明文案")
    .daylight(.body2, color: .white.opacity(DaylightTextOpacity.secondary), alignment: .leading)
```

> Snapshot 覆盖建议（占位代码，可放入测试目标）：
> ```swift
> import XCTest
> import SwiftUI
> 
> final class DaylightTextSnapshotTests: XCTestCase {
>     func testDaylightTextDefault() throws {
>         let view = Text("Daylight Hero").daylight(.hero)
>         let renderer = ImageRenderer(content: view.frame(width: 200, height: 80))
>         let image = renderer.uiImage
>         XCTAssertNotNil(image) // 基线快照比对可用 SnapshotTesting
>     }
> }
> ```

---

## 文件结构

```
Daylight/DesignSystem/
├── DesignTokens.swift          # 所有 Token 定义
└── Components/
    ├── DaylightCTAButton.swift # Day/Night/Ghost CTA 统一入口
    ├── PrimaryButton.swift     # DaylightPrimaryButton
    ├── SecondaryButton.swift   # DaylightSecondaryButton
    ├── GhostButton.swift       # DaylightGhostButton
    ├── GlowingSun.swift        # GlowingSun + GlowingMoon
    ├── LightDot.swift          # LightDot
    └── LampView.swift          # LampView (兼容组件)
```

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.2.1 | 2024-12 | 新增 DaylightCTAButton，旧主/次/幽灵按钮作为别名收敛样式 |
| 1.2.0 | 2024-11 | 完成全量迁移，移除废弃 Token，组件化主要按钮 |
| 1.0.0 | 2024-10 | 初始 Token 定义 |
