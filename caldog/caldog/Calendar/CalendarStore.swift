import SwiftUI
import Observation
import EventKit
import CaldogKit

/// 월 캘린더 화면 상태를 관리하는 뷰 모델.
///
/// EventKit 게이트웨이에서 가시 범위의 일정을 읽어 날짜별로 그룹핑한다.
/// 일정 원본은 EventKit이며 여기서는 캐시만 보관한다(SPEC §2.1).
@MainActor
@Observable
final class CalendarStore {
    let gateway: EventStoreGateway
    var calendar: Calendar
    var today: Date
    var visibleMonthAnchor: Date
    var selectedDate: Date
    var authorization: CalendarAuthorization

    private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]
    private(set) var monthBars: [MonthBarLayout.MonthBar] = []
    private(set) var calendars: [CalendarInfo] = []

    /// 월 그리드에 표시할 최대 레인 수(초과분은 "+N").
    static let maxBarLanes = 3

    init(gateway: EventStoreGateway, calendar: Calendar = .current, now: Date = Date()) {
        self.gateway = gateway
        self.calendar = calendar
        self.today = now
        self.visibleMonthAnchor = now
        self.selectedDate = calendar.startOfDay(for: now)
        self.authorization = gateway.authorizationStatus()
    }

    var grid: MonthGrid {
        MonthGrid.make(for: visibleMonthAnchor, calendar: calendar, today: today)
    }

    var monthTitle: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = calendar.locale ?? .current
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: visibleMonthAnchor)
    }

    var weekdaySymbols: [String] { MonthGrid.weekdaySymbols(calendar: calendar) }

    func refreshAuthorization() {
        authorization = gateway.authorizationStatus()
    }

    func requestAccess() async {
        _ = try? await gateway.requestFullAccess()
        refreshAuthorization()
        reload()
    }

    func reload() {
        guard authorization.canRead else {
            eventsByDay = [:]
            return
        }
        calendars = gateway.calendars()
        let interval = grid.dateInterval
        let events = (try? gateway.events(in: interval, calendarIDs: nil)) ?? []
        var map: [Date: [CalendarEvent]] = [:]
        for event in events {
            // 위젯과 동일 규칙: 걸친 모든 날에 배치(배타적 종료). 공유 로직은 EventLayout.
            for key in EventLayout.coveredDays(start: event.start, end: event.end,
                                               calendar: calendar, clampedTo: interval) {
                map[key, default: []].append(event)
            }
        }
        eventsByDay = map
        // 월 그리드 연속 바용 레인 배치(애플식). 공유 로직은 MonthBarLayout.
        monthBars = MonthBarLayout.assignLanes(events: events, calendar: calendar, gridInterval: interval)
    }

    func events(on day: Date) -> [CalendarEvent] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    func isSelected(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: selectedDate)
    }

    func select(_ day: Date) {
        selectedDate = calendar.startOfDay(for: day)
    }

    func goToMonth(offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: visibleMonthAnchor) else { return }
        visibleMonthAnchor = next
        reload()
    }

    func goToToday() {
        visibleMonthAnchor = today
        selectedDate = calendar.startOfDay(for: today)
        reload()
    }

    /// 설정의 주 시작 요일을 반영.
    func applyFirstWeekday(_ firstWeekday: Int) {
        guard calendar.firstWeekday != firstWeekday else { return }
        calendar = CalendarFactory.calendar(firstWeekday: firstWeekday, base: calendar)
        reload()
    }

    /// 위젯 딥링크 등 외부 진입 횟수(증가 시 화면은 월을 접어 일정 목록을 넓게 보여준다).
    private(set) var deepLinkArrivals = 0

    /// 위젯 딥링크 등 외부 진입으로 특정 날짜로 이동.
    func navigate(to date: Date) {
        visibleMonthAnchor = date
        selectedDate = calendar.startOfDay(for: date)
        reload()
        deepLinkArrivals += 1
    }

    /// 애플 캘린더를 특정 날짜로 여는 URL. 일정 생성/편집/삭제는 애플 캘린더에 위임한다
    /// (caldog는 위젯 중심 컴패니언으로, 앱 자체는 읽기 전용 글랜스다 — SPEC §4.3).
    ///
    /// `calshow:`는 Reference Date(2001-01-01) 기준 초를 받는다(iOS/iPadOS 전용 스킴).
    /// 초 단위로 자르는 것은 의도적이며 무해하다(애플 캘린더는 날짜만 사용).
    /// macOS는 날짜 점프용 공개 URL 스킴이 없어 nil을 반환하고, 호출부는 해당 동작을 숨긴다.
    func appleCalendarURL(for date: Date) -> URL? {
        #if os(iOS)
        return URL(string: "calshow:\(Int(date.timeIntervalSinceReferenceDate))")
        #else
        return nil
        #endif
    }

    /// 식별자로 원본 `EKEvent`를 조회한다(인앱 네이티브 일정 상세 표시용).
    /// EventKit 백엔드가 아닐 때(예: 프리뷰 Mock)는 nil.
    func ekEvent(for event: CalendarEvent) -> EKEvent? {
        (gateway as? EventKitGateway)?.ekEvent(withIdentifier: event.id)
    }
}
