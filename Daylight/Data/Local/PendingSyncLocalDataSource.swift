import Foundation

actor PendingSyncLocalDataSource {
    private let storage: FileStorage
    private let filename = "pending_ops.json"

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
            items[index] = item
        } else {
            items.append(item)
        }
        let wrapper = PersistedList(schemaVersion: 1, items: items)
        try storage.write(wrapper, to: filename)
    }

    func remove(id: String) throws {
        var items = try loadAll()
        items.removeAll { $0.id == id }
        let wrapper = PersistedList(schemaVersion: 1, items: items)
        try storage.write(wrapper, to: filename)
    }
}
