import Foundation

final class TodayTimeObserver {
    private var dayChangeTask: Task<Void, Never>?
    private var dateHelper: DaylightDateHelper

    init(dateHelper: DaylightDateHelper) {
        self.dateHelper = dateHelper
    }

    func scheduleDayChangeCheck(settings: Settings, handler: @escaping () async -> Void) {
        cancel()
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        let fireAt = dateHelper.nextLocalDayBoundary(after: Date(), nightWindow: window)
        let delaySeconds = max(fireAt.timeIntervalSinceNow, 1)
        let delayNanos = UInt64(delaySeconds * 1_000_000_000)
        dayChangeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled else { return }
            await handler()
            self?.dayChangeTask = nil
        }
    }

    func cancel() {
        dayChangeTask?.cancel()
        dayChangeTask = nil
    }

    func update(dateHelper: DaylightDateHelper) {
        self.dateHelper = dateHelper
    }
}
