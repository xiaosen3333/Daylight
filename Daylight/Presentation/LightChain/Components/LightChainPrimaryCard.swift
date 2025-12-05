import SwiftUI

/// 参考 docs/ui/card1.png 的主卡片，展示连续天数与灯链状态。
struct LightChainPrimaryCard: View {
    let records: [DayRecord]
    let streak: StreakResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(NSLocalizedString("lightchain.card.title", comment: "Light chain header"))
                .daylight(.display, color: DaylightColors.glowGold)

            Text(NSLocalizedString("lightchain.card.subtitle", comment: "Light chain subtitle"))
                .daylight(.headline, color: DaylightColors.glowGold)
                .lineSpacing(6)

            HStack(spacing: 30) {
                streakBlock(
                    value: streak?.current ?? 0,
                    label: NSLocalizedString("lightchain.card.current", comment: "Current streak")
                )
                streakBlock(
                    value: streak?.longest ?? 0,
                    label: NSLocalizedString("lightchain.card.longest", comment: "Longest streak")
                )
            }
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaylightRadius.xl, style: .continuous)
                .fill(DaylightGradients.cardPrimary)
        )
    }

    private func streakBlock(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(value)")
                    .daylight(.streakNumber, color: DaylightColors.glowGold)
                Text(NSLocalizedString("lightchain.card.days", comment: "Days suffix"))
                    .daylight(.subhead, color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
            }
            Text(label)
                .daylight(.bodyLarge, color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
        }
    }
}
