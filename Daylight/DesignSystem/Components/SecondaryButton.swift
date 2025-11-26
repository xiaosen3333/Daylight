import SwiftUI

/// 次级按钮 - 用于夜间页 CTA 等场景
/// 背景: overlay12, 文字: glowGold 90%, 圆角: button(28)
struct DaylightSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                }
                Text(title)
                    .font(DaylightTypography.subheadSemibold)
                    .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DaylightColors.bgOverlay12)
            .cornerRadius(DaylightRadius.button)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : DaylightTextOpacity.disabled)
        .buttonStyle(.plain)
    }
}
