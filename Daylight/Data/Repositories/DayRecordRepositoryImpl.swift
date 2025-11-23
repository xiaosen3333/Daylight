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

    func record(for localDate: String) async throws -> DayRecord? {
        let records = try await local.loadAll()
        return records.first(where: { $0.date == localDate })
    }

    func upsert(_ record: DayRecord) async throws {
        try await local.save(record: record)
        if let remote = remote {
            do {
                _ = try await remote.upload(records: [record])
                try await pending.remove(id: PendingSyncItem(type: .dayRecord, payload: record, retryCount: 0, lastTryAt: nil).id)
            } catch {
                let pendingItem = PendingSyncItem(type: .dayRecord,
                                                  payload: record,
                                                  retryCount: 0,
                                                  lastTryAt: Date())
                try await pending.enqueue(pendingItem)
                throw DomainError.syncFailure("网络不可用，已加入待同步队列")
            }
        } else {
            let pendingItem = PendingSyncItem(type: .dayRecord,
                                              payload: record,
                                              retryCount: 0,
                                              lastTryAt: Date())
            try await pending.enqueue(pendingItem)
        }
    }

    func records(in range: ClosedRange<String>) async throws -> [DayRecord] {
        let records = try await local.loadAll()
        return records
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .sorted { $0.date < $1.date }
    }

    func latestRecords(limit: Int) async throws -> [DayRecord] {
        let records = try await local.loadAll()
        return Array(records.sorted { $0.date > $1.date }.prefix(limit)).sorted { $0.date < $1.date }
    }
}
