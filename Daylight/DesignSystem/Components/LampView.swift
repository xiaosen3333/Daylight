import SwiftUI

struct LampView: View {
    enum State {
        case off
        case on
    }

    let state: State
    let size: CGFloat

    var body: some View {
        ZStack {
            if state == .on {
                Circle()
                    .fill(DaylightColors.lampGoldDeep.opacity(0.55))
                    .frame(width: size * 1.8, height: size * 1.8)
                    .blur(radius: size * 0.35)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: state == .on
                        ? [DaylightColors.lampGold, DaylightColors.lampGoldDeep]
                        : [DaylightColors.surfaceLight.opacity(0.7), DaylightColors.surfaceLight.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.4),
                        radius: size * 0.3,
                        x: 0,
                        y: size * 0.25)
                .overlay(
                    Circle()
                        .stroke(state == .on ? DaylightColors.borderSoft.opacity(0.3) : DaylightColors.borderSoft.opacity(0.6), lineWidth: 1.5)
                )
                .scaleEffect(state == .on ? 1.0 : 0.94)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
                .opacity(state == .on ? 1.0 : 0.8)
        }
    }
}

struct MiniLampView: View {
    let state: LampView.State

    var body: some View {
        LampView(state: state, size: 22)
            .shadow(color: LampView.State.on == state ? DaylightColors.lampGold.opacity(0.6) : .clear,
                    radius: LampView.State.on == state ? 6 : 0)
    }
}
