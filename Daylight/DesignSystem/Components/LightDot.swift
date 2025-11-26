import SwiftUI

/// 灯珠状态
enum LightDotStatus {
    /// 全亮 - 白天+夜间都完成
    case on
    /// 半亮 - 仅白天完成
    case partial
    /// 未完成
    case off
}

/// 灯珠组件 - 用于灯链展示
struct LightDot: View {
    let status: LightDotStatus
    var size: CGFloat = 16

    private var color: Color {
        switch status {
        case .on:
            return DaylightColors.glowGold
        case .partial:
            return DaylightColors.glowGold(opacity: 0.55)
        case .off:
            return DaylightColors.bgOverlay25
        }
    }

    private var glowColor: Color {
        switch status {
        case .on:
            return DaylightColors.glowGold(opacity: 0.4)
        case .partial:
            return DaylightColors.glowGold(opacity: 0.25)
        case .off:
            return Color.clear
        }
    }

    private var glowRadius: CGFloat {
        switch status {
        case .on: return 6
        case .partial: return 4
        case .off: return 0
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glowColor, radius: glowRadius)
    }
}

// MARK: - Convenience initializer from DayRecord
extension LightDotStatus {
    init(dayLight: LightStatus, nightLight: LightStatus) {
        if dayLight == .on && nightLight == .on {
            self = .on
        } else if dayLight == .on {
            self = .partial
        } else {
            self = .off
        }
    }
}
