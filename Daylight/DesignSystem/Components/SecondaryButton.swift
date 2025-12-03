import SwiftUI

/// 次级按钮 - 用于夜间页 CTA 等场景（内部别名，推荐使用 DaylightCTAButton）
/// 背景: overlay12, 文字: glowGold 90%, 圆角: button(28)
struct DaylightSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        DaylightCTAButton(title: title,
                          kind: .nightPrimary,
                          isEnabled: isEnabled,
                          isLoading: isLoading,
                          icon: icon,
                          action: action)
    }
}
