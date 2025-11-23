import Foundation

actor DayRecordLocalDataSource {
    private let storage: FileStorage
    private let filename = "day_records.json"

    init(storage: FileStorage = FileStorage()) {
        self.storage = storage
    }

    func loadAll() throws -> [DayRecord] {
        let wrapper: PersistedList<DayRecord>? = try storage.read(PersistedList<DayRecord>.self, from: filename)
        return wrapper?.items ?? []
    }

    func save(record: DayRecord) throws {
        var records = try loadAll()
        if let existingIndex = records.firstIndex(where: { $0.date == record.date && $0.userId == record.userId }) {
            if records[existingIndex].updatedAt <= record.updatedAt {
                records[existingIndex] = record
            }
        } else {
            records.append(record)
        }

        records.sort { $0.date < $1.date }
        let payload = PersistedList(schemaVersion: DayRecord.schemaVersion, items: records)
        try storage.write(payload, to: filename)
    }

    func save(records newRecords: [DayRecord]) throws {
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
