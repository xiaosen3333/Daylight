import SwiftUI

/// 幽灵按钮 - 用于 Settings 开发者操作等场景
/// 背景: overlay08, 文字: white 90%, 圆角: xs(12)
struct DaylightGhostButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white.opacity(DaylightTextOpacity.primary))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(DaylightColors.bgOverlay08)
                .cornerRadius(DaylightRadius.xs)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : DaylightTextOpacity.disabled)
        .buttonStyle(.plain)
    }
}
