import SwiftUI

/// 项目已使用的文本样式映射，直接复用现有 Typography/Colors/Opacity。
enum DaylightTextStyle: Hashable {
    case hero
    case display
    case title2
    case title3
    case headline
    case subhead
    case subheadSemibold
    case bodyLarge
    case body2
    case body2Medium
    case footnote
    case footnoteMedium
    case footnoteSemibold
    case caption1
    case caption1Medium
    case caption2
    case caption
    case callout
    case streakNumber
    case devTitle
    case body
}

extension Text {
    /// 统一文本样式入口，默认使用白色 + primary 透明度，可覆盖颜色/对齐/行数/缩放。
    func daylight(_ style: DaylightTextStyle,
                  color: Color? = nil,
                  alignment: TextAlignment = .leading,
                  lineLimit: Int? = nil,
                  minimumScaleFactor: CGFloat = 0.9) -> some View {
        self.multilineTextAlignment(alignment)
            .font(font(for: style))
            .foregroundColor(color ?? defaultColor(for: style))
            .lineLimit(lineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    private func font(for style: DaylightTextStyle) -> Font {
        let map: [DaylightTextStyle: Font] = [
            .hero: DaylightTypography.hero,
            .display: DaylightTypography.display,
            .title2: DaylightTypography.title2,
            .title3: DaylightTypography.title3,
            .headline: DaylightTypography.headline,
            .subhead: DaylightTypography.subhead,
            .subheadSemibold: DaylightTypography.subheadSemibold,
            .bodyLarge: DaylightTypography.bodyLarge,
            .body2: DaylightTypography.body2,
            .body2Medium: DaylightTypography.body2Medium,
            .footnote: DaylightTypography.footnote,
            .footnoteMedium: DaylightTypography.footnoteMedium,
            .footnoteSemibold: DaylightTypography.footnoteSemibold,
            .caption1: DaylightTypography.caption1,
            .caption1Medium: DaylightTypography.caption1Medium,
            .caption2: DaylightTypography.caption2,
            .caption: DaylightTypography.caption,
            .callout: DaylightTypography.callout,
            .streakNumber: DaylightTypography.streakNumber,
            .devTitle: DaylightTypography.devTitle,
            .body: DaylightTypography.body
        ]
        return map[style] ?? DaylightTypography.body
    }

    private func defaultColor(for style: DaylightTextStyle) -> Color {
        switch style {
        case .streakNumber:
            return Color.white.opacity(DaylightTextOpacity.primary)
        default:
            return Color.white.opacity(DaylightTextOpacity.primary)
        }
    }
}
