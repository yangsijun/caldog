import Testing
import Foundation
import CoreGraphics
@testable import CaldogKit

struct MockEventStoreTests {
    let cal = Fixtures.calendar()

    func makeStore() -> MockEventStore {
        let day = Fixtures.date(cal, 2026, 6, 15, 9)
        let events = [
            CalendarEvent(id: "e1", title: "스탠드업", start: day, end: day.addingTimeInterval(1800),
                          isAllDay: false, calendarID: "cal-work", calendarColorHex: "#E53935"),
            CalendarEvent(id: "e2", title: "점심", start: Fixtures.date(cal, 2026, 6, 15, 12),
                          end: Fixtures.date(cal, 2026, 6, 15, 13), isAllDay: false,
                          calendarID: "cal-personal", calendarColorHex: "#1E88E5"),
            CalendarEvent(id: "e3", title: "다른날", start: Fixtures.date(cal, 2026, 6, 20, 10),
                          end: Fixtures.date(cal, 2026, 6, 20, 11), isAllDay: false,
                          calendarID: "cal-work", calendarColorHex: "#E53935"),
        ]
        return MockEventStore(events: events)
    }

    @Test func eventsOnDayFiltersByDate() throws {
        let store = makeStore()
        let day = try store.events(on: Fixtures.date(cal, 2026, 6, 15), calendar: cal)
        #expect(day.map(\.id) == ["e1", "e2"])
    }

    @Test func eventsFilterByCalendar() throws {
        let store = makeStore()
        let range = DateInterval(start: Fixtures.date(cal, 2026, 6, 1), end: Fixtures.date(cal, 2026, 7, 1))
        let workOnly = try store.events(in: range, calendarIDs: ["cal-work"])
        #expect(workOnly.map(\.id) == ["e1", "e3"])
    }

    @Test func saveCreatesAndReturnsIdentifier() throws {
        let store = makeStore()
        let draft = EventDraft(title: "신규", start: Fixtures.date(cal, 2026, 6, 16, 10),
                               end: Fixtures.date(cal, 2026, 6, 16, 11), calendarID: "cal-personal")
        let id = try store.save(draft, span: .thisEvent)
        #expect(!id.isEmpty)
        #expect(store.storedEvents.contains { $0.id == id && $0.title == "신규" })
    }

    @Test func saveUpdatesExisting() throws {
        let store = makeStore()
        var draft = EventDraft(existingIdentifier: "e1", title: "스탠드업(변경)",
                               start: Fixtures.date(cal, 2026, 6, 15, 9),
                               end: Fixtures.date(cal, 2026, 6, 15, 10), calendarID: "cal-work")
        draft.notes = "노트"
        let id = try store.save(draft, span: .thisEvent)
        #expect(id == "e1")
        let updated = store.storedEvents.first { $0.id == "e1" }
        #expect(updated?.title == "스탠드업(변경)")
        #expect(store.storedEvents.count == 3) // 갱신이므로 개수 유지
    }

    @Test func saveToImmutableCalendarThrows() {
        let store = makeStore()
        let draft = EventDraft(title: "공휴일추가", start: Fixtures.date(cal, 2026, 6, 17, 10),
                               end: Fixtures.date(cal, 2026, 6, 17, 11), calendarID: "cal-holidays")
        #expect(throws: EventStoreError.calendarIsImmutable) {
            try store.save(draft, span: .thisEvent)
        }
    }

    @Test func deleteRemovesEvent() throws {
        let store = makeStore()
        try store.delete(eventIdentifier: "e1", span: .thisEvent)
        #expect(!store.storedEvents.contains { $0.id == "e1" })
    }

    @Test func deleteMissingThrows() {
        let store = makeStore()
        #expect(throws: EventStoreError.eventNotFound) {
            try store.delete(eventIdentifier: "nope", span: .thisEvent)
        }
    }

    @Test func readWhenDeniedThrows() {
        let store = MockEventStore(authorization: .denied)
        let range = DateInterval(start: Fixtures.date(cal, 2026, 6, 1), end: Fixtures.date(cal, 2026, 7, 1))
        #expect(throws: EventStoreError.notAuthorized) {
            try store.events(in: range, calendarIDs: nil)
        }
    }

    @Test func requestAccessGrantsFullAccess() async throws {
        let store = MockEventStore(authorization: .notDetermined)
        let granted = try await store.requestFullAccess()
        #expect(granted)
        #expect(store.authorizationStatus() == .fullAccess)
    }
}

struct ColorHexTests {
    @Test func roundTripPrimaryColors() {
        let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        #expect(ColorHex.string(from: red) == "#FF0000")
        let green = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        #expect(ColorHex.string(from: green) == "#00FF00")
    }

    @Test func parseHex() throws {
        let rgb = try #require(ColorHex.rgb(from: "#1E88E5"))
        #expect(abs(rgb.red - 30.0/255.0) < 0.001)
        #expect(abs(rgb.green - 136.0/255.0) < 0.001)
        #expect(abs(rgb.blue - 229.0/255.0) < 0.001)
    }

    @Test func parseInvalidReturnsNil() {
        #expect(ColorHex.rgb(from: "zzz") == nil)
    }

    @Test func nilColorFallback() {
        #expect(ColorHex.string(from: nil) == "#8E8E93")
    }
}

struct RecurrenceFormatterTests {
    @Test func describesNil() {
        #expect(RecurrenceFormatter.describe(nil) == "반복 안 함")
    }

    @Test func describesDailyEveryDay() {
        #expect(RecurrenceFormatter.describe(SimpleRecurrence(frequency: .daily)) == "매일")
    }

    @Test func describesIntervalWeekly() {
        #expect(RecurrenceFormatter.describe(SimpleRecurrence(frequency: .weekly, interval: 2)) == "2주마다")
    }
}
