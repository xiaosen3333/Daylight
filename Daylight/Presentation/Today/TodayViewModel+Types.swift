import Foundation

extension TodayViewModel {
    struct Suggestion: Identifiable, Equatable {
        let id: String
        let text: String
    }

    struct SuggestionSlot: Identifiable, Equatable {
        let id: String
        let text: String?

        var isEmpty: Bool { text?.isEmpty ?? true }
    }

    enum RefreshTrigger {
        case manual, timer, foreground
    }

    enum SettingsSyncState: Equatable {
        case idle
        case syncing
        case pending(nextRetryAt: Date?)
        case failed(nextRetryAt: Date?)
        case synced
    }

    enum NightGuardPhase {
        case notEligible
        case beforeEarly
        case early
        case inWindow
        case expired
        case completed
        case afterCutoff
    }

    enum RecoveryAction: Equatable {
        case day
        case night(dayKey: String)
        case none
    }

    struct NightGuardContext {
        let dayKey: String
        let record: DayRecord
        let timeline: NightTimeline
        let phase: NightGuardPhase

        var allowEarlyConfirm: Bool { phase == .early }
        var canReject: Bool { phase == .inWindow }
        var isExpired: Bool { phase == .expired || phase == .afterCutoff }
        var showHomeCTA: Bool {
            switch phase {
            case .early, .inWindow, .expired:
                return true
            default:
                return false
            }
        }
    }

    struct UIState {
        var isLoading: Bool = false
        var isSavingCommitment: Bool = false
        var isSavingNight: Bool = false
        var record: DayRecord?
        var settings: Settings?
        var streak: StreakResult?
        var errorMessage: String?
    }
}
