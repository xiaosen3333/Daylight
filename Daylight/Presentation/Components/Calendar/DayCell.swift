import SwiftUI

enum DayVisualStatus {
    case complete
    case partial
    case off

    func style(using palette: DayVisualStylePalette) -> DayVisualStyle {
        switch self {
        case .complete:
            return palette.complete
        case .partial:
            return palette.partial
        case .off:
            return palette.off
        }
    }
}

struct DayVisualStyle {
    let background: Color
    let text: Color
    let glow: Color
    let glowRadius: CGFloat
}

struct DayVisualStylePalette {
    let complete: DayVisualStyle
    let partial: DayVisualStyle
    let off: DayVisualStyle

    static let mainCalendar = DayVisualStylePalette(
        complete: DayVisualStyle(
            background: DaylightColors.glowGold,
            text: DaylightColors.textOnGlow,
            glow: DaylightColors.glowGold(opacity: 0.6),
            glowRadius: 12
        ),
        partial: DayVisualStyle(
            background: DaylightColors.glowGold(opacity: 0.4),
            text: Color.white.opacity(0.95),
            glow: DaylightColors.glowGold(opacity: 0.3),
            glowRadius: 6
        ),
        off: DayVisualStyle(
            background: DaylightColors.bgOverlay12,
            text: DaylightColors.glowGold(opacity: 0.65),
            glow: Color.clear,
            glowRadius: 0
        )
    )

    static let streakCalendar = DayVisualStylePalette(
        complete: DayVisualStyle(
            background: DaylightColors.glowGold,
            text: DaylightColors.textOnGlow,
            glow: DaylightColors.glowGold(opacity: 0.45),
            glowRadius: 10
        ),
        partial: DayVisualStyle(
            background: DaylightColors.glowGold(opacity: 0.35),
            text: Color.white.opacity(0.92),
            glow: DaylightColors.glowGold(opacity: 0.2),
            glowRadius: 6
        ),
        off: DayVisualStyle(
            background: DaylightColors.bgOverlay15,
            text: DaylightColors.glowGold(opacity: 0.65),
            glow: Color.clear,
            glowRadius: 0
        )
    )
}

func dayStatus(for record: DayRecord?) -> DayVisualStatus {
    guard let record else { return .off }
    if record.dayLightStatus == .on && record.nightLightStatus == .on {
        return .complete
    }
    if record.dayLightStatus == .on && record.nightLightStatus == .off {
        return .partial
    }
    return .off
}

struct DayCell: Identifiable, Hashable {
    let id: String
    let date: Date
    let record: DayRecord?
    let dayString: String

    init(date: Date, record: DayRecord?, calendar: Calendar, formatter: DateFormatter) {
        self.date = date
        self.record = record
        self.id = formatter.string(from: date)
        let comp = calendar.dateComponents([.day], from: date)
        self.dayString = "\(comp.day ?? 0)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DayCell, rhs: DayCell) -> Bool {
        lhs.id == rhs.id
    }
}
