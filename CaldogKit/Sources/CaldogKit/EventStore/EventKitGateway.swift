import Foundation
import EventKit

/// EventKit(`EKEventStore`) 기반 실제 일정 게이트웨이.
public final class EventKitGateway: EventStoreGateway {
    public let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func authorizationStatus() -> CalendarAuthorization {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestFullAccess() async throws -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            throw EventStoreError.underlying(error.localizedDescription)
        }
    }

    public func calendars() -> [CalendarInfo] {
        store.calendars(for: .event).map(Self.map(calendar:))
    }

    public func events(in range: DateInterval, calendarIDs: [String]?) throws -> [CalendarEvent] {
        guard authorizationStatus().canRead else { throw EventStoreError.notAuthorized }
        let calendars = resolveCalendars(calendarIDs)
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
        return store.events(matching: predicate)
            .map(Self.map(event:))
            .sorted { $0.start < $1.start }
    }

    /// 식별자로 원본 `EKEvent`를 조회한다(인앱 네이티브 일정 상세 표시용).
    public func ekEvent(withIdentifier id: String) -> EKEvent? {
        store.event(withIdentifier: id)
    }

    @discardableResult
    public func save(_ draft: EventDraft, span: EventSpan) throws -> String {
        guard authorizationStatus().canWrite else { throw EventStoreError.notAuthorized }

        let event: EKEvent
        if let id = draft.existingIdentifier, let existing = store.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        guard let calendar = targetCalendar(for: draft) else { throw EventStoreError.calendarNotFound }
        guard calendar.allowsContentModifications else { throw EventStoreError.calendarIsImmutable }

        event.calendar = calendar
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.isAllDay
        event.location = draft.location
        event.notes = draft.notes
        event.url = draft.url

        event.alarms = draft.alarms.map { EKAlarm(relativeOffset: $0.secondsRelativeToStart) }

        if let recurrence = draft.recurrence {
            event.recurrenceRules = [Self.map(recurrence: recurrence)]
        } else {
            event.recurrenceRules = nil
        }

        do {
            try store.save(event, span: Self.map(span: span), commit: true)
        } catch {
            throw EventStoreError.underlying(error.localizedDescription)
        }
        return event.eventIdentifier
    }

    public func delete(eventIdentifier: String, span: EventSpan) throws {
        guard authorizationStatus().canWrite else { throw EventStoreError.notAuthorized }
        guard let event = store.event(withIdentifier: eventIdentifier) else {
            throw EventStoreError.eventNotFound
        }
        do {
            try store.remove(event, span: Self.map(span: span), commit: true)
        } catch {
            throw EventStoreError.underlying(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func resolveCalendars(_ ids: [String]?) -> [EKCalendar]? {
        guard let ids else { return nil }
        let set = Set(ids)
        let matched = store.calendars(for: .event).filter { set.contains($0.calendarIdentifier) }
        return matched.isEmpty ? nil : matched
    }

    private func targetCalendar(for draft: EventDraft) -> EKCalendar? {
        if let id = draft.calendarID, let cal = store.calendar(withIdentifier: id) {
            return cal
        }
        return store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first
    }

    // MARK: - Mapping

    static func map(_ status: EKAuthorizationStatus) -> CalendarAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        @unknown default: return .denied
        }
    }

    static func map(calendar: EKCalendar) -> CalendarInfo {
        CalendarInfo(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: ColorHex.string(from: calendar.cgColor),
            allowsModification: calendar.allowsContentModifications,
            sourceTitle: calendar.source?.title ?? ""
        )
    }

    static func map(event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            calendarColorHex: ColorHex.string(from: event.calendar?.cgColor),
            location: event.location,
            notes: event.notes,
            hasRecurrence: event.hasRecurrenceRules
        )
    }

    static func map(span: EventSpan) -> EKSpan {
        switch span {
        case .thisEvent: return .thisEvent
        case .futureEvents: return .futureEvents
        }
    }

    static func map(recurrence: SimpleRecurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let end = recurrence.endDate.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: recurrence.interval, end: end)
    }
}
