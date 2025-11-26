import SwiftUI

@main
struct DaylightApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ForegroundNotificationDelegate.shared.activate()
        LanguageManager.shared.applySavedLanguage()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel = container.todayViewModel {
                    TodayView(viewModel: viewModel)
                        .environment(\.locale, viewModel.locale)
                        .id(viewModel.locale.identifier)
                } else if let error = container.errorMessage {
                    VStack(spacing: 16) {
                        Text("启动失败")
                            .font(DaylightTypography.headline)
                            .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                        Text(error)
                            .font(DaylightTypography.body)
                            .foregroundColor(.white.opacity(DaylightTextOpacity.secondary))
                        Button("重试") {
                            container.bootstrap()
                        }
                        .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DaylightColors.bgPrimary.ignoresSafeArea())
                } else {
                    ZStack {
                        DaylightColors.bgPrimary.ignoresSafeArea()
                        ProgressView("加载中…")
                            .tint(DaylightColors.glowGold)
                            .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                    }
                }
            }
            .onAppear { container.bootstrap() }
            .onChange(of: scenePhase) { _, newPhase in
                container.scenePhaseChanged(newPhase)
            }
        }
    }
}
