import WidgetKit
import SwiftUI
import AppIntents
import CaldogKit

struct MonthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: MonthEntry

    private var accent: Color { Color(widgetHex: entry.accentHex) }
    /// 공급자가 그리드/레인을 만든 것과 동일한 달력으로 조회해야 매칭이 어긋나지 않는다.
    private var calendar: Calendar { entry.calendar }

    /// 작은 위젯은 공간이 없어 내비게이션 버튼을 숨긴다.
    private var showsNavigation: Bool { family != .systemSmall }
    /// 큰/특대 위젯만 연속 바를 그린다(나머지는 점).
    private var showsBars: Bool { family == .systemLarge || family == .systemExtraLarge }
    private var maxLanes: Int {
        let base = family == .systemExtraLarge ? 3 : 2
        return base + entry.density.laneBonus
    }

    // 바 레이아웃 메트릭
    private var numberArea: CGFloat { family == .systemExtraLarge ? 20 : 18 }
    /// 촘촘 모드는 레인을 한 줄 더 넣는 대신 라인 높이를 줄여 같은 공간에 더 많은 일정을 담는다.
    private var laneHeight: CGFloat {
        let base: CGFloat = family == .systemExtraLarge ? 14 : 11
        return entry.density == .compact ? base - 3 : base
    }
    private let overflowStrip: CGFloat = 8
    private var barRowHeight: CGFloat { numberArea + CGFloat(maxLanes) * laneHeight + overflowStrip }
    private let hInset: CGFloat = 1

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
            VStack(spacing: 2) {
                ForEach(entry.grid.weeks, id: \.first?.id) { barWeekRow($0) }
            }
            .frame(maxHeight: .infinity)
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

    private func barWeekRow(_ week: [MonthGrid.Day]) -> some View {
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
                            numberLabel(day)
                                .frame(width: colW, height: barRowHeight, alignment: .top)
                                .contentShape(Rectangle())
                        }
                    }
                }
                ForEach(segments.filter { $0.bar.lane < maxLanes }) { seg in
                    barView(seg)
                        .frame(width: colW * CGFloat(seg.columnSpan) - 2 * hInset, height: laneHeight - 2)
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
        .frame(height: barRowHeight)
    }

    private func numberLabel(_ day: MonthGrid.Day) -> some View {
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

    private func barView(_ segment: MonthBarLayout.WeekSegment) -> some View {
        // 캘린더 색에 따라 대비를 보장하는 텍스트/배경색(가독성).
        let palette = ColorHex.barColors(from: segment.bar.colorHex, dark: colorScheme == .dark)
        let showTitle = segment.isStart || segment.startColumn == 0
        let leading: CGFloat = segment.isStart ? 3 : 0
        let trailing: CGFloat = segment.isEnd ? 3 : 0
        return Text(showTitle ? segment.bar.title : " ")
            .font(.system(size: family == .systemExtraLarge ? 9 : 8, weight: .medium))
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
    private func dotCellContent(_ day: MonthGrid.Day, rowHeight: CGFloat) -> some View {
        let dayBars = bars(on: day.date)
        let dotArea: CGFloat = 5
        let spacing: CGFloat = 1
        let circle = max(11, min(rowHeight - dotArea - spacing, family == .systemSmall ? 18 : 20))
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
                        .frame(width: 3.5, height: 3.5)
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
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: entry.date)
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
