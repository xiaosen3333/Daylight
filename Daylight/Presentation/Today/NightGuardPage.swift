import SwiftUI

struct NightGuardPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                nightBackground
                VStack(spacing: 24) {
                    starAndMoon(width: proxy.size.width * 0.8)
                        .padding(.top, 120) // 下移到与白天承诺页相近的位置

                    Text(NSLocalizedString("night.title", comment: ""))
                        .daylight(.display,
                                  color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary),
                                  alignment: .center,
                                  lineLimit: 2)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Text(viewModel.state.record?.commitmentText ?? NSLocalizedString("night.subtitle.placeholder", comment: ""))
                        .daylight(.body,
                                  color: .white.opacity(DaylightTextOpacity.secondary),
                                  alignment: .center)
                        .padding(.horizontal, 24)

                    DaylightSecondaryButton(
                        title: NSLocalizedString("night.button", comment: ""),
                        icon: "checkmark"
                    ) {
                        Task {
                            await viewModel.confirmSleepNow()
                            if viewModel.state.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .padding(.top, 4)

                    Spacer()

                }
                .padding(.horizontal, 32)
            }
            .ignoresSafeArea()
        }
    }

    private var nightBackground: some View {
        DaylightColors.bgNight
    }

    private func starAndMoon(width: CGFloat) -> some View {
        let height = width * 0.8
        return ZStack {
            GlowingMoon(size: 120)
        }
        .frame(width: width, height: height)
    }

}
