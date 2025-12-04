import Foundation

final class LoadMonthRecordsUseCase {
    private let dayRecordRepository: DayRecordRepository
    private let dateHelper: DaylightDateHelper

    init(dayRecordRepository: DayRecordRepository, dateHelper: DaylightDateHelper) {
        self.dayRecordRepository = dayRecordRepository
        self.dateHelper = dateHelper
    }

    func execute(userId: String, month: Date, settings: Settings) async throws -> [DayRecord] {
        var calendar = dateHelper.calendar
        calendar.timeZone = dateHelper.timeZone

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month),
              let endOfMonth = calendar.date(byAdding: DateComponents(day: range.count - 1), to: startOfMonth) else {
            return []
        }

        let startString = dateHelper.dayFormatter.string(from: startOfMonth)
        let endString = dateHelper.dayFormatter.string(from: endOfMonth)
        let recordsInRange = try await dayRecordRepository.records(in: startString...endString, userId: userId)
        let recordMap = Dictionary(uniqueKeysWithValues: recordsInRange.map { ($0.date, $0) })

        var results: [DayRecord] = []
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let key = dateHelper.dayFormatter.string(from: date)
                if let record = recordMap[key] {
                    results.append(record)
                } else {
                    results.append(DayRecord.defaultRecord(for: userId, date: key))
                }
            }
        }
        return results
    }
}
