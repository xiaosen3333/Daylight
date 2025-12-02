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
        VStack(spacing: 16) {
            if context.dayKey != viewModel.todayKey() {
                Text(String(format: NSLocalizedString("night.hint.dayKey", comment: ""), context.dayKey))
                    .daylight(.caption1,
                              color: .white.opacity(DaylightTextOpacity.secondary),
                              alignment: .center)
                    .padding(.horizontal, 12)
            }

            Text(headline(for: context))
                .daylight(.display,
                          color: DaylightColors.glowGold.opacity(DaylightTextOpacity.primary),
                          alignment: .center,
                          lineLimit: 2)
                .padding(.horizontal, 8)

            Text(bodyText(for: context))
                .daylight(.body,
                          color: .white.opacity(DaylightTextOpacity.secondary),
                          alignment: .center)
                .padding(.horizontal, 8)

            if let hint = secondaryHint(for: context) {
                Text(hint)
                    .daylight(.footnote,
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

    private func bodyText(for context: TodayViewModel.NightGuardContext) -> String {
        switch context.phase {
        case .early, .inWindow:
            return context.record.commitmentText ?? NSLocalizedString("night.subtitle.placeholder", comment: "")
        case .completed:
            return NSLocalizedString("night.hint.completed", comment: "")
        case .expired, .afterCutoff:
            return NSLocalizedString("night.hint.expired", comment: "")
        case .notEligible:
            return NSLocalizedString("night.hint.notReady", comment: "")
        case .beforeEarly:
            let timeText = viewModel.dateHelper.displayTimeString(from: context.timeline.earlyStart)
            return String(format: NSLocalizedString("night.hint.tooEarly", comment: ""), timeText)
        }
    }

    private func secondaryHint(for context: TodayViewModel.NightGuardContext) -> String? {
        switch context.phase {
        case .early:
            return NSLocalizedString("night.hint.early", comment: "")
        default:
            return nil
        }
    }

    @ViewBuilder
    private func actionButtons(for context: TodayViewModel.NightGuardContext) -> some View {
        switch context.phase {
        case .early:
            VStack(spacing: 12) {
                DaylightPrimaryButton(title: NSLocalizedString("night.button.early", comment: ""),
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
        case .inWindow:
            VStack(spacing: 12) {
                DaylightPrimaryButton(title: NSLocalizedString("night.button", comment: ""),
                                      isEnabled: !viewModel.state.isSavingNight,
                                      isLoading: viewModel.state.isSavingNight) {
                    Task {
                        await viewModel.confirmSleepNow(dayKey: context.dayKey)
                        if viewModel.state.errorMessage == nil {
                            dismiss()
                        }
                    }
                }

                DaylightSecondaryButton(title: NSLocalizedString("night.button.continue", comment: ""),
                                        isEnabled: !viewModel.state.isSavingNight) {
                    Task {
                        await viewModel.rejectNightOnce(dayKey: context.dayKey)
                        if viewModel.state.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            }
        case .expired, .afterCutoff:
            VStack(spacing: 12) {
                DaylightSecondaryButton(title: NSLocalizedString("night.button.home", comment: "")) {
                    dismiss()
                }

                DaylightGhostButton(title: NSLocalizedString("night.button.adjust", comment: "")) {
                    dismiss()
                    viewModel.navigateToSettingsPage()
                }
            }
        case .completed:
            VStack(spacing: 12) {
                DaylightSecondaryButton(title: NSLocalizedString("night.button.home", comment: "")) {
                    dismiss()
                }
            }
        case .notEligible, .beforeEarly:
            VStack(spacing: 12) {
                DaylightSecondaryButton(title: NSLocalizedString("night.button.home", comment: "")) {
                    dismiss()
                }
            }
        }
    }
}
