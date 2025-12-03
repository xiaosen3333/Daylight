import Foundation
import UIKit

enum TimeChangeEvent: Equatable {
    case timeZoneChanged(old: TimeZone, new: TimeZone)
    case localeFormatChanged
    case significantJump(delta: TimeInterval)
    case significantTimeChange

    var isSignificantJump: Bool {
        switch self {
        case .significantJump, .significantTimeChange:
            return true
        default:
            return false
        }
    }
}

/// 监听系统时间/时区/区域变更，基于 wall clock 与 system uptime 差值检测异常跳变。
final class TimeChangeMonitor {
    private var observers: [NSObjectProtocol] = []
    private var lastWallClock: Date
    private var lastUptime: TimeInterval
    private var lastTimeZone: TimeZone
    private let jumpThreshold: TimeInterval
    var onEvent: ((TimeChangeEvent) -> Void)?

    init(jumpThreshold: TimeInterval = 5 * 60, onEvent: ((TimeChangeEvent) -> Void)? = nil) {
        self.jumpThreshold = jumpThreshold
        self.onEvent = onEvent
        let now = Date()
        lastWallClock = now
        lastUptime = ProcessInfo.processInfo.systemUptime
        lastTimeZone = TimeZone.autoupdatingCurrent
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSNotification.Name.NSSystemTimeZoneDidChange,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.handleTimeZoneChange()
        })
        observers.append(center.addObserver(forName: UIApplication.significantTimeChangeNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.handleSignificantTimeChange()
        })
        observers.append(center.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.handleLocaleChange()
        })
    }

    func stop() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handleTimeZoneChange() {
        let oldZone = lastTimeZone
        let newZone = TimeZone.autoupdatingCurrent
        lastTimeZone = newZone
        detectJumpIfNeeded()
        guard oldZone != newZone else { return }
        onEvent?(.timeZoneChanged(old: oldZone, new: newZone))
    }

    private func handleLocaleChange() {
        detectJumpIfNeeded()
        onEvent?(.localeFormatChanged)
    }

    private func handleSignificantTimeChange() {
        detectJumpIfNeeded()
        onEvent?(.significantTimeChange)
    }

    private func detectJumpIfNeeded() {
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let wallDelta = now.timeIntervalSince(lastWallClock)
        let uptimeDelta = uptime - lastUptime
        let delta = abs(wallDelta - uptimeDelta)
        lastWallClock = now
        lastUptime = uptime
        if delta >= jumpThreshold {
            onEvent?(.significantJump(delta: delta))
        }
    }

    deinit {
        stop()
    }
}
