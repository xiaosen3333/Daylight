import SwiftUI

/// 主页面对齐 docs/ui/mainscreen.png
struct TodayView: View {
    @StateObject var viewModel: TodayViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State var showDayPage = false
    @State var showNightPage = false
    @State var showSettingsPage = false
    @State var showStats = false
    @State var isLoadingStats = false
    @State var selectedRecord: DayRecord?
    @State var currentMonth: Date = Date()
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                background
                GeometryReader { geo in
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)

                        content(for: geo.size)
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        scrollOffset = offset
                        if showStats && offset > 60 {
                            toggleStats()
                        }
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { value in
                            if showStats && scrollOffset >= -10 && value.translation.height > 60 {
                                toggleStats()
                            }
                        }
                    )
                }
            }
            .ignoresSafeArea()
            .onAppear {
                viewModel.onAppear()
            }
            .environment(\.locale, viewModel.locale)
            .navigationDestination(isPresented: $showDayPage) {
                DayCommitmentPage(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showNightPage) {
                NightGuardPage(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showSettingsPage) {
                SettingsPage(viewModel: viewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: .daylightNavigate)) { notification in
                guard let deeplink = notification.userInfo?["deeplink"] as? String else { return }
                let dayKey = notification.userInfo?["dayKey"] as? String
                handleDeeplink(deeplink, dayKey: dayKey)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    _ = await viewModel.refreshIfNeeded(trigger: .foreground, includeMonth: showStats)
                    await viewModel.handleNotificationRecovery()
                    if showStats {
                        await loadStatsData()
                    }
                }
            }
            .onChange(of: viewModel.recoveryAction) { _, action in
                guard let action else { return }
                switch action {
                case .day:
                    showDayPage = true
                case .night(let dayKey):
                    viewModel.prepareNightPage(dayKey: dayKey)
                    showNightPage = true
                case .none:
                    break
                }
                viewModel.recoveryAction = nil
            }
        }
    }

    @ViewBuilder
    private func content(for size: CGSize) -> some View {
        VStack(spacing: showStats ? TodayViewLayout.compactStackSpacing : TodayViewLayout.stackSpacing) {
            TodayHeaderView {
                showSettingsPage = true
            }
            .padding(.top, TodayViewLayout.headerTopPadding)
            .padding(.horizontal, TodayViewLayout.headerHorizontalPadding)

            SummaryCardView(homeTitle: homeTitle, homeSubtitle: homeSubtitle, showStats: showStats) {
                QuickActionsView {
                    getStartedButton
                        .padding(.top, 6)
                    if showSleepCTA {
                        sleepCTAButton
                    }
                    if let wakeButton {
                        wakeButton
                    }
                }
            }
            .padding(.horizontal, 28)
            .offset(y: showStats ? TodayViewLayout.statsLift : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showStats)

            Spacer(minLength: showStats ? TodayViewLayout.compactSpacer : TodayViewLayout.defaultSpacer)

            TimelineSectionView(lightChainBar: lightChainBar.eraseToAnyView(),
                                statsGrid: showStats ? AnyView(statsGrid) : nil)

            if let tipsContent {
                TipsCardView {
                    tipsContent
                }
            }
        }
        .frame(minHeight: size.height + (showStats ? TodayViewLayout.statsExtraHeight : 0))
    }
}
