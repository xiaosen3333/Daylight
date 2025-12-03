import SwiftUI

/// 主按钮 - 用于 Today/DayCommitment 等页面的主操作（内部别名，推荐使用 DaylightCTAButton）
/// 背景: actionPrimary (#467577), 文字: white 90%, 圆角: button(28)
struct DaylightPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        DaylightCTAButton(title: title,
                          kind: .dayPrimary,
                          isEnabled: isEnabled,
                          isLoading: isLoading,
                          action: action)
    }
}
