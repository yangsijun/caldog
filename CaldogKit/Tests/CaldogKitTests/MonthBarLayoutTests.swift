import Testing
import Foundation
@testable import CaldogKit

@Suite("MonthBarLayout")
struct MonthBarLayoutTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.firstWeekday = 1
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: title, title: title, start: start, end: end, isAllDay: allDay,
                      calendarID: "c", calendarColorHex: "#FF0000")
    }

    private func gridInterval(_ start: Date, _ endExclusive: Date) -> DateInterval {
        DateInterval(start: start, end: endExclusive)
    }

    @Test("겹치지 않는 두 일정은 같은 레인 0")
    func nonOverlappingShareLane() {
        let grid = gridInterval(day(2026, 7, 1), day(2026, 8, 9))
        let bars = MonthBarLayout.assignLanes(
            events: [event("A", day(2026, 7, 1, 9), day(2026, 7, 1, 10)),
                     event("B", day(2026, 7, 3, 9), day(2026, 7, 3, 10))],
            calendar: calendar, gridInterval: grid)
        #expect(bars.allSatisfy { $0.lane == 0 })
    }

    @Test("겹치는 두 일정은 다른 레인")
    func overlappingDifferentLanes() {
        let grid = gridInterval(day(2026, 7, 1), day(2026, 8, 9))
        let bars = MonthBarLayout.assignLanes(
            events: [event("A", day(2026, 7, 1), day(2026, 7, 5)),
                     event("B", day(2026, 7, 2), day(2026, 7, 3))],
            calendar: calendar, gridInterval: grid)
        let lanes = Set(bars.map(\.lane))
        #expect(lanes == [0, 1])
        // 더 긴 A가 먼저 정렬되어 레인 0.
        #expect(bars.first(where: { $0.eventID == "A" })?.lane == 0)
    }

    @Test("주 경계를 넘는 일정은 두 토막으로 분할되고 isStart/isEnd가 맞음")
    func splitsAcrossWeeks() {
        // 일~토 주. 7/3(금)~7/6(월) 종일 일정(end=7/7 자정).
        let grid = gridInterval(day(2026, 6, 28), day(2026, 8, 9))
        let bars = MonthBarLayout.assignLanes(
            events: [event("trip", day(2026, 7, 3), day(2026, 7, 7), allDay: true)],
            calendar: calendar, gridInterval: grid)

        // 첫 주: 6/28(일)~7/4(토)
        let week1 = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: day(2026, 6, 28))! }
        let seg1 = MonthBarLayout.segments(forWeek: week1, bars: bars, calendar: calendar)
        #expect(seg1.count == 1)
        #expect(seg1[0].startColumn == 5)      // 금요일
        #expect(seg1[0].columnSpan == 2)       // 금,토
        #expect(seg1[0].isStart == true)
        #expect(seg1[0].isEnd == false)

        // 둘째 주: 7/5(일)~7/11(토)
        let week2 = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: day(2026, 7, 5))! }
        let seg2 = MonthBarLayout.segments(forWeek: week2, bars: bars, calendar: calendar)
        #expect(seg2.count == 1)
        #expect(seg2[0].startColumn == 0)      // 일요일
        #expect(seg2[0].columnSpan == 2)       // 일,월(7/5,7/6)
        #expect(seg2[0].isStart == false)
        #expect(seg2[0].isEnd == true)
    }

    @Test("같은 날 일정은 제목이 아니라 시작 시각 순으로 레인 배치")
    func sameDayOrderedByStartTime() {
        let grid = gridInterval(day(2026, 7, 1), day(2026, 8, 9))
        // 제목 역순(Z가 이른 시각)으로 넣어 제목 정렬이면 실패하게 한다.
        let bars = MonthBarLayout.assignLanes(
            events: [event("A늦은일정", day(2026, 7, 2, 15), day(2026, 7, 2, 16)),
                     event("Z이른일정", day(2026, 7, 2, 9), day(2026, 7, 2, 10))],
            calendar: calendar, gridInterval: grid)
        #expect(bars.first(where: { $0.eventID == "Z이른일정" })?.lane == 0)
        #expect(bars.first(where: { $0.eventID == "A늦은일정" })?.lane == 1)
    }

    @Test("maxLanes 초과 일정은 overflow로 집계")
    func overflowCounting() {
        let grid = gridInterval(day(2026, 7, 1), day(2026, 8, 9))
        // 7/2에 겹치는 3개 → 레인 0,1,2.
        let bars = MonthBarLayout.assignLanes(
            events: [event("A", day(2026, 7, 2, 9), day(2026, 7, 2, 10)),
                     event("B", day(2026, 7, 2, 9), day(2026, 7, 2, 10)),
                     event("C", day(2026, 7, 2, 9), day(2026, 7, 2, 10))],
            calendar: calendar, gridInterval: grid)
        let week = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: day(2026, 6, 28))! }
        let counts = MonthBarLayout.overflowCounts(forWeek: week, bars: bars, maxLanes: 2, calendar: calendar)
        // 7/2 = 목요일(col 4)에 레인 2짜리 1개 숨김.
        #expect(counts[4] == 1)
    }
}
