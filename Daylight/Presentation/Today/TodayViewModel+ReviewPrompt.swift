import Foundation
import StoreKit
import UIKit

extension TodayViewModel {
    func requestReviewIfEligible(record: DayRecord, now: Date = Date()) {
        guard record.dayLightStatus == .on, record.nightLightStatus == .on else { return }
        requestReview(now: now)
    }

    private func requestReview(now: Date = Date()) {
        guard reviewPromptStore.canPrompt(now: now) else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        reviewPromptStore.recordPrompt(now: now, action: .later)
        SKStoreReviewController.requestReview(in: scene)
    }
}
