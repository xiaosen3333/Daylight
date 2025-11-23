import SwiftUI

/// 主页面对齐 docs/ui/mainscreen.png
struct TodayView: View {
    @StateObject var viewModel: TodayViewModel
    @State private var showDayPage = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 28) {
                glowingSun
                    .padding(.top, 80)

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
        .ignoresSafeArea()
        .onAppear { viewModel.onAppear() }
        .onTapGesture {
            showDayPage = true
        }
        .sheet(isPresented: $showDayPage) {
            DayCommitmentPage(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
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

// MARK: - Day Commitment Page (简单延用现有逻辑)
struct DayCommitmentPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("commit.title", comment: ""))
                    .font(.title2.bold())
                TextField(NSLocalizedString("commit.placeholder", comment: ""), text: $text, axis: .vertical)
                    .lineLimit(3...4)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4)))

                Spacer()

                Button {
                    Task {
                        viewModel.commitmentText = text
                        await viewModel.submitCommitment()
                        dismiss()
                    }
                } label: {
                    Text(NSLocalizedString("common.confirm", comment: ""))
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 70/255, green: 117/255, blue: 119/255))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            }
            .padding()
            .onAppear {
                text = viewModel.state.record?.commitmentText ?? ""
            }
            .navigationTitle(NSLocalizedString("commit.nav", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }
}
