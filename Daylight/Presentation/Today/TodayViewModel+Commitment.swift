import Foundation

// MARK: - Commitment & Suggestions
extension TodayViewModel {
    func applySuggestedReason(_ text: String) {
        commitmentText = text
    }

    func setupSuggestions(initialText: String) {
        suggestionsVisible = suggestionsProvider.setupSuggestions(initialText: initialText)
    }

    func pickSuggestion(at index: Int) {
        guard let result = suggestionsProvider.pickSuggestion(at: index,
                                                              slots: suggestionsVisible,
                                                              currentInput: commitmentText) else { return }
        applySuggestedReason(result.0)
        suggestionsVisible = result.1
    }

    func onTextChanged(_ text: String) {
        suggestionsVisible = suggestionsProvider.onTextChanged(text,
                                                               slots: suggestionsVisible,
                                                               currentInput: commitmentText)
    }

    func submitCommitment() async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        state.isSavingCommitment = true
        state.errorMessage = nil
        do {
            let record = try await useCases.setDayCommitment.execute(userId: user.id, settings: settings, text: commitmentText)
            state.record = record
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
            await checkNotificationPermissionAfterCommit()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingCommitment = false
    }

    func confirmSleepNow(allowEarly: Bool = false, dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.isSavingNight = true
        state.errorMessage = nil
        do {
            let record = try await useCases.confirmSleep.execute(userId: user.id,
                                                                 settings: settings,
                                                                 allowEarly: allowEarly,
                                                                 dayKey: targetDayKey,
                                                                 now: now)
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingNight = false
    }

    func undoSleepNow(dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.isSavingNight = true
        state.errorMessage = nil
        do {
            let result = try await useCases.undoSleep.execute(userId: user.id,
                                                              settings: settings,
                                                              dayKey: targetDayKey,
                                                              now: now)
            let record = result.record
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            if result.timeline.phase == .early || result.timeline.phase == .inWindow {
                await scheduleNotifications()
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
        state.isSavingNight = false
    }

    func rejectNightOnce(dayKey: String? = nil) async {
        if shouldBlockForTimeChange() { return }
        guard let user = user, let settings = state.settings else { return }
        let targetDayKey = dayKey ?? nightDayKey ?? state.record?.date ?? todayKey()
        let now = Date()
        state.errorMessage = nil
        state.isSavingNight = true
        defer { state.isSavingNight = false }
        do {
            let record = try await useCases.rejectNight.execute(userId: user.id,
                                                                settings: settings,
                                                                dayKey: targetDayKey,
                                                                now: now)
            if state.record == nil || state.record?.date == record.date {
                state.record = record
            }
            try await refreshLightChain()
            try await refreshStreak()
            await scheduleNotifications()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
