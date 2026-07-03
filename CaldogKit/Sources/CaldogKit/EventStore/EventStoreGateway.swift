import Foundation

/// 일정 원본(EventKit) 접근을 추상화한 게이트웨이.
///
/// 앱·위젯·테스트는 이 프로토콜에만 의존한다. 실제 구현은 `EventKitGateway`,
/// 테스트용 인메모리 구현은 `MockEventStore`.
public protocol EventStoreGateway: AnyObject {
    /// 현재 캘린더 접근 권한 상태.
    func authorizationStatus() -> CalendarAuthorization

    /// 전체 접근 권한 요청. 허용 여부를 반환.
    func requestFullAccess() async throws -> Bool

    /// 표시 가능한 캘린더 목록.
    func calendars() -> [CalendarInfo]

    /// 기간 내 이벤트 조회. `calendarIDs == nil`이면 전체 캘린더.
    func events(in range: DateInterval, calendarIDs: [String]?) throws -> [CalendarEvent]

    // MARK: - 쓰기 API (현재 미사용 — 향후 편집 지원용 예약)
    //
    // 재포지셔닝(위젯 중심 컴패니언)으로 앱/위젯은 일정을 읽기만 하며 편집은 애플 캘린더에
    // 위임한다(SPEC §4.3). 아래 쓰기 API는 어떤 호출부에서도 사용하지 않지만, EventKit
    // 게이트웨이의 정당한 능력이자 향후 편집 기능 복원 시 재사용하기 위해 보존한다.

    /// 이벤트 생성/수정. 저장된 이벤트의 식별자를 반환. (예약: 현재 미사용)
    @discardableResult
    func save(_ draft: EventDraft, span: EventSpan) throws -> String

    /// 이벤트 삭제. (예약: 현재 미사용)
    func delete(eventIdentifier: String, span: EventSpan) throws
}

public extension EventStoreGateway {
    /// 특정 날짜(로컬 자정~자정)의 이벤트.
    func events(on day: Date, calendar: Calendar, calendarIDs: [String]? = nil) throws -> [CalendarEvent] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try events(in: DateInterval(start: start, end: end), calendarIDs: calendarIDs)
    }
}
