import Foundation

protocol DataMigrating {
    func migrate(from version: Int, data: Data) throws -> Data
}

struct NoOpDataMigrator: DataMigrating {
    func migrate(from version: Int, data: Data) throws -> Data {
        data
    }
}
