import SwiftUI

/// 主页面对齐 docs/ui/mainscreen.png
struct TodayView: View {
    @StateObject var viewModel: TodayViewModel
    @State private var showDayPage = false
    @State private var showNightPage = false
    @State private var showSettingsPage = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            showSettingsPage = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 10)
                    }
                    .padding(.top, 44)
                    .padding(.trailing, 20)

                    VStack(spacing: 28) {
                        glowingSun
                            .padding(.top, 40)

                        VStack(spacing: 12) {
                            Text(NSLocalizedString("home.title", comment: ""))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                            Text(NSLocalizedString("home.subtitle", comment: ""))
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 12)

                        getStartedButton
                            .padding(.top, 12)

                        Spacer()

                        lightChainBar
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 36)
                }
            }
            .ignoresSafeArea()
            .onAppear { viewModel.onAppear() }
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
                if deeplink == "day" {
                    showDayPage = true
                } else if deeplink == "night" {
                    showNightPage = true
                }
            }
            .alert("提示", isPresented: errorAlertBinding) {
                Button(NSLocalizedString("common.confirm", comment: ""), role: .cancel) {
                    viewModel.state.errorMessage = nil
                }
            } message: {
                Text(viewModel.state.errorMessage ?? "")
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { isShowing in
                if !isShowing {
                    viewModel.state.errorMessage = nil
                }
            }
        )
    }

    private var background: some View {
        Color(red: 93/255, green: 140/255, blue: 141/255)
    }

    private var glowingSun: some View {
        ZStack {
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.5))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.6))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                .frame(width: 140, height: 140)
        }
        .padding(.top, 40)
    }

    private var getStartedButton: some View {
        Button {
            showDayPage = true
        } label: {
            Text(NSLocalizedString("home.button", comment: ""))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(28)
        }
        .buttonStyle(.plain)
    }

    private var progressDots: some View {
        HStack(spacing: 18) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
            }
        }
    }

    private var lightChainBar: some View {
        HStack(spacing: 18) {
            ForEach(0..<6) { index in
                Circle()
                    .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
            }
        }
    }
}

// MARK: - Day Commitment Page 对齐 daycommit.png
struct DayCommitmentPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        ZStack {
            Color(red: 93/255, green: 140/255, blue: 141/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                glowingSun
                    .padding(.top, 40)

                Text(NSLocalizedString("commit.title.full", comment: ""))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    capsuleField(title: NSLocalizedString("commit.placeholder.short", comment: ""), isEditable: true)
                    suggestionButton(text: NSLocalizedString("commit.suggestion1", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion2", comment: ""))
                    suggestionButton(text: NSLocalizedString("commit.suggestion3", comment: ""))
                }
                .padding(.top, 12)

                Button {
                    Task {
                        viewModel.commitmentText = text
                        await viewModel.submitCommitment()
                        if viewModel.state.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Text(NSLocalizedString("common.confirm", comment: ""))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                        .cornerRadius(28)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 18) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < 4 ? Color(red: 255/255, green: 236/255, blue: 173/255) : Color.white.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 32)
            .onAppear {
                text = viewModel.state.record?.commitmentText ?? ""
            }
        }
    }

    private var glowingSun: some View {
        ZStack {
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.5))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255).opacity(0.6))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
            Circle()
                .fill(Color(red: 255/255, green: 236/255, blue: 173/255))
                .frame(width: 120, height: 120)
        }
    }

    private func capsuleField(title: String, isEditable: Bool) -> some View {
        Group {
            if isEditable {
                TextField(title, text: Binding(
                    get: { text },
                    set: { text = $0 }
                ))
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(24)
                .foregroundColor(.white)
            } else {
                Text(title)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                    .cornerRadius(24)
                    .foregroundColor(.white)
            }
        }
    }

    private func suggestionButton(text suggestion: String) -> some View {
        Button {
            text = suggestion
        } label: {
            Text(suggestion)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                .cornerRadius(24)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
