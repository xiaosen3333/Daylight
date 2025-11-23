import Foundation

struct PersistedList<T: Codable>: Codable {
    let schemaVersion: Int
    var items: [T]
}

struct PendingSyncItem: Codable, Identifiable {
    enum ItemType: String, Codable {
        case dayRecord
    }

    var id: String { "\(type.rawValue)-\(payload.id)" }

    let type: ItemType
    var payload: DayRecord
    var retryCount: Int
    var lastTryAt: Date?
}
