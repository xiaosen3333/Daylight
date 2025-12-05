import SwiftUI

struct NightGuardPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    private var context: TodayViewModel.NightGuardContext? {
        let targetDayKey = viewModel.nightDayKey ?? viewModel.state.record?.date ?? viewModel.todayKey()
        return viewModel.nightGuardContext(dayKeyOverride: targetDayKey)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                nightBackground
                VStack(spacing: 24) {
                    starAndMoon(width: proxy.size.width * 0.8)
                        .padding(.top, 96)

                    if let context = context {
                        content(for: context)
                    } else {
                        ProgressView()
                            .tint(DaylightColors.glowGold)
                            .padding(.top, 16)
                    }

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

    @ViewBuilder
    private func content(for context: TodayViewModel.NightGuardContext) -> some View {
        VStack(spacing: 14) {
            Text(headline(for: context))
                .daylight(.display,
                          color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary),
                          alignment: .center,
                          lineLimit: 2)
                .padding(.horizontal, 8)

            if let body = bodyText(for: context) {
                Text(body)
                    .daylight(.body,
                              color: .white.opacity(DaylightTextOpacity.secondary),
                              alignment: .center)
                    .padding(.horizontal, 8)
            }

            actionButtons(for: context)
        }
    }

    private func starAndMoon(width: CGFloat) -> some View {
        let height = width * 0.8
        return ZStack {
            GlowingMoon(size: 120)
        }
        .frame(width: width, height: height)
    }

    private func headline(for context: TodayViewModel.NightGuardContext) -> String {
        switch context.phase {
        case .expired, .afterCutoff:
            return NSLocalizedString("night.state.expired.title", comment: "")
        case .completed:
            return NSLocalizedString("night.state.completed.title", comment: "")
        case .notEligible:
            return NSLocalizedString("night.state.notReady.title", comment: "")
        default:
            return NSLocalizedString("night.title", comment: "")
        }
    }

    private func bodyText(for context: TodayViewModel.NightGuardContext) -> String? {
        switch context.phase {
        case .early, .inWindow:
            return context.record.commitmentText ?? NSLocalizedString("night.subtitle.placeholder", comment: "")
        case .notEligible:
            return NSLocalizedString("night.subtitle.notReady", comment: "")
        default:
            return nil
        }
    }

    @ViewBuilder
    private func actionButtons(for context: TodayViewModel.NightGuardContext) -> some View {
        switch context.phase {
        case .early:
            earlyActions(for: context)
        case .inWindow:
            inWindowActions(for: context)
        case .expired, .afterCutoff:
            expiredActions()
        case .completed:
            completedActions()
        case .notEligible:
            notEligibleActions()
        case .beforeEarly:
            beforeEarlyActions()
        }
    }

    @ViewBuilder
    private func earlyActions(for context: TodayViewModel.NightGuardContext) -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button.early", comment: ""),
                              kind: .nightPrimary,
                              isEnabled: !viewModel.state.isSavingNight,
                              isLoading: viewModel.state.isSavingNight) {
                Task {
                    await viewModel.confirmSleepNow(allowEarly: true, dayKey: context.dayKey)
                    if viewModel.state.errorMessage == nil {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inWindowActions(for context: TodayViewModel.NightGuardContext) -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button", comment: ""),
                              kind: .nightPrimary,
                              isEnabled: !viewModel.state.isSavingNight,
                              isLoading: viewModel.state.isSavingNight) {
                Task {
                    await viewModel.confirmSleepNow(dayKey: context.dayKey)
                    if viewModel.state.errorMessage == nil {
                        dismiss()
                    }
                }
            }

            DaylightCTAButton(title: NSLocalizedString("night.button.continue", comment: ""),
                              kind: .nightPrimary,
                              isEnabled: !viewModel.state.isSavingNight) {
                Task {
                    await viewModel.rejectNightOnce(dayKey: context.dayKey)
                    if viewModel.state.errorMessage == nil {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func expiredActions() -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button.home", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
            }

            DaylightCTAButton(title: NSLocalizedString("night.button.adjust", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
                viewModel.navigateToSettingsPage()
            }
        }
    }

    @ViewBuilder
    private func completedActions() -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button.home", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func notEligibleActions() -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button.commit", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
                DispatchQueue.main.async {
                    viewModel.navigateToDayPage()
                }
            }

            DaylightCTAButton(title: NSLocalizedString("night.button.home", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func beforeEarlyActions() -> some View {
        VStack(spacing: 12) {
            DaylightCTAButton(title: NSLocalizedString("night.button.home", comment: ""),
                              kind: .nightPrimary) {
                dismiss()
            }
        }
    }
}
