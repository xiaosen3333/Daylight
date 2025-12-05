import SwiftUI

/// 集中管理灯链数据可视化组件，后续可直接复用到桌面小组件。
struct LightChainVisualizationGallery: View {
    let records: [DayRecord]
    let selectedRecord: DayRecord?
    let streak: StreakResult?
    let currentMonth: Date
    let userId: String
    let locale: Locale
    let timeZone: TimeZone
    let todayKey: String
    let onMonthChange: (Date) -> Void
    let onSelect: (DayRecord?) -> Void

    var body: some View {
        let recordToShow = selectedRecord
        ?? records.first(where: { $0.date == todayKey })
        ?? DayRecord.defaultRecord(for: userId, date: todayKey)
        LazyVStack(spacing: 14) {
            LightChainPrimaryCard(records: records, streak: streak)
            LightChainStreakCalendarCard(
                records: records,
                month: currentMonth,
                locale: locale,
                initialSelection: selectedRecord?.date ?? todayKey,
                onSelect: onSelect,
                onMonthChange: onMonthChange
            )
            DayRecordStatusCard(record: recordToShow, locale: locale, timeZone: timeZone, todayKey: todayKey)
        }
    }
}
