import Testing
import Foundation
@testable import CaldogKit

@Suite("EventLayout")
struct EventLayoutTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("같은 날 시간 일정은 시작일 1칸")
    func sameDayTimed() {
        let days = EventLayout.coveredDays(start: date(2026, 6, 23, 14), end: date(2026, 6, 23, 15), calendar: calendar)
        #expect(days == [date(2026, 6, 23)])
    }

    @Test("22:00~익일 00:00(자정 종료)은 시작일만 — 배타적 종료")
    func midnightExclusiveEnd() {
        let days = EventLayout.coveredDays(start: date(2026, 6, 23, 22), end: date(2026, 6, 24, 0), calendar: calendar)
        #expect(days == [date(2026, 6, 23)])
    }

    @Test("자정을 넘겨 끝나는 시간 일정은 두 날 점유")
    func crossesMidnight() {
        let days = EventLayout.coveredDays(start: date(2026, 6, 23, 22), end: date(2026, 6, 24, 1), calendar: calendar)
        #expect(days == [date(2026, 6, 23), date(2026, 6, 24)])
    }

    @Test("3일짜리 종일 일정(end=다음날 자정)은 3일 모두 점유")
    func multiDayAllDay() {
        // 종일 일정은 보통 end가 마지막날+1의 자정.
        let days = EventLayout.coveredDays(start: date(2026, 6, 4), end: date(2026, 6, 7), calendar: calendar)
        #expect(days == [date(2026, 6, 4), date(2026, 6, 5), date(2026, 6, 6)])
    }

    @Test("0 길이 일정도 시작일 1칸 보장")
    func zeroDuration() {
        let days = EventLayout.coveredDays(start: date(2026, 6, 23, 9), end: date(2026, 6, 23, 9), calendar: calendar)
        #expect(days == [date(2026, 6, 23)])
    }

    @Test("range로 그리드 밖 날짜는 잘라냄")
    func clampToRange() {
        // 5/30~6/2 일정이지만 그리드는 6/1부터.
        let range = DateInterval(start: date(2026, 6, 1), end: date(2026, 7, 6))
        let days = EventLayout.coveredDays(start: date(2026, 5, 30), end: date(2026, 6, 3),
                                           calendar: calendar, clampedTo: range)
        #expect(days == [date(2026, 6, 1), date(2026, 6, 2)])
    }
}
