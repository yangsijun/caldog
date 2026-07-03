import Testing
import Foundation
@testable import CaldogKit

struct EventSearchTests {
    let cal = Fixtures.calendar()

    func sample() -> [CalendarEvent] {
        [
            CalendarEvent(id: "e1", title: "팀 회의", start: Fixtures.date(cal, 2026, 6, 1, 9),
                          end: Fixtures.date(cal, 2026, 6, 1, 10), isAllDay: false,
                          calendarID: "cal-work", calendarColorHex: "#E53935", location: "본사 3층"),
            CalendarEvent(id: "e2", title: "점심", start: Fixtures.date(cal, 2026, 6, 2, 12),
                          end: Fixtures.date(cal, 2026, 6, 2, 13), isAllDay: false,
                          calendarID: "cal-personal", calendarColorHex: "#1E88E5", notes: "회의실 옆 식당"),
            CalendarEvent(id: "e3", title: "운동", start: Fixtures.date(cal, 2026, 6, 3, 18),
                          end: Fixtures.date(cal, 2026, 6, 3, 19), isAllDay: false,
                          calendarID: "cal-personal", calendarColorHex: "#1E88E5"),
        ]
    }

    @Test func emptyKeywordReturnsAllSorted() {
        let result = EventSearch.filter(sample())
        #expect(result.map(\.id) == ["e1", "e2", "e3"])
    }

    @Test func keywordMatchesTitle() {
        #expect(EventSearch.filter(sample(), keyword: "운동").map(\.id) == ["e3"])
    }

    @Test func keywordMatchesLocationAndNotes() {
        // "회의"는 e1 제목 + e2 메모에 등장.
        #expect(Set(EventSearch.filter(sample(), keyword: "회의").map(\.id)) == ["e1", "e2"])
    }

    @Test func keywordCaseInsensitive() {
        var events = sample()
        events.append(CalendarEvent(id: "e4", title: "Standup", start: Fixtures.date(cal, 2026, 6, 4, 9),
                                    end: Fixtures.date(cal, 2026, 6, 4, 10), isAllDay: false,
                                    calendarID: "cal-work", calendarColorHex: "#E53935"))
        #expect(EventSearch.filter(events, keyword: "standup").map(\.id) == ["e4"])
    }

    @Test func calendarFilter() {
        #expect(EventSearch.filter(sample(), calendarIDs: ["cal-personal"]).map(\.id) == ["e2", "e3"])
    }

    @Test func allowedEventIDsFilter() {
        #expect(EventSearch.filter(sample(), allowedEventIDs: ["e1", "e3"]).map(\.id) == ["e1", "e3"])
    }

    @Test func combinedFilters() {
        let result = EventSearch.filter(sample(), keyword: "점심", calendarIDs: ["cal-personal"])
        #expect(result.map(\.id) == ["e2"])
    }
}

struct CalendarFactoryTests {
    @Test func setsFirstWeekday() {
        #expect(CalendarFactory.calendar(firstWeekday: 2).firstWeekday == 2)
    }

    @Test func clampsOutOfRange() {
        #expect(CalendarFactory.calendar(firstWeekday: 0).firstWeekday == 1)
        #expect(CalendarFactory.calendar(firstWeekday: 99).firstWeekday == 7)
    }
}

struct NotificationPlanTests {
    let cal = Fixtures.calendar()

    @Test func futureFireDateComputed() {
        let now = Fixtures.date(cal, 2026, 6, 1, 8)
        let start = Fixtures.date(cal, 2026, 6, 1, 9)
        let fire = NotificationPlan.fireDate(eventStart: start, minutesBefore: 30, now: now)
        #expect(fire == start.addingTimeInterval(-1800))
    }

    @Test func pastFireDateReturnsNil() {
        let now = Fixtures.date(cal, 2026, 6, 1, 8, 45)
        let start = Fixtures.date(cal, 2026, 6, 1, 9)
        // 30분 전 = 8:30, 이미 지남(now 8:45) → nil
        #expect(NotificationPlan.fireDate(eventStart: start, minutesBefore: 30, now: now) == nil)
    }
}
