import Foundation

actor SyncReplayer {
    enum ReplayReason {
        case appLaunch
        case foreground
        case networkBack
        case manual
    }

    struct Snapshot {
        let pendingItems: [PendingSyncItem]
        let nextRetryAt: Date?
    }

    private struct PartitionResult {
        var updated: [PendingSyncItem]
        var nextRetry: Date?
        var readyDayRecords: [PendingSyncItem]
        var readySettings: [PendingSyncItem]
    }

    private let pending: PendingSyncLocalDataSource
    private let remote: RemoteAPIStub?

    init(pending: PendingSyncLocalDataSource, remote: RemoteAPIStub?) {
        self.pending = pending
        self.remote = remote
    }

    func replay(reason: ReplayReason, force: Bool = false, types: Set<PendingSyncItem.ItemType>? = nil) async -> Snapshot {
        guard let remote = remote else {
            return await snapshot(types: types)
        }

        let items = (try? await pending.loadAll()) ?? []
        guard !items.isEmpty else {
            return Snapshot(pendingItems: [], nextRetryAt: nil)
        }

        let now = Date()
        let forceReplay = force || reason == .manual
        var partition = partitionItems(items,
                                       allowedTypes: types,
                                       forceReplay: forceReplay,
                                       now: now)

        if !partition.readyDayRecords.isEmpty {
            await processDayRecords(partition.readyDayRecords,
                                    now: now,
                                    updated: &partition.updated,
                                    nextRetry: &partition.nextRetry,
                                    remote: remote)
        }

        if !partition.readySettings.isEmpty {
            await processSettings(partition.readySettings,
                                  now: now,
                                  updated: &partition.updated,
                                  nextRetry: &partition.nextRetry,
                                  remote: remote)
        }

        try? await pending.saveAll(partition.updated)
        let settingsNext = partition.updated.first(where: { $0.type == .settings }).flatMap { Self.nextRetryDate(for: $0, now: now) }
        return Snapshot(pendingItems: partition.updated, nextRetryAt: settingsNext ?? partition.nextRetry)
    }

    func snapshot(types: Set<PendingSyncItem.ItemType>? = nil, now: Date = Date()) async -> Snapshot {
        let items = (try? await pending.loadAll()) ?? []
        let filtered: [PendingSyncItem]
        if let types {
            filtered = items.filter { types.contains($0.type) }
        } else {
            filtered = items
        }
        let next = filtered.compactMap { Self.nextRetryDate(for: $0, now: now) }.min()
        return Snapshot(pendingItems: filtered, nextRetryAt: next)
    }

    static func backoffSeconds(for retryCount: Int) -> TimeInterval {
        let exponent = max(retryCount, 0)
        let seconds = pow(2.0, Double(exponent)) * 5.0
        return min(seconds, 600)
    }

    static func nextRetryDate(for item: PendingSyncItem, now: Date = Date()) -> Date? {
        guard let last = item.lastTryAt else { return now }
        let delay = backoffSeconds(for: item.retryCount)
        return last.addingTimeInterval(delay)
    }

    private static func isReadyToRetry(_ item: PendingSyncItem, now: Date) -> Bool {
        guard let next = nextRetryDate(for: item, now: now) else { return true }
        return now >= next
    }

    private static func earliest(_ current: Date?, candidate: Date?) -> Date? {
        guard let candidate else { return current }
        guard let current else { return candidate }
        return min(current, candidate)
    }

    private func partitionItems(_ items: [PendingSyncItem],
                                allowedTypes: Set<PendingSyncItem.ItemType>?,
                                forceReplay: Bool,
                                now: Date) -> PartitionResult {
        var updated: [PendingSyncItem] = []
        var nextRetry: Date?
        var readyDayRecords: [PendingSyncItem] = []
        var readySettings: [PendingSyncItem] = []

        for item in items {
            if let allowedTypes, !allowedTypes.contains(item.type) {
                updated.append(item)
                continue
            }

            let ready = forceReplay || Self.isReadyToRetry(item, now: now)
            if !ready {
                nextRetry = Self.earliest(nextRetry, candidate: Self.nextRetryDate(for: item, now: now))
                updated.append(item)
                continue
            }

            switch item.payload {
            case .dayRecord:
                readyDayRecords.append(item)
            case .settings:
                readySettings.append(item)
            }
        }

        return PartitionResult(updated: updated,
                               nextRetry: nextRetry,
                               readyDayRecords: readyDayRecords,
                               readySettings: readySettings)
    }

    private func processDayRecords(_ items: [PendingSyncItem],
                                   now: Date,
                                   updated: inout [PendingSyncItem],
                                   nextRetry: inout Date?,
                                   remote: RemoteAPIStub) async {
        do {
            let records = items.compactMap { item -> DayRecord? in
                if case .dayRecord(let record) = item.payload {
                    return record
                }
                return nil
            }
            _ = try await remote.upload(records: records)
        } catch {
            for var item in items {
                item.retryCount += 1
                item.lastTryAt = now
                nextRetry = Self.earliest(nextRetry, candidate: Self.nextRetryDate(for: item, now: now))
                updated.append(item)
            }
        }
    }

    private func processSettings(_ items: [PendingSyncItem],
                                 now: Date,
                                 updated: inout [PendingSyncItem],
                                 nextRetry: inout Date?,
                                 remote: RemoteAPIStub) async {
        for var item in items {
            do {
                if case .settings(let settings) = item.payload {
                    try await remote.upload(settings: settings)
                }
            } catch {
                item.retryCount += 1
                item.lastTryAt = now
                nextRetry = Self.earliest(nextRetry, candidate: Self.nextRetryDate(for: item, now: now))
                updated.append(item)
            }
        }
    }
}
