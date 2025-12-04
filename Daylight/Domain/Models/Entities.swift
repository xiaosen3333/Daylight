import Foundation

enum LightStatus: String, Codable {
    case on = "ON"
    case off = "OFF"
}

struct User: Codable, Identifiable, Equatable {
    static let schemaVersion: Int = 1

    let id: String
    let deviceId: String
    let createdAt: Date
    var lastActiveAt: Date
    var email: String?
    var phone: String?
    var appleId: String?
    var locale: String?
    var timezone: String?
    var nickname: String?
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

    enum CodingKeys: String, CodingKey {
        case userId
        case dayReminderTime
        case nightReminderStart
        case nightReminderEnd
        case nightReminderInterval
        case nightReminderEnabled
        case showCommitmentInNotification
        case version
    }

    let userId: String
    var dayReminderTime: String
    var nightReminderStart: String
    var nightReminderEnd: String
    var nightReminderInterval: Int
    var nightReminderEnabled: Bool
    var version: Int

    // Default init for new instances
    init(userId: String,
         dayReminderTime: String,
         nightReminderStart: String,
         nightReminderEnd: String,
         nightReminderInterval: Int,
         nightReminderEnabled: Bool,
         showCommitmentInNotification: Bool = true,
         version: Int) {
        self.userId = userId
        self.dayReminderTime = dayReminderTime
        self.nightReminderStart = nightReminderStart
        self.nightReminderEnd = nightReminderEnd
        self.nightReminderInterval = nightReminderInterval
        self.nightReminderEnabled = nightReminderEnabled
        self.showCommitmentInNotification = showCommitmentInNotification
        self.version = version
    }

    // Custom decoding to provide default for new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        dayReminderTime = try container.decode(String.self, forKey: .dayReminderTime)
        nightReminderStart = try container.decode(String.self, forKey: .nightReminderStart)
        nightReminderEnd = try container.decode(String.self, forKey: .nightReminderEnd)
        nightReminderInterval = try container.decode(Int.self, forKey: .nightReminderInterval)
        nightReminderEnabled = try container.decode(Bool.self, forKey: .nightReminderEnabled)
        showCommitmentInNotification = try container.decodeIfPresent(Bool.self, forKey: .showCommitmentInNotification) ?? true
        version = try container.decode(Int.self, forKey: .version)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(dayReminderTime, forKey: .dayReminderTime)
        try container.encode(nightReminderStart, forKey: .nightReminderStart)
        try container.encode(nightReminderEnd, forKey: .nightReminderEnd)
        try container.encode(nightReminderInterval, forKey: .nightReminderInterval)
        try container.encode(nightReminderEnabled, forKey: .nightReminderEnabled)
        try container.encode(showCommitmentInNotification, forKey: .showCommitmentInNotification)
        try container.encode(version, forKey: .version)
    }

    var showCommitmentInNotification: Bool = true
}
