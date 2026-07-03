import Foundation

/// EventKit 접근 권한 상태를 앱 도메인으로 추상화한 값.
public enum CalendarAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
    case writeOnly

    /// 일정을 읽어 표시할 수 있는 상태인지.
    public var canRead: Bool { self == .fullAccess }
    /// 일정을 생성/수정할 수 있는 상태인지.
    public var canWrite: Bool { self == .fullAccess || self == .writeOnly }
}

/// 반복 일정 편집/삭제의 적용 범위.
public enum EventSpan: Sendable, Equatable {
    case thisEvent
    case futureEvents
}

/// 캘린더(EKCalendar)의 표시용 스냅샷.
public struct CalendarInfo: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let colorHex: String
    public let allowsModification: Bool
    public let sourceTitle: String

    public init(id: String, title: String, colorHex: String, allowsModification: Bool, sourceTitle: String) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.allowsModification = allowsModification
        self.sourceTitle = sourceTitle
    }
}

/// 이벤트(EKEvent)의 읽기 전용 스냅샷. 일정 본문은 EventKit이 원본이며 caldog는 저장하지 않는다.
public struct CalendarEvent: Sendable, Equatable, Identifiable, Hashable {
    public let id: String              // eventIdentifier
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarColorHex: String
    public let location: String?
    public let notes: String?
    public let hasRecurrence: Bool

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarColorHex: String,
        location: String? = nil,
        notes: String? = nil,
        hasRecurrence: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarColorHex = calendarColorHex
        self.location = location
        self.notes = notes
        self.hasRecurrence = hasRecurrence
    }
}

/// 알람 오프셋(이벤트 시작 기준 상대 시간, 초 단위. 음수 = 시작 전).
public struct AlarmOffset: Sendable, Equatable, Hashable {
    public let secondsRelativeToStart: TimeInterval
    public init(secondsRelativeToStart: TimeInterval) {
        self.secondsRelativeToStart = secondsRelativeToStart
    }
    public static let atStart = AlarmOffset(secondsRelativeToStart: 0)
    public static func minutesBefore(_ m: Int) -> AlarmOffset { .init(secondsRelativeToStart: -Double(m) * 60) }
    public static func hoursBefore(_ h: Int) -> AlarmOffset { .init(secondsRelativeToStart: -Double(h) * 3600) }
    public static func daysBefore(_ d: Int) -> AlarmOffset { .init(secondsRelativeToStart: -Double(d) * 86400) }
}

/// 단순 반복 규칙 표현(EKRecurrenceRule로 매핑).
public struct SimpleRecurrence: Sendable, Equatable, Hashable {
    public enum Frequency: String, Sendable, CaseIterable, Codable {
        case daily, weekly, monthly, yearly
    }
    public let frequency: Frequency
    public let interval: Int
    /// nil = 무한 반복. 그 외 종료일.
    public let endDate: Date?

    public init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.endDate = endDate
    }
}

/// 새 이벤트 생성/수정에 사용하는 입력 묶음.
public struct EventDraft: Sendable, Equatable {
    public var existingIdentifier: String?     // nil = 신규
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarID: String?             // nil = 기본 캘린더
    public var location: String?
    public var notes: String?
    public var url: URL?
    public var alarms: [AlarmOffset]
    public var recurrence: SimpleRecurrence?

    public init(
        existingIdentifier: String? = nil,
        title: String = "",
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarID: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        alarms: [AlarmOffset] = [],
        recurrence: SimpleRecurrence? = nil
    ) {
        self.existingIdentifier = existingIdentifier
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.location = location
        self.notes = notes
        self.url = url
        self.alarms = alarms
        self.recurrence = recurrence
    }
}

/// 게이트웨이 오류.
public enum EventStoreError: Error, Sendable, Equatable {
    case notAuthorized
    case calendarNotFound
    case eventNotFound
    case calendarIsImmutable
    case underlying(String)
}
