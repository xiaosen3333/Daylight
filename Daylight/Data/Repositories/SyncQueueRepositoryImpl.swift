import Foundation

final class SyncQueueRepositoryImpl: SyncQueueRepository {
    private let local: PendingSyncLocalDataSource

    init(local: PendingSyncLocalDataSource) {
        self.local = local
    }

    func enqueuePendingRecord(_ record: DayRecord) async {
        let item = PendingSyncItem(type: .dayRecord, payload: record, retryCount: 0, lastTryAt: Date())
        try? await local.enqueue(item)
    }

    func pendingRecords() async -> [DayRecord] {
        guard let items = try? await local.loadAll() else { return [] }
        return items.map { $0.payload }
    }

    func removePending(for id: String) async {
        try? await local.remove(id: id)
    }
}
