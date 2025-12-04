import Foundation

struct TodayState {
    let record: DayRecord
    let settings: Settings
}

struct StreakResult {
    let current: Int
    let longest: Int
}

struct UndoSleepResult {
    let record: DayRecord
    let timeline: NightTimeline
}
