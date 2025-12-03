import SwiftUI

/// 幽灵按钮 - 用于 Settings 开发者操作等场景（内部别名，推荐使用 DaylightCTAButton）
/// 背景: overlay08, 文字: white 90%, 圆角: xs(12)
struct DaylightGhostButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        DaylightCTAButton(title: title,
                          kind: .ghost,
                          isEnabled: isEnabled,
                          isLoading: isLoading,
                          action: action)
    }
}
