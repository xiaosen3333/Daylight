# Daylight 设计系统规范（组件与 Tokens）
- 目标：为后续开发提供统一的按钮样式、字体与色彩规则，指导组件化落地，减少页面内魔法数。
- 适用范围：iOS/SwiftUI 客户端，基于 `Daylight/DesignSystem/DesignTokens.swift` 与现有组件（如 `DaylightPrimaryButton`）。

## 现有 Tokens（来自 DesignTokens.swift）
- 颜色：`lampGold/lampGoldDeep`、`nightIndigo/nightSky`、`dayTeal/dayTealLight`、`surfaceDark/surfaceLight`、`textPrimary/textSecondary/textMuted`、`borderSoft/dividerSoft`、`success/warning/error`。
- 字体：`titleLarge`(28/semibold/rounded)、`titleMedium`(22/semibold/rounded)、`body`(16/regular/rounded)、`bodySecondary`(14/regular/rounded)、`caption`(12/regular/rounded)。
- 间距：4, 8, 12, 16, 24, 32, 40；圆角：`pill/card/chip/lamp`；阴影/动效：`DaylightShadow.lamp`、`DaylightDurations/Easing`。

## 规范化命名（与实际界面一致）
- 品牌/背景
  - `brand.teal.base`：#5D8C8D（Today 主背景现用色）。
  - `brand.teal.action`：#467577（主操作按钮现用色）。
  - `bg.night.primary`：#0C2740（夜间页背景）。
  - `bg.overlay.light`：白色 12–18% 透明度（次按钮/蒙层）。
- 高光
  - `accent.gold.glow`：#FFECB0（灯光/进度点）。
  - `accent.gold.deep`：#FFB950（强调，已对应 `lampGoldDeep`）。
- 文本
  - `text.primary.light`：#FFFFFF 90%。
  - `text.secondary.light`：#FFFFFF 80%。
- 反馈/边框：沿用 `success/warning/error` 与 `borderSoft`。

建议在 `DesignTokens.swift` 扩展上述别名/常量，映射到现有值，避免页面再写 RGB。

## 字体层级（按实际页面）
- 主标题：System 38 Bold（Today）、34 Bold（夜间页）。
- 副标题/描述：System 19 Regular（Today）、20 Regular（夜间页描述）。
- 主按钮文字：System 22 Semibold。
- 次要按钮/CTA：System 18–20 Semibold。
- 标签/辅助：System 13–15 Semibold/Regular。
可在 Tokens 中新增对应常量（如 `font.titleXL = .system(size: 38, weight: .bold)` 等）。

## 按钮样式规范（基于真实样式）
- Primary（主操作）
  - 背景：`brand.teal.action` 纯色；文字：`text.primary.light` 90%；圆角 24–28；垂直内边距 14–16。
  - 禁用：整体降低不透明度；加载：用 `ProgressView` 覆盖文字。
- Secondary（弱化确认/夜间 CTA）
  - 背景：`bg.overlay.light`；文字：`text.primary.light`；圆角同 Primary。
- Ghost（透明/弱化链接）
  - 背景透明；文字用 `text.secondary.light`；最小高度 44pt。
- Destructive（预留）
  - 背景：`error`；文字白色；圆角同 Primary。

> 注：当前项目 `DaylightPrimaryButton` 未被使用，可新建 `PrimaryButton/SecondaryButton/GhostButton` 按上述样式封装，并替换页面硬编码按钮。

### 按钮示例
```swift
PrimaryButton(title: "确认提交", isEnabled: formValid, isLoading: isSubmitting) {
    Task { await submit() }
}
```

## 组件化与落地建议
- 扩展 `DesignTokens.swift` 增加上述命名别名，保留旧常量兼容。
- 在 `DesignSystem/Components` 实现 `PrimaryButton/SecondaryButton/GhostButton`，统一禁用/加载状态。
- 页面整改：Today/DayCommitment/Night/Settings 将硬编码 RGB/字号替换为 tokens；按钮替换为组件；卡片可抽象 `DaylightCard`（统一圆角 24–26、内边距 16–18、渐变或纯色）。
- 动效：统一使用 `DaylightEasing.glow`（入场/高亮）与 `DaylightEasing.fade`（点击）。
