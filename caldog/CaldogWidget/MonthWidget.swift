import WidgetKit
import SwiftUI
import AppIntents
import CaldogKit

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

/// 정보 밀도(테마/밀도 옵션, SPEC §5). 보통은 여유 있게, 촘촘은 레인을 더 늘리고 라인 높이를
/// 줄여 더 많은 일정을 빽빽하게 보여준다.
enum DensityOption: String, AppEnum {
    case comfortable, compact
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "정보 밀도" }
    static var caseDisplayRepresentations: [DensityOption: DisplayRepresentation] {
        [.comfortable: "보통", .compact: "촘촘"]
    }
    /// 패밀리별 기본 레인 수에 더하는 값(촘촘일수록 레인을 늘려 더 많은 일정을 표시).
    var laneBonus: Int { self == .compact ? 1 : 0 }
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

/// 구성 화면에 캘린더 후보를 제공/복원하는 쿼리. 앱 프로세스에서 EventKit을 직접 읽는다.
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
    static var title: LocalizedStringResource { "월 캘린더 위젯" }
    static var description: IntentDescription { "월 캘린더 위젯의 표시 옵션." }

    @Parameter(title: "표시 캘린더", description: "비워 두면 모든 캘린더를 표시합니다.")
    var calendars: [CalendarAppEntity]?

    @Parameter(title: "주 시작 요일", default: .sunday)
    var weekStart: WeekStartOption

    @Parameter(title: "강조 색", default: .peachPink)
    var accent: AccentOption

    @Parameter(title: "정보 밀도", default: .comfortable)
    var density: DensityOption
}

// MARK: - 위젯 상호작용 상태 (현재 표시 중인 달 오프셋)
//
// 위젯의 ‹/› 버튼이 누적 오프셋을 갱신하고, 타임라인 공급자가 이를 읽어 표시 달을 결정한다.
// 인터랙티브 AppIntent와 공급자가 같은 저장소를 공유해야 하므로 App Group 스위트를 사용한다.
// (App Group capability 미연결 시에도 위젯 익스텐션 프로세스 내에서는 동작하며, 정식 동작에는
//  `group.dev.sijun.caldog` App Group 활성화가 필요하다 — docs/CAPABILITIES.md 참고.)
//
// 설계 메모: monthOffset은 전역 단일 값이라 같은 종류 위젯 인스턴스가 여러 개면 모두 같은 달을
// 함께 이동한다. 단순함을 위한 의도적 선택(대부분 월 위젯은 1개만 배치). 인스턴스별 분리가
// 필요해지면 구성 인텐트 파라미터로 오프셋을 옮긴다.
enum WidgetState {
    private static let key = "monthOffset"
    /// ±10년으로 제한해 극단 오프셋에서 date(byAdding:)가 nil이 되는 상황을 막는다.
    static let limit = 120
    private static let store = UserDefaults(suiteName: "group.dev.sijun.caldog") ?? .standard
    static var monthOffset: Int {
        get { store.integer(forKey: key) }
        set { store.set(max(-limit, min(limit, newValue)), forKey: key) }
    }
}

// MARK: - 인터랙티브 인텐트 (이전/다음 달, 이번 달)

struct ShiftMonthIntent: AppIntent {
    static var title: LocalizedStringResource { "월 이동" }
    @Parameter(title: "이동") var delta: Int
    init() {}
    init(delta: Int) { self.delta = delta }
    func perform() async throws -> some IntentResult {
        WidgetState.monthOffset += delta
        // 오프셋이 전역 공유 값이므로 같은 종류 위젯 전체를 갱신한다.
        WidgetCenter.shared.reloadTimelines(ofKind: MonthWidget.kind)
        return .result()
    }
}

struct ResetMonthIntent: AppIntent {
    static var title: LocalizedStringResource { "이번 달로" }
    init() {}
    func perform() async throws -> some IntentResult {
        WidgetState.monthOffset = 0
        WidgetCenter.shared.reloadTimelines(ofKind: MonthWidget.kind)
        return .result()
    }
}

// MARK: - Timeline

struct MonthEntry: TimelineEntry {
    let date: Date                              // 표시 중인 달(앵커)
    let monthOffset: Int                        // 현재 달 기준 오프셋(0 = 이번 달)
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

        // 갤러리/플레이스홀더(readEvents == false)는 항상 이번 달을 보여준다.
        let offset = readEvents ? WidgetState.monthOffset : 0
        let anchor = calendar.date(byAdding: .month, value: offset, to: now) ?? now
        let grid = MonthGrid.make(for: anchor, calendar: calendar, today: now)

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
    static let kind = "CaldogMonthWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: MonthWidgetConfig.self, provider: MonthTimelineProvider()) { entry in
            MonthWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("월 캘린더")
        .description("이번 달 일정을 한눈에 봅니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
