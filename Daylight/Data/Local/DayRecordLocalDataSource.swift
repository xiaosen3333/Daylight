import Foundation

actor DayRecordLocalDataSource {
    private let storage: FileStorage
    private let migrator: DataMigrating
    private let filename = "day_records.json"

    init(storage: FileStorage = FileStorage(), migrator: DataMigrating = NoOpDataMigrator()) {
        self.storage = storage
        self.migrator = migrator
    }

    private func loadAll() throws -> [DayRecord] {
        let wrapper: PersistedList<DayRecord>? = try storage.readPersistedList(PersistedList<DayRecord>.self,
                                                                              expectedVersion: DayRecord.schemaVersion,
                                                                              from: filename,
                                                                              migrator: migrator)
        return wrapper?.items ?? []
    }

    func loadAll(for userId: String) throws -> [DayRecord] {
        try loadAll().filter { $0.userId == userId }
    }

    func save(record: DayRecord, for userId: String) throws {
        guard record.userId == userId else {
            throw DayRecordLocalDataSourceError.mismatchedUserId
        }

        try persist(records: [record])
    }

    func save(records newRecords: [DayRecord], for userId: String) throws {
        guard newRecords.allSatisfy({ $0.userId == userId }) else {
            throw DayRecordLocalDataSourceError.mismatchedUserId
        }

        try persist(records: newRecords)
    }

    private func persist(records newRecords: [DayRecord]) throws {
        var records = try loadAll()
        for record in newRecords {
            if let index = records.firstIndex(where: { $0.userId == record.userId && $0.date == record.date }) {
                if records[index].updatedAt <= record.updatedAt {
                    records[index] = record
                }
            } else {
                records.append(record)
            }
        }
        records.sort { $0.date < $1.date }
        let payload = PersistedList(schemaVersion: DayRecord.schemaVersion, items: records)
        try storage.write(payload, to: filename)
    }
}

enum DayRecordLocalDataSourceError: Error, LocalizedError {
    case mismatchedUserId

    var errorDescription: String? {
        switch self {
        case .mismatchedUserId:
            return "记录的用户与操作用户不一致"
        }
    }
}
