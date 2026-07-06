import Testing
import Foundation
@testable import CaldogKit

struct MonthGridTests {
    @Test func gridAlwaysSixWeeksOfSeven() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 15), calendar: cal, today: Fixtures.date(cal, 2026, 6, 15))
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.count == 7 })
        #expect(grid.allDays.count == 42)
    }

    @Test func rollingWeeksStartOnFirstWeekdayAndContainAnchor() {
        let cal = Fixtures.calendar(firstWeekday: 1)
        let anchor = Fixtures.date(cal, 2026, 7, 3) // 금요일
        let grid = MonthGrid.makeWeeks(containing: anchor, weekCount: 3, calendar: cal, today: anchor)
        #expect(grid.weeks.count == 3)
        #expect(grid.allDays.count == 21)
        #expect(cal.component(.weekday, from: grid.weeks[0][0].date) == 1)   // 일요일 시작
        #expect(grid.weeks[0].contains { cal.isDate($0.date, inSameDayAs: anchor) })
        #expect(grid.allDays.allSatisfy { $0.isInMonth })
        #expect(grid.allDays.filter { $0.isToday }.count == 1)
    }

    @Test func rollingWeeksIntervalCoversAllCells() {
        let cal = Fixtures.calendar(firstWeekday: 2)
        let anchor = Fixtures.date(cal, 2026, 7, 3)
        let grid = MonthGrid.makeWeeks(containing: anchor, weekCount: 3, calendar: cal, today: anchor)
        #expect(cal.component(.weekday, from: grid.weeks[0][0].date) == 2)   // 월요일 시작
        #expect(grid.dateInterval.contains(grid.allDays.last!.date))
    }

    @Test func monthStartIsFirstOfMonth() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 15), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        #expect(cal.component(.day, from: grid.monthStart) == 1)
        #expect(cal.component(.month, from: grid.monthStart) == 6)
    }

    @Test func firstCellMatchesFirstWeekdaySunday() {
        let cal = Fixtures.calendar(firstWeekday: 1)
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 15), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        #expect(cal.component(.weekday, from: grid.weeks[0][0].date) == 1)
    }

    @Test func firstCellMatchesFirstWeekdayMonday() {
        let cal = Fixtures.calendar(firstWeekday: 2)
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 15), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        #expect(cal.component(.weekday, from: grid.weeks[0][0].date) == 2)
    }

    @Test func inMonthCountJune() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 10), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        #expect(grid.allDays.filter { $0.isInMonth }.count == 30)
    }

    @Test func inMonthCountNonLeapFebruary() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 2, 10), calendar: cal, today: Fixtures.date(cal, 2026, 2, 1))
        #expect(grid.allDays.filter { $0.isInMonth }.count == 28)
    }

    @Test func inMonthCountLeapFebruary() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2028, 2, 10), calendar: cal, today: Fixtures.date(cal, 2028, 2, 1))
        #expect(grid.allDays.filter { $0.isInMonth }.count == 29)
    }

    @Test func todayFlaggedExactlyOnceWhenInMonth() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 10), calendar: cal, today: Fixtures.date(cal, 2026, 6, 15))
        let todays = grid.allDays.filter { $0.isToday }
        #expect(todays.count == 1)
        #expect(cal.component(.day, from: todays[0].date) == 15)
    }

    @Test func leadingDaysBelongToPreviousMonth() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 10), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        guard let monthStartIndex = grid.allDays.firstIndex(where: { cal.isDate($0.date, inSameDayAs: grid.monthStart) }) else {
            Issue.record("month start not found in grid")
            return
        }
        for i in 0..<monthStartIndex {
            #expect(grid.allDays[i].isInMonth == false)
        }
    }

    @Test func dateIntervalCoversMonth() {
        let cal = Fixtures.calendar()
        let grid = MonthGrid.make(for: Fixtures.date(cal, 2026, 6, 10), calendar: cal, today: Fixtures.date(cal, 2026, 6, 1))
        let interval = grid.dateInterval
        #expect(interval.start <= grid.monthStart)
        let lastDayOfMonth = Fixtures.date(cal, 2026, 6, 30, 23, 0)
        #expect(interval.end > lastDayOfMonth)
    }

    @Test func weekdaySymbolsRotateWithFirstWeekday() {
        let calSun = Fixtures.calendar(firstWeekday: 1)
        let calMon = Fixtures.calendar(firstWeekday: 2)
        let sun = MonthGrid.weekdaySymbols(calendar: calSun)
        let mon = MonthGrid.weekdaySymbols(calendar: calMon)
        #expect(sun.count == 7)
        #expect(mon.count == 7)
        // 월요일 시작이면 첫 요일이 일요일 시작의 두 번째 요일과 같아야 함.
        #expect(mon[0] == sun[1])
    }
}
