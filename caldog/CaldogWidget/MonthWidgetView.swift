import WidgetKit
import SwiftUI
import AppIntents
import CaldogKit

struct MonthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: MonthEntry

    /// 표시 범위(월/3주)는 위젯 구성에서 오며 엔트리에 실려 온다.
    private var mode: ViewModeOption { entry.mode }
    private var accent: Color { Color(widgetHex: entry.accentHex) }
    /// 공급자가 그리드/레인을 만든 것과 동일한 달력으로 조회해야 매칭이 어긋나지 않는다.
    private var calendar: Calendar { entry.calendar }

    /// 작은 위젯은 공간이 없어 내비게이션 버튼을 숨긴다. 3주 뷰는 항상 오늘 기준이라 내비게이션이 없다.
    private var showsNavigation: Bool { mode == .month && family != .systemSmall }
    /// 월 뷰는 큰/특대만 연속 바(나머지는 점). 3주 뷰는 행이 적어 모든 크기에서 바를 그린다.
    private var showsBars: Bool {
        mode == .threeWeeks || family == .systemLarge || family == .systemExtraLarge
    }

    // 바 레이아웃 메트릭
    private var preferredNumberArea: CGFloat { family == .systemExtraLarge ? 20 : 18 }
    /// 선호 레인 높이. 3주 뷰도 월 뷰와 같은 바 크기를 쓴다 — 행이 높은 만큼 바를 키우는 게
    /// 아니라 레인 수를 늘려 더 많은 일정을 보여준다. 촘촘 밀도는 높이를 줄여 레인을 더 담는다.
    private var preferredLaneHeight: CGFloat {
        let base: CGFloat = family == .systemExtraLarge ? 14 : 11
        return entry.density == .compact ? base - 3 : base
    }
    /// 바 제목 글자 크기 상한(레인이 낮아지면 `barView`에서 함께 줄어든다).
    private var barFontCap: CGFloat { family == .systemExtraLarge ? 9 : 8 }
    private let overflowStrip: CGFloat = 8
    private let hInset: CGFloat = 1

    /// 행 높이에 들어가는 날짜 영역/레인 수/레인 높이를 역산한다. 고정 레인 수로 행 높이를
    /// 누적하면 위젯의 실제 캔버스 높이(특히 iPad는 iPhone보다 낮음)를 초과해 하단 주가
    /// 잘리므로, 가용 높이가 기준이 되어야 한다.
    private func laneLayout(rowHeight: CGFloat) -> (numberArea: CGFloat, count: Int, height: CGFloat) {
        // 날짜 숫자 영역도 행 높이에 비례해 줄인다 — 고정 18/20pt는 iPad mini의 낮은 행에서
        // 레인 공간을 다 잡아먹어 일정이 한 줄만 남는 원인이었다.
        let numberArea = min(preferredNumberArea, max(12, rowHeight * 0.34))
        let available = rowHeight - numberArea - overflowStrip
        // 선호 높이 그대로 들어가면 압축하지 않는다 — 항상 압축 기준으로 세면 여유 공간에서도
        // 얇은 레인만 잔뜩 생겨 '보통' 밀도가 촘촘해 보인다. 남는 높이는 레인을 살짝 키워 흡수.
        let full = Int(available / preferredLaneHeight)
        if full >= 2 {
            return (numberArea, full, min(preferredLaneHeight * 1.25, available / CGFloat(full)))
        }
        // 빠듯하면 8pt(글자 6pt 하한)까지 압축해서라도 레인을 확보한다. 선호 높이 비례(80%)
        // 하한은 특대(14pt)에서 11pt가 되어 iPad mini에 레인이 1개만 나왔다.
        let count = max(1, Int(available / 8))
        return (numberArea, count, min(preferredLaneHeight, max(available, 8) / CGFloat(count)))
    }

    var body: some View {
        VStack(spacing: family == .systemSmall ? 3 : 5) {
            header
            weekdayHeader
            grid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .widgetURL(family == .systemSmall ? deepLink(for: entry.date) : nil)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text(monthTitle)
                .font(family == .systemSmall ? .caption.bold() : .headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if showsNavigation {
                if entry.monthOffset != 0 {
                    Button(intent: ResetMonthIntent()) {
                        Text("오늘")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                navButton(systemName: "chevron.left", intent: ShiftMonthIntent(delta: -1))
                navButton(systemName: "chevron.right", intent: ShiftMonthIntent(delta: 1))
            }
        }
    }

    private func navButton(systemName: String, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(entry.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(String(symbol.prefix(1)))
                    .font(.system(size: showsBars ? 11 : 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        if showsBars {
            // 바 모드(large/특대): 남은 높이를 주 수로 나눠 행 높이를 정하고, 그 안에 들어가는
            // 레인 수를 역산한다. 고정 높이 누적으로 iPad에서 하단 주가 잘리던 문제를 방지.
            GeometryReader { geo in
                let weeks = entry.grid.weeks
                let spacing: CGFloat = 2
                let rowH = (geo.size.height - spacing * CGFloat(max(weeks.count - 1, 0)))
                    / CGFloat(max(weeks.count, 1))
                let lanes = laneLayout(rowHeight: rowH)
                VStack(spacing: spacing) {
                    ForEach(weeks, id: \.first?.id) {
                        barWeekRow($0, rowHeight: rowH, numberArea: lanes.numberArea,
                                   maxLanes: lanes.count, laneHeight: lanes.height)
                    }
                }
            }
        } else {
            // 점 모드(small/medium): 남은 높이를 주 수로 나눠 행 높이를 정하고 내부 크기를
            // 비례 조정한다. 고정 크기 누적으로 하단 주가 잘리던 문제를 방지.
            GeometryReader { geo in
                let weeks = entry.grid.weeks
                let rowH = geo.size.height / CGFloat(max(weeks.count, 1))
                VStack(spacing: 0) {
                    ForEach(weeks, id: \.first?.id) { week in
                        dotWeekRow(week, rowHeight: rowH)
                    }
                }
            }
        }
    }

    // MARK: - 연속 바 (Large/특대)

    private func barWeekRow(_ week: [MonthGrid.Day], rowHeight: CGFloat, numberArea: CGFloat,
                            maxLanes: Int, laneHeight: CGFloat) -> some View {
        let dates = week.map(\.date)
        let segments = MonthBarLayout.segments(forWeek: dates, bars: entry.bars, calendar: calendar)
        let overflow = MonthBarLayout.overflowCounts(forWeek: dates, bars: entry.bars,
                                                     maxLanes: maxLanes, calendar: calendar)
        return GeometryReader { geo in
            let colW = geo.size.width / 7
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        Link(destination: deepLink(for: day.date)) {
                            numberLabel(day, numberArea: numberArea)
                                .frame(width: colW, height: rowHeight, alignment: .top)
                                .contentShape(Rectangle())
                        }
                    }
                }
                ForEach(segments.filter { $0.bar.lane < maxLanes }) { seg in
                    barView(seg, laneHeight: laneHeight)
                        .frame(width: colW * CGFloat(seg.columnSpan) - 2 * hInset, height: laneHeight - 2)
                        .clipped() // 글자가 바 높이를 넘어도 아래 레인을 침범하지 못하게(촘촘 모드 겹침 방지)
                        .offset(x: colW * CGFloat(seg.startColumn) + hInset,
                                y: numberArea + CGFloat(seg.bar.lane) * laneHeight)
                        .allowsHitTesting(false)
                }
                ForEach(overflow.sorted { $0.key < $1.key }, id: \.key) { col, count in
                    Text("+\(count)")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .frame(width: colW, alignment: .center)
                        .offset(x: colW * CGFloat(col), y: numberArea + CGFloat(maxLanes) * laneHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: rowHeight)
    }

    private func numberLabel(_ day: MonthGrid.Day, numberArea: CGFloat) -> some View {
        Text("\(calendar.component(.day, from: day.date))")
            .font(.system(size: family == .systemExtraLarge ? 12 : 10,
                          weight: day.isToday ? .bold : .regular))
            .foregroundStyle(day.isToday ? .white : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: numberArea - 1, height: numberArea - 1)
            .background(Circle().fill(day.isToday ? accent : .clear))
            .frame(maxWidth: .infinity)
            .opacity(day.isInMonth ? 1 : 0.3)
    }

    private func barView(_ segment: MonthBarLayout.WeekSegment, laneHeight: CGFloat) -> some View {
        // 캘린더 색에 따라 대비를 보장하는 텍스트/배경색(가독성).
        let palette = ColorHex.barColors(from: segment.bar.colorHex, dark: colorScheme == .dark)
        let showTitle = segment.isStart || segment.startColumn == 0
        let leading: CGFloat = segment.isStart ? 3 : 0
        let trailing: CGFloat = segment.isEnd ? 3 : 0
        // 레인이 낮아지면(촘촘 모드 등) 글자도 함께 줄여 바 높이(laneHeight-2) 안에 담는다.
        let fontSize = max(6, min(barFontCap, laneHeight - 3))
        return Text(showTitle ? segment.bar.title : " ")
            .font(.system(size: fontSize, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(Color(red: palette.text.red, green: palette.text.green, blue: palette.text.blue))
            .background(
                // 반투명 틴트 알약(회색·옅은 색 일정도 배경이 보이도록). 텍스트만 대비색 사용.
                Color(widgetHex: segment.bar.colorHex).opacity(0.22),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: leading, bottomLeadingRadius: leading,
                    bottomTrailingRadius: trailing, topTrailingRadius: trailing
                )
            )
    }

    // MARK: - 점 (small/medium)

    private func dotWeekRow(_ week: [MonthGrid.Day], rowHeight: CGFloat) -> some View {
        HStack(spacing: 1) {
            ForEach(week) { day in
                dotCell(day, rowHeight: rowHeight)
            }
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private func dotCell(_ day: MonthGrid.Day, rowHeight: CGFloat) -> some View {
        if family == .systemSmall {
            dotCellContent(day, rowHeight: rowHeight)
        } else {
            Link(destination: deepLink(for: day.date)) { dotCellContent(day, rowHeight: rowHeight) }
        }
    }

    /// 행 높이에 맞춰 날짜 원과 점 영역을 비례 조정한다(6주가 항상 들어맞게).
    /// 원 크기에 최소값(11pt)을 강제하지 않는다 — 행이 낮은 iPad에서 원+점이 행을 넘쳐
    /// 다음 주 날짜 숫자 위에 점이 겹쳐 보이던 원인이었다. 합이 항상 행 높이와 같도록 배분.
    private func dotCellContent(_ day: MonthGrid.Day, rowHeight: CGFloat) -> some View {
        let dayBars = bars(on: day.date)
        let spacing: CGFloat = 1
        let circle = min(family == .systemSmall ? 18 : 20, (rowHeight - spacing) * 0.72)
        let dotArea = max(0, rowHeight - spacing - circle)
        let dotSize = min(3.5, dotArea * 0.7)
        return VStack(spacing: spacing) {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.system(size: circle * 0.62, weight: day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: circle, height: circle)
                .background(Circle().fill(day.isToday ? accent : .clear))
            HStack(spacing: 2) {
                ForEach(Array(dayBars.prefix(3).enumerated()), id: \.offset) { _, bar in
                    Circle()
                        .fill(day.isInMonth ? Color(widgetHex: bar.colorHex) : Color.secondary)
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(height: dotArea)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(day.isInMonth ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private func bars(on date: Date) -> [MonthBarLayout.MonthBar] {
        let key = calendar.startOfDay(for: date)
        return entry.bars.filter { $0.firstDay <= key && key <= $0.lastDay }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        switch mode {
        case .month:
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("yMMMM")
            return df.string(from: entry.date)
        case .threeWeeks:
            // 3주 뷰는 달을 걸칠 수 있어 기간으로 표기(예: "6월 28일 ~ 7월 18일").
            guard let first = entry.grid.weeks.first?.first?.date,
                  let last = entry.grid.weeks.last?.last?.date else { return "" }
            let f = DateIntervalFormatter()
            f.dateTemplate = "MMMd"
            return f.string(from: first, to: last)
        }
    }

    // 셀마다 호출되므로 DateFormatter 대신 컴포넌트로 직접 포맷. 앱 파서와 동일한 그레고리력 yyyy-MM-dd.
    private func deepLink(for date: Date) -> URL {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let s = String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
        return URL(string: "caldog://date/\(s)") ?? URL(string: "caldog://date")!
    }
}

private extension Color {
    init(widgetHex hex: String) {
        if let rgb = ColorHex.rgb(from: hex) {
            self = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } else {
            self = .blue
        }
    }
}
