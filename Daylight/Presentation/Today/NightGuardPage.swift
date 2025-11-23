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
                        .multilineTextAlignment(.center)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(moonColor.opacity(0.9))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    Text(viewModel.state.record?.commitmentText ?? NSLocalizedString("night.subtitle.placeholder", comment: ""))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)

                    Button {
                        Task {
                            await viewModel.confirmSleepNow()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(moonColor.opacity(0.9))
                            Text(NSLocalizedString("night.button", comment: ""))
                                .foregroundColor(moonColor.opacity(0.9))
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(28)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer()

                    HStack(spacing: 18) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < 4 ? moonColor : Color.white.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
            }
            .ignoresSafeArea()
        }
    }

    private var moonColor: Color {
        Color(red: 255/255, green: 236/255, blue: 173/255)
    }

    private var nightBackground: some View {
        Color(red: 12/255, green: 39/255, blue: 64/255)
    }

    private var glowingMoon: some View {
        ZStack {
            Circle()
                .fill(moonColor.opacity(0.45))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
            Circle()
                .fill(moonColor.opacity(0.6))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
            Circle()
                .fill(moonColor)
                .frame(width: 120, height: 120)
        }
    }

    private func starAndMoon(width: CGFloat) -> some View {
        let height = width * 0.8
        return ZStack {
            glowingMoon
        }
        .frame(width: width, height: height)
    }

}
