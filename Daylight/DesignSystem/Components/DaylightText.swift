import SwiftUI

/// 项目已使用的文本样式映射，直接复用现有 Typography/Colors/Opacity。
enum DaylightTextStyle {
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
        switch style {
        case .hero: return DaylightTypography.hero
        case .display: return DaylightTypography.display
        case .title2: return DaylightTypography.title2
        case .title3: return DaylightTypography.title3
        case .headline: return DaylightTypography.headline
        case .subhead: return DaylightTypography.subhead
        case .subheadSemibold: return DaylightTypography.subheadSemibold
        case .bodyLarge: return DaylightTypography.bodyLarge
        case .body2: return DaylightTypography.body2
        case .body2Medium: return DaylightTypography.body2Medium
        case .footnote: return DaylightTypography.footnote
        case .footnoteMedium: return DaylightTypography.footnoteMedium
        case .footnoteSemibold: return DaylightTypography.footnoteSemibold
        case .caption1: return DaylightTypography.caption1
        case .caption1Medium: return DaylightTypography.caption1Medium
        case .caption2: return DaylightTypography.caption2
        case .caption: return DaylightTypography.caption
        case .callout: return DaylightTypography.callout
        case .streakNumber: return DaylightTypography.streakNumber
        case .devTitle: return DaylightTypography.devTitle
        case .body: return DaylightTypography.body
        }
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
