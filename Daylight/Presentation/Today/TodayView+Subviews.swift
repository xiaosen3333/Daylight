import SwiftUI

struct TodayHeaderView: View {
    let onSettingsTap: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white.opacity(DaylightTextOpacity.secondary))
                    .padding(TodayViewLayout.headerButtonPadding)
                    .background(DaylightColors.bgOverlay12)
                    .clipShape(Circle())
            }
            .padding(.trailing, TodayViewLayout.headerButtonPadding)
        }
    }
}

struct SummaryCardView<Actions: View>: View {
    let homeTitle: String
    let homeSubtitle: String
    let showStats: Bool
    private let actions: Actions

    init(homeTitle: String, homeSubtitle: String, showStats: Bool, @ViewBuilder actions: () -> Actions) {
        self.homeTitle = homeTitle
        self.homeSubtitle = homeSubtitle
        self.showStats = showStats
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: showStats ? TodayViewLayout.summaryCompactSpacing : TodayViewLayout.summarySpacing) {
            GlowingSun(size: TodayViewLayout.sunSize)
                .padding(.top, showStats ? TodayViewLayout.summaryCompactTopPadding : TodayViewLayout.summaryTopPadding)

            VStack(spacing: showStats ? TodayViewLayout.summaryTextCompactSpacing : TodayViewLayout.summaryTextSpacing) {
                Text(homeTitle)
                    .daylight(.hero, alignment: .center, lineLimit: 2)
                Text(homeSubtitle)
                    .daylight(.bodyLarge,
                              color: .white.opacity(DaylightTextOpacity.secondary),
                              alignment: .center,
                              lineLimit: 2)
            }
            .padding(.top, TodayViewLayout.summaryTextTopPadding)

            if !showStats {
                actions
            }
        }
    }
}

struct QuickActionsView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 6) {
            content
        }
    }
}

struct TimelineSectionView: View {
    let lightChainBar: AnyView
    let statsGrid: AnyView?

    var body: some View {
        VStack(spacing: 0) {
            lightChainBar
                .padding(.bottom, TodayViewLayout.timelineBottomPadding)
            if let statsGrid {
                statsGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 32)
            }
        }
    }
}

struct TipsCardView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaylightColors.bgOverlay08)
        .cornerRadius(DaylightRadius.card)
        .padding(.horizontal, 12)
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
