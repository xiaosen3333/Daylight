import SwiftUI

// MARK: - Color + Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Colors (基于真实界面 v1.2.0)
enum DaylightColors {
    // MARK: 背景色
    /// 主背景 - Today/DayCommit/Settings/LightChain
    static let bgPrimary = Color(hex: "#5D8C8D")
    /// 夜间背景 - NightGuard
    static let bgNight = Color(hex: "#0C2740")

    // MARK: 透明覆盖层
    static let bgOverlay08 = Color.white.opacity(0.08)
    static let bgOverlay10 = Color.white.opacity(0.10)
    static let bgOverlay12 = Color.white.opacity(0.12)
    static let bgOverlay15 = Color.white.opacity(0.15)
    static let bgOverlay18 = Color.white.opacity(0.18)
    static let bgOverlay25 = Color.white.opacity(0.25)
    static let bgOverlay28 = Color.white.opacity(0.28)

    // MARK: 交互/按钮色
    /// 主按钮背景、输入框胶囊
    static let actionPrimary = Color(hex: "#467577")

    // MARK: 灯光/高亮色
    /// 太阳/月亮核心、日历完成点、Toggle 高亮
    static let glowGold = Color(hex: "#FFECAD")

    /// 带透明度的灯光色
    static func glowGold(opacity: Double) -> Color {
        glowGold.opacity(opacity)
    }

    // MARK: 文字色 (用于深色文字在亮色背景上)
    /// 日历完成格的深色文字
    static let textOnGlow = Color(hex: "#334F50")
    /// 日历选中日期的深色文字
    static let textOnGlowAlt = Color(hex: "#324B4B")

    // MARK: 状态/反馈色
    static let statusSuccess = Color(hex: "#87DC98")
    static let statusError = Color(hex: "#FFBAAD")
    static let statusInfo = Color(hex: "#BBD3FF")
    // 兼容别名
    static let statusSynced = statusSuccess
    static let statusFailed = statusError
    static let statusSyncing = statusInfo

    // MARK: 日历辅助色 (LightChain 浅色日历)
    static let calendarArrow = Color(hex: "#4A5C46")
    static let calendarMonth = Color(hex: "#44553F")
    static let calendarText = Color(hex: "#ECF6E1")

    // MARK: - 兼容层 (供 LampView 组件使用)
    static let lampGold = Color(hex: "#FFDCA8")
    static let lampGoldDeep = Color(hex: "#FFB950")
    static let surfaceLight = Color(hex: "#F5F7FF")
    static let borderSoft = Color(hex: "#41446A")

}

// MARK: - 卡片渐变
enum DaylightGradients {
    /// LightChainPrimaryCard 主卡片
    static let cardPrimary = LinearGradient(
        colors: [Color(hex: "#5D8C8D"), Color(hex: "#507A7B")],
        startPoint: .top, endPoint: .bottom
    )

    /// 深色日历卡片
    static let cardCalendarDark = LinearGradient(
        colors: [Color(hex: "#467070"), Color(hex: "#375D5D")],
        startPoint: .top, endPoint: .bottom
    )

    /// 浅色日历卡片
    static let cardCalendarLight = LinearGradient(
        colors: [Color(hex: "#F8F3CF"), Color(hex: "#F2EABB")],
        startPoint: .top, endPoint: .bottom
    )

    /// Streak 卡片
    static let cardStreak = LinearGradient(
        colors: [Color(hex: "#142B31"), Color(hex: "#1E3C42")],
        startPoint: .top, endPoint: .bottom
    )

    /// Detail 卡片
    static let cardDetail = LinearGradient(
        colors: [Color(hex: "#223D44"), Color(hex: "#162C36")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Sun 卡片
    static let cardSun = LinearGradient(
        colors: [Color(hex: "#4E7D7C"), Color(hex: "#3F6667")],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Typography (基于真实界面 v1.2.0)
enum DaylightTypography {
    // MARK: 标题层级
    /// 38pt - Today 主标题
    static let hero = Font.system(size: 38, weight: .bold)
    /// 36pt - LightChainPrimaryCard 大标题
    static let display = Font.system(size: 36, weight: .bold)
    /// 34pt - NightGuard 主标题
    static let title1 = Font.system(size: 34, weight: .bold)
    /// 30pt - DayCommitment 主标题
    static let title2 = Font.system(size: 30, weight: .bold)
    /// 26pt - LightChain sunCard 标题
    static let title3 = Font.system(size: 26, weight: .bold)

    // MARK: 正文层级
    /// 22pt semibold - 主按钮文字、卡片标题
    static let headline = Font.system(size: 22, weight: .semibold)
    /// 20pt regular - NightGuard 副标题
    static let subhead = Font.system(size: 20, weight: .regular)
    /// 20pt semibold - NightGuard 按钮
    static let subheadSemibold = Font.system(size: 20, weight: .semibold)
    /// 19pt - Today 副标题
    static let bodyLarge = Font.system(size: 19, weight: .regular)
    /// 18pt semibold - Settings 区块标题、睡眠 CTA
    static let callout = Font.system(size: 18, weight: .semibold)
    /// 16pt - 通用正文
    static let body2 = Font.system(size: 16, weight: .regular)
    /// 16pt medium
    static let body2Medium = Font.system(size: 16, weight: .medium)
    /// 15pt - 卡片描述、状态文字
    static let footnote = Font.system(size: 15, weight: .regular)
    /// 15pt medium
    static let footnoteMedium = Font.system(size: 15, weight: .medium)
    /// 15pt semibold - 同步状态文字
    static let footnoteSemibold = Font.system(size: 15, weight: .semibold)
    /// 14pt semibold - 日历数字
    static let caption1 = Font.system(size: 14, weight: .semibold)
    /// 14pt medium
    static let caption1Medium = Font.system(size: 14, weight: .medium)
    /// 13pt semibold - 周几标题、小字说明
    static let caption2 = Font.system(size: 13, weight: .semibold)
    /// 13pt regular
    static let caption2Regular = Font.system(size: 13, weight: .regular)
    /// 48pt bold - 超大数字 (streak)
    static let streakNumber = Font.system(size: 48, weight: .bold)
    /// 24pt bold - 开发者工具标题
    static let devTitle = Font.system(size: 24, weight: .bold)

    // MARK: - 兼容层
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
}

// MARK: - Text Opacity
enum DaylightTextOpacity {
    static let primary: Double = 0.9
    static let secondary: Double = 0.8
    static let tertiary: Double = 0.7
    static let muted: Double = 0.6
    static let disabled: Double = 0.5
}

// MARK: - Spacing
enum DaylightSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

// MARK: - Radius (基于真实界面 v1.2.0)
enum DaylightRadius {
    /// 34pt - LightChainPrimaryCard
    static let xl: CGFloat = 34
    /// 30pt - 日历卡片
    static let lg: CGFloat = 30
    /// 28pt - 主按钮
    static let button: CGFloat = 28
    /// 26pt - LightChain 各类卡片
    static let cardLarge: CGFloat = 26
    /// 24pt - 输入框胶囊
    static let capsule: CGFloat = 24
    /// 22pt - DayRecordStatusCard、睡眠 CTA
    static let md: CGFloat = 22
    /// 18pt - 开发者按钮
    static let devButton: CGFloat = 18
    /// 16pt - Settings 卡片
    static let sm: CGFloat = 16
    /// 14pt - 日历导航按钮
    static let nav: CGFloat = 14
    /// 12pt - Settings 输入框、小按钮
    static let xs: CGFloat = 12
    /// 10pt - 同步重试按钮
    static let xxs: CGFloat = 10
    /// 999pt - 圆形/胶囊
    static let pill: CGFloat = 999

    // MARK: - 兼容层 (保留旧 API)
    static let card: CGFloat = 24
    static let chip: CGFloat = 16
    static let lamp: CGFloat = 999
}

// MARK: - Shadow
enum DaylightShadow {
    static let lamp = ShadowStyle(color: Color.black.opacity(0.45),
                                  radius: 28,
                                  x: 0,
                                  y: 18)

    static let card = ShadowStyle(color: Color.black.opacity(0.25),
                                  radius: 18,
                                  x: 0,
                                  y: 10)

    static let glow = ShadowStyle(color: DaylightColors.glowGold.opacity(0.45),
                                  radius: 10,
                                  x: 0,
                                  y: 0)

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Durations
enum DaylightDurations {
    static let glowOn: Double = 0.60
    static let glowOff: Double = 0.40
    static let tap: Double = 0.18
}

// MARK: - Easing
enum DaylightEasing {
    static let glow = Animation.timingCurve(0.17, 0.89, 0.32, 1.28, duration: DaylightDurations.glowOn)
    static let fade = Animation.easeOut(duration: DaylightDurations.glowOff)
}
