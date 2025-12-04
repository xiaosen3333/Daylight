import Foundation

struct FileStorage {
    private let fileManager: FileManager
    private let directory: URL

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let custom = directory {
            self.directory = custom
        } else if let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.directory = dir
        } else {
            self.directory = fileManager.temporaryDirectory
        }
    }

    func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func read<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        let url = url(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = makeDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func readPersistedList<T: Codable>(_ type: PersistedList<T>.Type,
                                       expectedVersion: Int,
                                       from filename: String,
                                       migrator: DataMigrating = NoOpDataMigrator()) throws -> PersistedList<T>? {
        let url = url(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = makeDecoder()
        do {
            let wrapper = try decoder.decode(PersistedList<T>.self, from: data)
            guard wrapper.schemaVersion == expectedVersion else {
                let migratedData = try migrator.migrate(from: wrapper.schemaVersion, data: data)
                let migratedWrapper = try decoder.decode(PersistedList<T>.self, from: migratedData)
                guard migratedWrapper.schemaVersion == expectedVersion else {
                    print("[Storage] Schema mismatch for \(filename). expected: \(expectedVersion), got: \(migratedWrapper.schemaVersion)")
                    return nil
                }
                return migratedWrapper
            }
            return wrapper
        } catch {
            print("[Storage] Failed to decode \(filename): \(error)")
            return nil
        }
    }

    func write<T: Encodable>(_ value: T, to filename: String) throws {
        let url = url(for: filename)
        let encoder = makeEncoder()
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static var iso8601WithFractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = FileStorage.iso8601WithFractional.date(from: string) {
                return date
            }
            if let fallback = ISO8601DateFormatter().date(from: string) {
                return fallback
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析时间")
        }
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = FileStorage.iso8601WithFractional.string(from: date)
            try container.encode(string)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
