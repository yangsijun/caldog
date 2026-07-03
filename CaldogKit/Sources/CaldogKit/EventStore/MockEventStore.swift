import Foundation

/// 테스트/프리뷰용 인메모리 일정 저장소.
public final class MockEventStore: EventStoreGateway {
    public var authorization: CalendarAuthorization
    public private(set) var storedCalendars: [CalendarInfo]
    public private(set) var storedEvents: [CalendarEvent]
    private var idCounter = 0

    public init(
        authorization: CalendarAuthorization = .fullAccess,
        calendars: [CalendarInfo] = MockEventStore.defaultCalendars,
        events: [CalendarEvent] = []
    ) {
        self.authorization = authorization
        self.storedCalendars = calendars
        self.storedEvents = events
    }

    public func authorizationStatus() -> CalendarAuthorization { authorization }

    public func requestFullAccess() async throws -> Bool {
        authorization = .fullAccess
        return true
    }

    public func calendars() -> [CalendarInfo] { storedCalendars }

    public func events(in range: DateInterval, calendarIDs: [String]?) throws -> [CalendarEvent] {
        guard authorization.canRead else { throw EventStoreError.notAuthorized }
        return storedEvents
            .filter { $0.start < range.end && $0.end > range.start }
            .filter { calendarIDs == nil || calendarIDs!.contains($0.calendarID) }
            .sorted { $0.start < $1.start }
    }

    @discardableResult
    public func save(_ draft: EventDraft, span: EventSpan) throws -> String {
        guard authorization.canWrite else { throw EventStoreError.notAuthorized }
        let calendarID = draft.calendarID ?? storedCalendars.first?.id ?? "mock-default"
        guard let cal = storedCalendars.first(where: { $0.id == calendarID }) else {
            throw EventStoreError.calendarNotFound
        }
        guard cal.allowsModification else { throw EventStoreError.calendarIsImmutable }

        let event = CalendarEvent(
            id: draft.existingIdentifier ?? nextID(),
            title: draft.title,
            start: draft.start,
            end: draft.end,
            isAllDay: draft.isAllDay,
            calendarID: calendarID,
            calendarColorHex: cal.colorHex,
            location: draft.location,
            notes: draft.notes,
            hasRecurrence: draft.recurrence != nil
        )
        if let existing = draft.existingIdentifier,
           let idx = storedEvents.firstIndex(where: { $0.id == existing }) {
            storedEvents[idx] = event
        } else {
            storedEvents.append(event)
        }
        return event.id
    }

    public func delete(eventIdentifier: String, span: EventSpan) throws {
        guard authorization.canWrite else { throw EventStoreError.notAuthorized }
        guard storedEvents.contains(where: { $0.id == eventIdentifier }) else {
            throw EventStoreError.eventNotFound
        }
        storedEvents.removeAll { $0.id == eventIdentifier }
    }

    private func nextID() -> String {
        idCounter += 1
        return "mock-event-\(idCounter)"
    }

    public static let defaultCalendars: [CalendarInfo] = [
        CalendarInfo(id: "cal-personal", title: "개인", colorHex: "#1E88E5", allowsModification: true, sourceTitle: "iCloud"),
        CalendarInfo(id: "cal-work", title: "업무", colorHex: "#E53935", allowsModification: true, sourceTitle: "iCloud"),
        CalendarInfo(id: "cal-holidays", title: "대한민국 공휴일", colorHex: "#43A047", allowsModification: false, sourceTitle: "구독"),
    ]
}
