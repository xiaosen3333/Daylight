import SwiftUI

/// 主按钮 - 用于 Today/DayCommitment 等页面的主操作
/// 背景: actionPrimary (#467577), 文字: white 90%, 圆角: button(28)
struct DaylightPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(DaylightTypography.headline)
                        .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DaylightColors.actionPrimary)
            .cornerRadius(DaylightRadius.button)
            .opacity(isEnabled ? 1.0 : DaylightTextOpacity.disabled)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
