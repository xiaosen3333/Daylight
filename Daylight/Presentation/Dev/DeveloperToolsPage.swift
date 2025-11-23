import SwiftUI

struct DeveloperToolsPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 93/255, green: 140/255, blue: 141/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(NSLocalizedString("dev.title", comment: ""))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 40)

                Button {
                    Task { await viewModel.triggerDayReminderNow() }
                } label: {
                    Text(NSLocalizedString("dev.trigger.day", comment: ""))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.triggerNightReminderNow() }
                } label: {
                    Text(NSLocalizedString("dev.trigger.night", comment: ""))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.cancel", comment: ""))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
}
