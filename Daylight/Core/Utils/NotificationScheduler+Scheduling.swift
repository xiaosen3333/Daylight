import UserNotifications

struct NotificationSchedulePlan {
    let dayKey: String
    let nextDayKey: String?
    let context: NotificationContext
    let nextDayContext: NotificationContext
    let nightReminderNeeded: Bool
}

private struct NotificationRequestPlan {
    let identifier: String
    let request: UNNotificationRequest
    let fireDate: Date
}

private struct NightRequestInput {
    let dayDate: Date
    let window: DaylightDateHelper.ParsedNightWindow
    let notificationContext: NotificationContext
    let dayKey: String
}

extension NotificationScheduler {
    func reschedule(settings: Settings,
                    plan: NotificationSchedulePlan,
                    now: Date = Date()) async {
        let status = await authorizationStatusWithCache()
        guard isAuthorized(status) else { return }
        resetScheduledRequests()

        var scheduledIds: [String] = []
        scheduledIds += await scheduleDaily(dayKey: plan.dayKey,
                                            settings: settings,
                                            context: plan.context,
                                            nightReminderNeeded: plan.nightReminderNeeded,
                                            now: now)
        if let nextKey = plan.nextDayKey {
            scheduledIds += await scheduleDaily(dayKey: nextKey,
                                                settings: settings,
                                                context: plan.nextDayContext,
                                                nightReminderNeeded: settings.nightReminderEnabled,
                                                now: now)
        }
        saveScheduled(ids: scheduledIds, dayKey: plan.dayKey)
    }

    /// 立即触发一次白昼提醒（开发调试用）
    func triggerDayReminderNow(context: NotificationContext) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_day_\(UUID().uuidString)",
                                            content: makeDayContent(context: context, dayKey: nil),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// 立即触发一次夜间提醒（开发调试用）
    func triggerNightReminderNow(context: NotificationContext, round: Int = 1) async {
        guard await requestAuthorization() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dev_daylight_night_\(UUID().uuidString)",
                                            content: makeNightContent(round: round, context: context, dayKey: nil),
                                            trigger: trigger)
        try? await center.add(request)
    }

    func clearNightReminders() {
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        let nightIds = stored.filter { $0.hasPrefix(nightReminderPrefix) }
        center.getPendingNotificationRequests { requests in
            let pendingNightIds = requests.map(\.identifier).filter { $0.hasPrefix(self.nightReminderPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: nightIds + pendingNightIds + self.legacyNightReminderIds)
        }
    }

    func lastScheduledDayKey() -> String? {
        defaults.string(forKey: lastScheduledDayKeyKey)
    }

    func handleTimeChange(event: TimeChangeEvent,
                          settings: Settings,
                          plan: NotificationSchedulePlan,
                          now: Date = Date()) async {
        _ = event
        await reschedule(settings: settings,
                         plan: plan,
                         now: now)
    }

    func nightReminderTimes(startMinutes: Int,
                            endMinutes: Int,
                            intervalMinutes: Int) -> [Int] {
        guard intervalMinutes > 0 else { return [] }
        let window: Int
        if startMinutes == endMinutes {
            window = 0
        } else if startMinutes < endMinutes {
            window = endMinutes - startMinutes
        } else {
            window = minutesPerDay - startMinutes + endMinutes
        }

        var times: [Int] = []
        var offset = 0
        while offset <= window {
            times.append((startMinutes + offset) % minutesPerDay)
            offset += intervalMinutes
        }
        if window > 0 {
            let endNormalized = endMinutes % minutesPerDay
            if !times.contains(endNormalized) {
                times.append(endNormalized)
            }
        }
        if startMinutes > endMinutes && endMinutes > 0 {
            times.removeAll { $0 == 0 }
        }
        return times
    }
}

// MARK: - Scheduling helpers
private extension NotificationScheduler {
    func appendRequestIfFuture(_ request: NotificationRequestPlan?,
                               scheduled: inout [String],
                               now: Date) async {
        guard let plan = request, plan.fireDate > now else { return }
        try? await center.add(plan.request)
        scheduled.append(plan.identifier)
    }

    func scheduleDaily(dayKey: String,
                       settings: Settings,
                       context: NotificationContext,
                       nightReminderNeeded: Bool,
                       now: Date = Date()) async -> [String] {
        guard let dayDate = dayFormatter.date(from: dayKey) else { return [] }

        await clearRequests(for: dayKey)
        var scheduled: [String] = []

        let dayRequest = buildDayRequest(for: dayDate, time: settings.dayReminderTime, context: context, dayKey: dayKey)
        await appendRequestIfFuture(dayRequest, scheduled: &scheduled, now: now)

        guard nightReminderNeeded, settings.nightReminderEnabled else { return scheduled }
        let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
        guard let parsedWindow = dateHelper.parsedNightWindow(window) else { return scheduled }
        let intervalMinutes = settings.nightReminderInterval
        guard intervalMinutes > 0 else { return scheduled }
        let nightInput = NightRequestInput(dayDate: dayDate,
                                           window: parsedWindow,
                                           notificationContext: context,
                                           dayKey: dayKey)

        let times = nightReminderTimes(startMinutes: parsedWindow.startMinutes,
                                       endMinutes: parsedWindow.endMinutes,
                                       intervalMinutes: intervalMinutes)
        for (index, minutes) in times.enumerated() {
            guard let nightRequest = buildNightRequest(minutes: minutes,
                                                       roundIndex: index,
                                                       input: nightInput) else { continue }
            await appendRequestIfFuture(nightRequest, scheduled: &scheduled, now: now)
        }
        return scheduled
    }

    func buildDayRequest(for dayDate: Date,
                         time: String,
                         context: NotificationContext,
                         dayKey: String) -> NotificationRequestPlan? {
        guard let components = dateComponents(for: dayDate, time: time),
              let fireDate = calendar.date(from: components) else {
            return nil
        }
        let id = dayReminderIdentifier(for: dayKey)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id,
                                            content: makeDayContent(context: context, dayKey: dayKey),
                                            trigger: trigger)
        return NotificationRequestPlan(identifier: id, request: request, fireDate: fireDate)
    }

    func buildNightRequest(minutes: Int,
                           roundIndex: Int,
                           input: NightRequestInput) -> NotificationRequestPlan? {
        guard let components = nightDateComponents(for: minutes,
                                                   dayDate: input.dayDate,
                                                   window: input.window),
              let fireDate = calendar.date(from: components) else {
            return nil
        }
        let id = nightReminderIdentifier(for: input.dayKey, roundIndex: roundIndex)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id,
                                            content: makeNightContent(round: roundIndex + 1,
                                                                      context: input.notificationContext,
                                                                      dayKey: input.dayKey),
                                            trigger: trigger)
        return NotificationRequestPlan(identifier: id, request: request, fireDate: fireDate)
    }

    func dateComponents(for day: Date, time: String) -> DateComponents? {
        guard let minutes = dateHelper.minutes(from: time) else { return nil }
        var comps = dateHelper.calendar.dateComponents(in: dateHelper.timeZone, from: day)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        comps.second = 0
        return comps
    }

    func nightDateComponents(for minutes: Int,
                             dayDate: Date,
                             window: DaylightDateHelper.ParsedNightWindow) -> DateComponents? {
        let dayOffset = window.crossesMidnight && minutes <= window.endMinutes ? 1 : 0
        let targetDay = dateHelper.date(fromDayStart: dayDate, minutesIntoDay: minutes, dayOffset: dayOffset)
        return dateHelper.calendar.dateComponents(in: dateHelper.timeZone, from: targetDay)
    }

    func dayReminderIdentifier(for dayKey: String) -> String {
        "\(dayReminderPrefix)\(dayKey)"
    }

    func nightReminderIdentifier(for dayKey: String, roundIndex: Int) -> String {
        "\(nightReminderPrefix)\(dayKey)_\(roundIndex)"
    }

    func clearRequests(for dayKey: String) async {
        let dayId = dayReminderIdentifier(for: dayKey)
        let nightPrefix = "\(nightReminderPrefix)\(dayKey)_"
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        let storedForDay = stored.filter { $0 == dayId || $0.hasPrefix(nightPrefix) }
        let pendingForDay = await pendingRequestIdentifiers(prefixes: [dayId, nightPrefix])
        var ids = Set(storedForDay + pendingForDay)
        ids.insert(dayId)
        center.removePendingNotificationRequests(withIdentifiers: Array(ids) + legacyNightReminderIds)
    }

    func clearLegacyRequests() {
        center.removePendingNotificationRequests(withIdentifiers: [dayReminderId] + legacyNightReminderIds)
    }

    func clearStoredRequests() {
        let stored = defaults.stringArray(forKey: scheduledRequestIdsKey) ?? []
        guard !stored.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: stored)
    }

    func resetScheduledRequests() {
        clearLegacyRequests()
        clearStoredRequests()
    }

    func pendingRequestIdentifiers(prefixes: [String]) async -> [String] {
        let requests = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
        return requests.map(\.identifier).filter { id in
            prefixes.contains(where: { prefix in id.hasPrefix(prefix) })
        }
    }

    func saveScheduled(ids: [String], dayKey: String) {
        defaults.set(ids, forKey: scheduledRequestIdsKey)
        defaults.set(dayKey, forKey: lastScheduledDayKeyKey)
    }

    var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
