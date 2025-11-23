import SwiftUI

@main
struct DaylightApp: App {
    @StateObject private var container = AppContainer()

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
                            .font(DaylightTypography.titleMedium)
                            .foregroundColor(DaylightColors.textPrimary)
                        Text(error)
                            .font(DaylightTypography.bodySecondary)
                            .foregroundColor(DaylightColors.textSecondary)
                        Button("重试") {
                            container.bootstrap()
                        }
                        .foregroundColor(DaylightColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [DaylightColors.nightIndigo, DaylightColors.nightSky],
                                       startPoint: .top,
                                       endPoint: .bottom)
                            .ignoresSafeArea()
                    )
                } else {
                    ZStack {
                        LinearGradient(colors: [DaylightColors.nightIndigo, DaylightColors.nightSky],
                                       startPoint: .top,
                                       endPoint: .bottom)
                            .ignoresSafeArea()
                        ProgressView("加载中…")
                            .tint(DaylightColors.lampGoldDeep)
                            .foregroundColor(DaylightColors.textPrimary)
                    }
                }
            }
            .onAppear { container.bootstrap() }
        }
    }
}
