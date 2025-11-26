import Foundation

actor PendingSyncLocalDataSource {
    private let storage: FileStorage
    private let filename = "pending_ops.json"
    private let maxItems = 200

    init(storage: FileStorage = FileStorage()) {
        self.storage = storage
    }

    func loadAll() throws -> [PendingSyncItem] {
        let wrapper: PersistedList<PendingSyncItem>? = try storage.read(PersistedList<PendingSyncItem>.self, from: filename)
        return wrapper?.items ?? []
    }

    func enqueue(_ item: PendingSyncItem) throws {
        var items = try loadAll()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = merge(existing: items[index], incoming: item)
        } else {
            items.append(item)
        }
        items = trimmed(items)
        try persist(items)
    }

    func remove(id: String) throws {
        var items = try loadAll()
        items.removeAll { $0.id == id }
        try persist(items)
    }

    func remove(ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        var items = try loadAll()
        items.removeAll { ids.contains($0.id) }
        try persist(items)
    }

    func saveAll(_ items: [PendingSyncItem]) throws {
        let unique = Array(Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }).values)
        try persist(trimmed(unique))
    }

    private func merge(existing: PendingSyncItem, incoming: PendingSyncItem) -> PendingSyncItem {
        var merged = incoming
        merged.retryCount = max(existing.retryCount, incoming.retryCount)
        merged.lastTryAt = incoming.lastTryAt ?? existing.lastTryAt
        return merged
    }

    private func trimmed(_ items: [PendingSyncItem]) -> [PendingSyncItem] {
        guard items.count > maxItems else { return items }
        let sorted = items.sorted { ($0.lastTryAt ?? .distantPast) < ($1.lastTryAt ?? .distantPast) }
        return Array(sorted.suffix(maxItems))
    }

    private func persist(_ items: [PendingSyncItem]) throws {
        let wrapper = PersistedList(schemaVersion: 1, items: items)
        try storage.write(wrapper, to: filename)
    }
}
