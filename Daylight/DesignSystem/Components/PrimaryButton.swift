import SwiftUI

struct DaylightPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
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
                        .tint(DaylightColors.textPrimary)
                } else {
                    Text(title)
                        .font(DaylightTypography.body.bold())
                        .foregroundColor(DaylightColors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                LinearGradient(colors: [DaylightColors.lampGoldDeep, DaylightColors.lampGold],
                               startPoint: .leading,
                               endPoint: .trailing)
            )
            .cornerRadius(DaylightRadius.pill)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
