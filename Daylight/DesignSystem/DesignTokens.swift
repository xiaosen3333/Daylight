import SwiftUI

// MARK: - Color + Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanInt64(&int)
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

// MARK: - Tokens
enum DaylightColors {
    static let lampGold = Color(hex: "#FFDCA8")
    static let lampGoldDeep = Color(hex: "#FFB950")

    static let nightIndigo = Color(hex: "#2A2E4A")
    static let nightPurple = Color(hex: "#3D3F63")
    static let nightSky = Color(hex: "#5A67A8")

    static let dayTeal = Color(hex: "#46C0C8")
    static let dayTealLight = Color(hex: "#8CE0E8")

    static let surfaceDark = Color(hex: "#26263A")
    static let surfaceLight = Color(hex: "#F5F7FF")
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#C9D0FF")
    static let textMuted = Color(hex: "#99A0C2")

    static let borderSoft = Color(hex: "#41446A")
    static let dividerSoft = Color(hex: "#3B3F60")

    static let success = Color(hex: "#3DD28A")
    static let warning = Color(hex: "#FFB950")
    static let error = Color(hex: "#FF6B6B")
}

enum DaylightTypography {
    static let titleLarge = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let titleMedium = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let bodySecondary = Font.system(size: 14, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
}

enum DaylightSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum DaylightRadius {
    static let pill: CGFloat = 999
    static let card: CGFloat = 24
    static let chip: CGFloat = 16
    static let lamp: CGFloat = 999
}

enum DaylightShadow {
    static let lamp = ShadowStyle(color: Color.black.opacity(0.45),
                                  radius: 28,
                                  x: 0,
                                  y: 18)

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

enum DaylightDurations {
    static let glowOn: Double = 0.60
    static let glowOff: Double = 0.40
    static let tap: Double = 0.18
}

enum DaylightEasing {
    static let glow = Animation.timingCurve(0.17, 0.89, 0.32, 1.28, duration: DaylightDurations.glowOn)
    static let fade = Animation.easeOut(duration: DaylightDurations.glowOff)
}
