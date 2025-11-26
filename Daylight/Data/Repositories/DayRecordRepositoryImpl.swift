import Foundation

final class DayRecordRepositoryImpl: DayRecordRepository {
    private let local: DayRecordLocalDataSource
    private let pending: PendingSyncLocalDataSource
    private let remote: RemoteAPIStub?

    init(local: DayRecordLocalDataSource,
         pending: PendingSyncLocalDataSource,
         remote: RemoteAPIStub?) {
        self.local = local
        self.pending = pending
        self.remote = remote
    }

    func record(for localDate: String, userId: String) async throws -> DayRecord? {
        let records = try await local.loadAll(for: userId)
        return records.first(where: { $0.date == localDate })
    }

    func upsert(_ record: DayRecord, userId: String) async throws {
        guard record.userId == userId else {
            throw DomainError.invalidInput("用户不匹配，写入被拒绝")
        }

        try await local.save(record: record, for: userId)
        if let remote = remote {
            let pendingId = PendingSyncItem(type: .dayRecord, payload: .dayRecord(record), retryCount: 0, lastTryAt: nil).id
            do {
                _ = try await remote.upload(records: [record])
                try await pending.remove(id: pendingId)
            } catch {
                let existing = try? await pending.loadAll().first(where: { $0.id == pendingId })
                let retryCount = (existing?.retryCount ?? -1) + 1
                let pendingItem = PendingSyncItem(type: .dayRecord,
                                                  payload: .dayRecord(record),
                                                  retryCount: retryCount,
                                                  lastTryAt: Date())
                try await pending.enqueue(pendingItem)
                throw DomainError.syncFailure("网络不可用，已加入待同步队列")
            }
        } else {
            let pendingItem = PendingSyncItem(type: .dayRecord,
                                              payload: .dayRecord(record),
                                              retryCount: 0,
                                              lastTryAt: nil)
            try await pending.enqueue(pendingItem)
        }
    }

    func records(in range: ClosedRange<String>, userId: String) async throws -> [DayRecord] {
        let records = try await local.loadAll(for: userId)
        return records
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .sorted { $0.date < $1.date }
    }

    func latestRecords(limit: Int, userId: String) async throws -> [DayRecord] {
        let records = try await local.loadAll(for: userId)
        return Array(records.sorted { $0.date > $1.date }.prefix(limit)).sorted { $0.date < $1.date }
    }
}
