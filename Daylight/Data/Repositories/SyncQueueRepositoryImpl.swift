import Foundation

final class SyncQueueRepositoryImpl: SyncQueueRepository {
    private let local: PendingSyncLocalDataSource

    init(local: PendingSyncLocalDataSource) {
        self.local = local
    }

    func enqueuePendingRecord(_ record: DayRecord) async {
        let item = PendingSyncItem(type: .dayRecord, payload: .dayRecord(record), retryCount: 0, lastTryAt: Date())
        try? await local.enqueue(item)
    }

    func pendingRecords() async -> [DayRecord] {
        guard let items = try? await local.loadAll() else { return [] }
        return items.compactMap {
            if case .dayRecord(let record) = $0.payload { return record }
            return nil
        }
    }

    func removePending(for id: String) async {
        try? await local.remove(id: id)
    }
}
