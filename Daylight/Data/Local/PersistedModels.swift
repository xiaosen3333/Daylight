import Foundation

struct PersistedList<T: Codable>: Codable {
    let schemaVersion: Int
    var items: [T]
}

struct PendingSyncItem: Codable, Identifiable {
    enum ItemType: String, Codable {
        case dayRecord
        case settings
    }

    enum Payload: Equatable {
        case dayRecord(DayRecord)
        case settings(Settings)
    }

    let type: ItemType
    var payload: Payload
    var retryCount: Int
    var lastTryAt: Date?

    var payloadId: String {
        switch payload {
        case .dayRecord(let record):
            return record.id
        case .settings(let settings):
            return settings.userId
        }
    }

    var id: String { "\(type.rawValue)-\(payloadId)" }

    init(type: ItemType, payload: Payload, retryCount: Int, lastTryAt: Date?) {
        self.type = type
        self.payload = payload
        self.retryCount = retryCount
        self.lastTryAt = lastTryAt
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case type
        case payload
        case retryCount
        case lastTryAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ItemType.self, forKey: .type)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        lastTryAt = try container.decodeIfPresent(Date.self, forKey: .lastTryAt)

        switch type {
        case .dayRecord:
            let record = try container.decode(DayRecord.self, forKey: .payload)
            payload = .dayRecord(record)
        case .settings:
            let settings = try container.decode(Settings.self, forKey: .payload)
            payload = .settings(settings)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(lastTryAt, forKey: .lastTryAt)
        switch payload {
        case .dayRecord(let record):
            try container.encode(record, forKey: .payload)
        case .settings(let settings):
            try container.encode(settings, forKey: .payload)
        }
    }
}
