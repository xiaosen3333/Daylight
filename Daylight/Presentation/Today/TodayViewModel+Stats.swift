import Foundation

// MARK: - Summary & Stats
extension TodayViewModel {
    /// 按夜窗重新归一化当月记录，必要时填充当天默认记录，避免 UI 重复实现。
    func normalizedMonthRecords(todayKey: String) -> [DayRecord] {
        var map = Dictionary(uniqueKeysWithValues: monthRecords.map { ($0.date, $0) })
        if let settings = state.settings {
            let window = NightWindow(start: settings.nightReminderStart, end: settings.nightReminderEnd)
            for record in monthRecords {
                let recomputed = dateHelper.localDayString(for: record.updatedAt, nightWindow: window)
                if recomputed == todayKey && record.date != recomputed && map[todayKey] == nil {
                    map[recomputed] = DayRecord(
                        userId: record.userId,
                        date: recomputed,
                        commitmentText: record.commitmentText,
                        dayLightStatus: record.dayLightStatus,
                        nightLightStatus: record.nightLightStatus,
                        sleepConfirmedAt: record.sleepConfirmedAt,
                        nightRejectCount: record.nightRejectCount,
                        updatedAt: record.updatedAt,
                        version: record.version
                    )
                }
            }
        }
        if map[todayKey] == nil {
            map[todayKey] = DayRecord.defaultRecord(for: currentUserId ?? "", date: todayKey)
        }
        return map.values.sorted { $0.date < $1.date }
    }

    func nextDayKey(from dayKey: String, settings: Settings) -> String? {
        guard let dayDate = dateHelper.dayFormatter.date(from: dayKey) else { return nil }
        return dateHelper.calendar.date(byAdding: .day, value: 1, to: dayDate).map { dateHelper.dayFormatter.string(from: $0) }
    }

    func formattedCommitmentPreview(maxLength: Int = 32) -> String {
        guard let text = state.record?.commitmentText else { return "还没有承诺哦" }
        if text.count <= maxLength { return text }
        let prefix = text.prefix(maxLength)
        return "\(prefix)…"
    }

    func refreshLightChain() async throws {
        guard let user = user, let settings = state.settings else { return }
        let records = try await statsLoader.loadLightChain(userId: user.id, settings: settings)
        lightChain = records
    }

    func refreshStreak() async throws {
        guard let user = user, let settings = state.settings else { return }
        state.streak = try await statsLoader.loadStreak(userId: user.id, settings: settings)
    }

    func scheduleNotifications() async {
        guard let settings = state.settings else { return }
        let effectiveDayKey = todayKey()
        let nextKey = nextDayKey(from: effectiveDayKey, settings: settings)
        let input = NotificationPlanInput(settings: settings,
                                          record: state.record,
                                          user: user,
                                          effectiveDayKey: effectiveDayKey,
                                          nextDayKeyOverride: nextKey)
        await notificationCoordinator.scheduleNotifications(input: input)
        lastDayKey = effectiveDayKey
    }

    func nightWindowChanged(from old: Settings, to new: Settings) -> Bool {
        old.nightReminderStart != new.nightReminderStart ||
        old.nightReminderEnd != new.nightReminderEnd ||
        old.nightReminderInterval != new.nightReminderInterval
    }

    func forceRescheduleTonight(settings: Settings, timeline: NightTimeline, now: Date) async {
        let dayKey = timeline.dayKey
        let input = NotificationPlanInput(settings: settings,
                                          record: state.record,
                                          user: user,
                                          effectiveDayKey: dayKey,
                                          nextDayKeyOverride: nil)
        await notificationCoordinator.forceRescheduleTonight(input: input,
                                                             timeline: timeline,
                                                             now: now)
        lastDayKey = dayKey
    }

    func applySyncSnapshot(_ snapshot: SyncReplayer.Snapshot) {
        let pendingSettings = snapshot.pendingItems.first(where: { $0.type == .settings })
        if let pendingSettings {
            let nextRetry = SyncReplayer.nextRetryDate(for: pendingSettings)
            settingsSyncState = .pending(nextRetryAt: nextRetry)
        } else {
            settingsSyncState = .synced
        }
    }

    func refreshSettingsSyncState() async {
        let snapshot = await syncReplayer.snapshot(types: [.settings])
        applySyncSnapshot(snapshot)
    }

    func loadMonth(_ month: Date) async {
        guard let user = user, let settings = state.settings else { return }
        do {
            let records = try await statsLoader.loadMonth(userId: user.id, month: month, settings: settings)
            monthRecords = records
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    func checkNotificationPermissionAfterCommit() async {
        // 未授权时静默请求一次权限，不在界面弹窗提示
        await notificationCoordinator.checkNotificationPermissionAfterCommit()
    }
}
