import WidgetKit
import SwiftUI
import AppIntents
import CaldogKit

// 버튼 인텐트(ShiftMonthIntent 등)와 WidgetState는 caldog/WidgetIntents.swift에 있다(앱 타깃과
// 공유 — Apple 가이드). 구성 인텐트는 익스텐션 전용이어야 하므로 이 파일에 둔다: 앱에도 등록하면
// 위젯 편집 UI가 앱 쪽 등록으로 저장해 익스텐션이 구성값을 디코드하지 못한다(항상 기본값 표시).

// MARK: - Configuration (중간 수준: 주 시작 요일 + 강조 색, SPEC 이슈 2)

enum WeekStartOption: String, AppEnum {
    case sunday, monday
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "주 시작 요일" }
    static var caseDisplayRepresentations: [WeekStartOption: DisplayRepresentation] {
        [.sunday: "일요일", .monday: "월요일"]
    }
    var firstWeekday: Int { self == .sunday ? 1 : 2 }
}

enum AccentOption: String, AppEnum {
    case peachPink, blue, red, green, orange, purple
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "강조 색" }
    static var caseDisplayRepresentations: [AccentOption: DisplayRepresentation] {
        [.peachPink: "피치 핑크", .blue: "파랑", .red: "빨강", .green: "초록", .orange: "주황", .purple: "보라"]
    }
    var hex: String {
        switch self {
        case .peachPink: return "#FF9F8D"
        case .blue: return "#1E88E5"
        case .red: return "#E53935"
        case .green: return "#43A047"
        case .orange: return "#FB8C00"
        case .purple: return "#8E24AA"
        }
    }
}

/// 표시 범위: 월(6주 그리드, 달 이동 내비게이션) / 3주(오늘 주부터 롤링, 항상 바 표시).
enum ViewModeOption: String, AppEnum {
    case month, threeWeeks
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "표시 범위" }
    static var caseDisplayRepresentations: [ViewModeOption: DisplayRepresentation] {
        [.month: "월", .threeWeeks: "3주"]
    }
}

/// 정보 밀도(테마/밀도 옵션, SPEC §5). 보통은 여유 있게, 촘촘은 라인 높이를 줄여 같은
/// 공간에 더 많은 레인이 들어가게 한다(레인 수는 뷰가 가용 높이에서 역산).
enum DensityOption: String, AppEnum {
    case comfortable, compact
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "정보 밀도" }
    static var caseDisplayRepresentations: [DensityOption: DisplayRepresentation] {
        [.comfortable: "보통", .compact: "촘촘"]
    }
}

// MARK: - 표시 캘린더 선택 (AppEntity picker, SPEC §5)

/// 위젯 구성에서 고를 수 있는 캘린더 항목. EventKit의 EKCalendar를 위젯 구성용으로 노출.
struct CalendarAppEntity: AppEntity, Identifiable {
    let id: String
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "캘린더" }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    static var defaultQuery = CalendarEntityQuery()
}

/// 구성 화면에 캘린더 후보를 제공/복원하는 쿼리. 위젯 프로세스에서 EventKit을 직접 읽는다.
struct CalendarEntityQuery: EntityQuery {
    /// EKEventStore는 프로세스당 재사용이 권장되므로 쿼리 호출마다 새로 만들지 않는다.
    private static let gateway = EventKitGateway()

    func entities(for identifiers: [String]) async throws -> [CalendarAppEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CalendarAppEntity] {
        all()
    }

    private func all() -> [CalendarAppEntity] {
        Self.gateway.calendars().map { CalendarAppEntity(id: $0.id, title: $0.title) }
    }
}

struct MonthWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "캘린더 위젯" }
    static var description: IntentDescription { "캘린더 위젯의 표시 옵션." }

    @Parameter(title: "표시 범위", default: .month)
    var viewMode: ViewModeOption

    @Parameter(title: "표시 캘린더", description: "비워 두면 모든 캘린더를 표시합니다.")
    var calendars: [CalendarAppEntity]?

    @Parameter(title: "주 시작 요일", default: .sunday)
    var weekStart: WeekStartOption

    @Parameter(title: "강조 색", default: .peachPink)
    var accent: AccentOption

    @Parameter(title: "정보 밀도", default: .comfortable)
    var density: DensityOption
}

// MARK: - Timeline

struct MonthEntry: TimelineEntry {
    let date: Date                              // 표시 중인 달(앵커). 3주 모드는 오늘.
    let mode: ViewModeOption                    // 표시 범위(월/3주)
    let monthOffset: Int                        // 현재 달 기준 오프셋(0 = 이번 달, 월 모드 전용)
    let calendar: Calendar                      // 그리드/조회에 쓴 달력(뷰가 동일 달력으로 조회)
    let grid: MonthGrid
    let weekdaySymbols: [String]
    let bars: [MonthBarLayout.MonthBar]         // 연속 바용 레인 배치 결과
    let accentHex: String
    let density: DensityOption                  // 정보 밀도(레인 수에 반영)
}

struct MonthTimelineProvider: AppIntentTimelineProvider {
    /// EKEventStore는 프로세스당 재사용이 권장되므로 공급자에 1개만 둔다.
    private let gateway = EventKitGateway()

    func placeholder(in context: Context) -> MonthEntry {
        makeEntry(config: MonthWidgetConfig(), now: Date(), readEvents: false)
    }

    func snapshot(for configuration: MonthWidgetConfig, in context: Context) async -> MonthEntry {
        makeEntry(config: configuration, now: Date(), readEvents: !context.isPreview)
    }

    func timeline(for configuration: MonthWidgetConfig, in context: Context) async -> Timeline<MonthEntry> {
        let now = Date()
        let entry = makeEntry(config: configuration, now: now, readEvents: true)
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func makeEntry(config: MonthWidgetConfig, now: Date, readEvents: Bool) -> MonthEntry {
        var calendar = Calendar.current
        calendar.firstWeekday = config.weekStart.firstWeekday

        // 표시 범위별 그리드. 3주는 항상 오늘 주부터의 롤링 창이라 달 오프셋과 무관하다.
        let anchor: Date
        let offset: Int
        let grid: MonthGrid
        switch config.viewMode {
        case .month:
            // 갤러리/플레이스홀더(readEvents == false)는 항상 이번 달을 보여준다.
            offset = readEvents ? WidgetState.monthOffset : 0
            anchor = calendar.date(byAdding: .month, value: offset, to: now) ?? now
            grid = MonthGrid.make(for: anchor, calendar: calendar, today: now)
        case .threeWeeks:
            offset = 0
            anchor = now
            grid = MonthGrid.makeWeeks(containing: now, weekCount: 3, calendar: calendar, today: now)
        }

        // 표시 캘린더 필터: 선택이 없으면 nil(전체), 있으면 해당 ID만.
        let selectedIDs = config.calendars?.map(\.id)
        let calendarIDs = (selectedIDs?.isEmpty ?? true) ? nil : selectedIDs

        var bars: [MonthBarLayout.MonthBar] = []
        if readEvents, gateway.authorizationStatus().canRead,
           let events = try? gateway.events(in: grid.dateInterval, calendarIDs: calendarIDs) {
            // 앱과 동일한 연속 바 레인 배치(공유 로직).
            bars = MonthBarLayout.assignLanes(events: events, calendar: calendar, gridInterval: grid.dateInterval)
        }

        return MonthEntry(
            date: anchor,
            mode: config.viewMode,
            monthOffset: offset,
            calendar: calendar,
            grid: grid,
            weekdaySymbols: MonthGrid.weekdaySymbols(calendar: calendar),
            bars: bars,
            accentHex: config.accent.hex,
            density: config.density
        )
    }
}

// MARK: - Widget

struct MonthWidget: Widget {
    static let kind = CaldogWidgetKind.month

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: MonthWidgetConfig.self, provider: MonthTimelineProvider()) { entry in
            MonthWidgetView(entry: entry)
                // 시스템 배경(라이트=흰색)으로 깨끗하게. .fill.tertiary는 회색빛이라 옅은 일정 틴트가 뭉개짐.
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("캘린더")
        .description("이번 달 또는 3주간의 일정을 한눈에 봅니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Previews
// 구성 조합(월/3주 × 보통/촘촘 × 강조 색)을 홈 화면 없이 캔버스에서 바로 확인한다.
// 시뮬레이터의 위젯 구성 편집은 신뢰할 수 없으므로(표시 계층이 옛 렌더를 고정 표시하는
// 사례 확인) 레이아웃 검증은 프리뷰, 구성 편집 E2E는 실기기에서 한다.

#if DEBUG
private enum PreviewMock {

    static func entry(
        mode: ViewModeOption,
        density: DensityOption = .comfortable,
        accent: AccentOption = .peachPink
    ) -> MonthEntry {
        var calendar = Calendar.current
        calendar.firstWeekday = WeekStartOption.sunday.firstWeekday
        let now = Date()
        let grid: MonthGrid
        switch mode {
        case .month:
            grid = MonthGrid.make(for: now, calendar: calendar, today: now)
        case .threeWeeks:
            grid = MonthGrid.makeWeeks(containing: now, weekCount: 3, calendar: calendar, today: now)
        }
        let bars = MonthBarLayout.assignLanes(
            events: events(around: now, calendar: calendar),
            calendar: calendar,
            gridInterval: grid.dateInterval
        )
        return MonthEntry(
            date: now,
            mode: mode,
            monthOffset: 0,
            calendar: calendar,
            grid: grid,
            weekdaySymbols: MonthGrid.weekdaySymbols(calendar: calendar),
            bars: bars,
            accentHex: accent.hex,
            density: density
        )
    }

    /// 오늘 앞뒤 몇 주를 실제 캘린더처럼 채운 mock 일정.
    /// 멀티데이 종일, 겹침(오늘 4건 → 낮은 레인 초과분 "+N"), 긴 제목 말줄임까지 포함.
    private static func events(around now: Date, calendar: Calendar) -> [CalendarEvent] {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, hour: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return hour == 0 ? base : (calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base)
        }
        func timed(_ title: String, dayOffset: Int, hour: Int, hours: Double = 1, color: String) -> CalendarEvent {
            let start = day(dayOffset, hour: hour)
            return CalendarEvent(
                id: "mock-\(title)", title: title,
                start: start, end: start.addingTimeInterval(hours * 3600),
                isAllDay: false, calendarID: "mock", calendarColorHex: color
            )
        }
        func allDay(_ title: String, from: Int, days: Int = 1, color: String) -> CalendarEvent {
            CalendarEvent(
                id: "mock-\(title)", title: title,
                start: day(from), end: day(from + days - 1, hour: 23),
                isAllDay: true, calendarID: "mock", calendarColorHex: color
            )
        }
        let red = "#E53935", blue = "#1E88E5", green = "#43A047"
        let orange = "#FB8C00", purple = "#8E24AA", teal = "#00897B"
        return [
            // 지난 주
            allDay("프로젝트 마감", from: -6, color: red),
            timed("치과 예약", dayOffset: -4, hour: 10, color: teal),
            timed("팀 회식", dayOffset: -2, hour: 19, hours: 2, color: orange),
            // 오늘(겹침 → 오버플로 확인)
            timed("스탠드업", dayOffset: 0, hour: 9, hours: 0.5, color: blue),
            timed("디자인 리뷰", dayOffset: 0, hour: 11, color: purple),
            timed("점심 약속", dayOffset: 0, hour: 12, hours: 1.5, color: green),
            timed("1:1 미팅", dayOffset: 0, hour: 15, color: blue),
            // 이번 주
            allDay("여름 휴가", from: 2, days: 3, color: teal),
            timed("요가 클래스", dayOffset: 4, hour: 7, color: green),
            // 다음 주
            allDay("부산 출장", from: 8, days: 2, color: blue),
            timed("건강검진", dayOffset: 10, hour: 8, hours: 3, color: red),
            allDay("FORMULA 1 코리아 그랑프리 결승", from: 12, color: red),
            // 2주 뒤(월 그리드 하단/3주 마지막 주)
            timed("동창 모임", dayOffset: 16, hour: 18, hours: 3, color: orange),
            allDay("엄마 생신", from: 18, color: purple),
        ]
    }
}

#Preview("월 · 보통", as: .systemLarge) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .month)
}

#Preview("월 · 촘촘", as: .systemLarge) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .month, density: .compact)
}

#Preview("3주 · 보통", as: .systemLarge) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .threeWeeks)
}

#Preview("3주 · 촘촘 · 빨강", as: .systemExtraLarge) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .threeWeeks, density: .compact, accent: .red)
}

#Preview("작게", as: .systemSmall) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .month)
}

#Preview("중간", as: .systemMedium) {
    MonthWidget()
} timeline: {
    PreviewMock.entry(mode: .month)
}
#endif
