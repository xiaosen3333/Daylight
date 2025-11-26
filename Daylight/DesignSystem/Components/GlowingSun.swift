import SwiftUI

/// 太阳光晕组件 - 用于 Today/DayCommitment 页面
/// 三层光晕: 外层 50% blur60, 中层 60% blur30, 核心 100%
struct GlowingSun: View {
    var size: CGFloat = 140

    private var outerSize: CGFloat { size * 1.7 }
    private var middleSize: CGFloat { size * 1.3 }

    var body: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(DaylightColors.glowGold(opacity: 0.5))
                .frame(width: outerSize, height: outerSize)
                .blur(radius: 60)

            // 中层光晕
            Circle()
                .fill(DaylightColors.glowGold(opacity: 0.6))
                .frame(width: middleSize, height: middleSize)
                .blur(radius: 30)

            // 核心
            Circle()
                .fill(DaylightColors.glowGold)
                .frame(width: size, height: size)
        }
    }
}

/// 月亮光晕组件 - 用于 NightGuard 页面
/// 三层光晕: 外层 45% blur60, 中层 60% blur30, 核心 100%
struct GlowingMoon: View {
    var size: CGFloat = 120

    private var outerSize: CGFloat { size * 1.83 }
    private var middleSize: CGFloat { size * 1.33 }

    var body: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(DaylightColors.glowGold(opacity: 0.45))
                .frame(width: outerSize, height: outerSize)
                .blur(radius: 60)

            // 中层光晕
            Circle()
                .fill(DaylightColors.glowGold(opacity: 0.6))
                .frame(width: middleSize, height: middleSize)
                .blur(radius: 30)

            // 核心
            Circle()
                .fill(DaylightColors.glowGold)
                .frame(width: size, height: size)
        }
    }
}
