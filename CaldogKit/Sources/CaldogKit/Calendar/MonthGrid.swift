import Foundation

/// 월 캘린더 그리드(항상 6주 × 7일 = 42칸)를 계산하는 순수 값 타입.
///
/// 앱 월 뷰와 위젯이 공유한다. 주 시작 요일은 전달된 `Calendar.firstWeekday`를 따른다.
public struct MonthGrid: Equatable, Sendable {
    /// 그리드의 한 칸.
    public struct Day: Equatable, Hashable, Sendable, Identifiable {
        public let date: Date          // 해당 날짜의 자정(전달 calendar 기준)
        public let isInMonth: Bool     // 대상 월에 속하는지(앞/뒤 채움 칸 구분)
        public let isToday: Bool
        public var id: Date { date }

        public init(date: Date, isInMonth: Bool, isToday: Bool) {
            self.date = date
            self.isInMonth = isInMonth
            self.isToday = isToday
        }
    }

    /// 대상 월의 1일 자정.
    public let monthStart: Date
    /// 6주 × 7일.
    public let weeks: [[Day]]

    /// 그리드의 첫 칸(앞 채움 포함) ~ 마지막 칸을 포함하는 기간. 이벤트 조회 범위로 사용.
    public var dateInterval: DateInterval {
        let first = weeks.first!.first!.date
        let lastDay = weeks.last!.last!.date
        // 마지막 칸의 다음 자정까지 포함.
        let end = lastDay.addingTimeInterval(24 * 3600)
        return DateInterval(start: first, end: end)
    }

    public var allDays: [Day] { weeks.flatMap { $0 } }

    /// 주어진 기준 날짜가 속한 달의 그리드를 만든다.
    /// - Parameters:
    ///   - date: 표시할 달 안의 임의 날짜.
    ///   - calendar: 사용할 달력(`firstWeekday`, `timeZone` 반영).
    ///   - today: "오늘" 강조 기준(기본은 `date`).
    public static func make(for date: Date, calendar: Calendar, today: Date) -> MonthGrid {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let monthStart = calendar.date(from: comps) ?? calendar.startOfDay(for: date)

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart) // 1...7
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart

        var days: [Day] = []
        days.reserveCapacity(42)
        for offset in 0..<42 {
            let dayDate = calendar.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart
            let inMonth = calendar.isDate(dayDate, equalTo: monthStart, toGranularity: .month)
            let isToday = calendar.isDate(dayDate, inSameDayAs: today)
            days.append(Day(date: dayDate, isInMonth: inMonth, isToday: isToday))
        }

        let weeks = stride(from: 0, to: 42, by: 7).map { Array(days[$0..<$0 + 7]) }
        return MonthGrid(monthStart: monthStart, weeks: weeks)
    }

    /// 전달된 달력 기준 요일 머리글(예: 일, 월, ...). `firstWeekday`부터 정렬.
    public static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols // index 0 = Sunday
        let start = calendar.firstWeekday - 1       // 0-based
        return (0..<7).map { symbols[(start + $0) % 7] }
    }
}
