import SwiftUI

/// 统一 CTA 按钮（Day / Night / Ghost）
struct DaylightCTAButton: View {
    enum Kind {
        case dayPrimary
        case nightPrimary
        case ghost
    }

    let title: String
    let kind: Kind
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(opacity)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .dayPrimary:
            dayPrimaryContent
        case .nightPrimary:
            nightPrimaryContent
        case .ghost:
            ghostContent
        }
    }

    private var dayPrimaryContent: some View {
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
    }

    private var nightPrimaryContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DaylightColors.glowGold)
            } else {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                    }
                    Text(title)
                        .font(DaylightTypography.subheadSemibold)
                        .foregroundColor(DaylightColors.glowGold.opacity(DaylightTextOpacity.primary))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DaylightColors.bgOverlay12)
        .cornerRadius(DaylightRadius.button)
    }

    private var ghostContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Text(title)
                    .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.xs)
    }

    private var isDisabled: Bool {
        switch kind {
        case .dayPrimary:
            return false
        case .nightPrimary, .ghost:
            return !isEnabled || isLoading
        }
    }

    private var opacity: Double {
        isEnabled ? 1.0 : DaylightTextOpacity.disabled
    }
}
