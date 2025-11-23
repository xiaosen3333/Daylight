import Foundation

enum LightStatus: String, Codable {
    case on = "ON"
    case off = "OFF"
}

struct User: Codable, Identifiable, Equatable {
    let id: String
    let deviceId: String
    let createdAt: Date
    var lastActiveAt: Date
    var email: String?
    var phone: String?
    var appleId: String?
    var locale: String?
    var timezone: String?
}

struct Subscription: Codable, Equatable {
    enum Plan: String, Codable {
        case free
        case proMonthly = "pro_monthly"
        case proYearly = "pro_yearly"
    }

    enum Status: String, Codable {
        case active
        case expired
        case cancelled
    }

    let userId: String
    let plan: Plan
    let status: Status
    let startedAt: Date
    var expiredAt: Date?
}

enum EntitlementKey: String, Codable {
    case maxHistoryDays
    case advancedThemes
    case weeklyReport
}

struct Entitlement: Codable, Equatable {
    let key: EntitlementKey
    let value: EntitlementValue
}

enum EntitlementValue: Codable, Equatable {
    case number(Double)
    case boolean(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let num = try? container.decode(Double.self) {
            self = .number(num)
        } else if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
        } else {
            self = .string((try? container.decode(String.self)) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let number):
            try container.encode(number)
        case .boolean(let bool):
            try container.encode(bool)
        case .string(let string):
            try container.encode(string)
        }
    }
}

struct DayRecord: Codable, Identifiable, Equatable {
    static let schemaVersion: Int = 1

    var id: String { "\(userId)-\(date)" }

    let userId: String
    let date: String        // YYYY-MM-DD (local day window)
    var commitmentText: String?
    var dayLightStatus: LightStatus
    var nightLightStatus: LightStatus
    var sleepConfirmedAt: Date?
    var nightRejectCount: Int
    var updatedAt: Date
    var version: Int
}

struct Settings: Codable, Equatable {
    static let schemaVersion: Int = 1

    let userId: String
    var dayReminderTime: String
    var nightReminderStart: String
    var nightReminderEnd: String
    var nightReminderInterval: Int
    var nightReminderEnabled: Bool
    var version: Int
}
