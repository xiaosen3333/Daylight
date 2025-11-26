import SwiftUI

struct DeveloperToolsPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DaylightColors.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(NSLocalizedString("dev.title", comment: ""))
                    .font(DaylightTypography.devTitle)
                    .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                    .padding(.top, 40)

                Button {
                    Task { await viewModel.triggerDayReminderNow() }
                } label: {
                    Text(NSLocalizedString("dev.trigger.day", comment: ""))
                        .font(DaylightTypography.callout)
                        .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DaylightColors.bgOverlay15)
                        .cornerRadius(DaylightRadius.devButton)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.triggerNightReminderNow() }
                } label: {
                    Text(NSLocalizedString("dev.trigger.night", comment: ""))
                        .font(DaylightTypography.callout)
                        .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DaylightColors.bgOverlay15)
                        .cornerRadius(DaylightRadius.devButton)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.cancel", comment: ""))
                        .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(DaylightColors.bgOverlay10)
                        .cornerRadius(DaylightRadius.xs)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
}
