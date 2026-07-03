import SwiftUI
import CaldogKit

/// 월 그리드(6주 × 7일). 일정을 애플 캘린더처럼 연속 바로 표시한다.
/// 여러 날에 걸친 일정은 주 경계에서 분할된 하나의 바로 그려진다(레인 계산: `MonthBarLayout`).
struct MonthCalendarView: View {
    @Bindable var store: CalendarStore
    /// 축소 모드: 선택된 주 한 줄만 표시(일정 목록 스크롤 시 애플식 간략화).
    var collapsed: Bool = false

    private let numberArea: CGFloat = 24
    private let laneHeight: CGFloat = 15
    private let overflowStrip: CGFloat = 12
    private var maxLanes: Int { CalendarStore.maxBarLanes }
    private var rowHeight: CGFloat { numberArea + CGFloat(maxLanes) * laneHeight + overflowStrip }

    /// 선택된 날짜가 속한 주의 인덱스(없으면 0).
    private func selectedWeekIndex(_ weeks: [[MonthGrid.Day]]) -> Int {
        weeks.firstIndex { week in
            week.contains { store.calendar.isDate($0.date, inSameDayAs: store.selectedDate) }
        } ?? 0
    }

    var body: some View {
        let grid = store.grid
        let weeks = grid.weeks
        let selected = selectedWeekIndex(weeks)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(store.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)
            // 모든 주를 항상 렌더하고, 접힐 때 비선택 주만 height→0 + opacity→0으로
            // 애니메이션해 자연스럽게 사라지게 한다(데이터 교체 시의 끊김 방지).
            ForEach(weeks.indices, id: \.self) { i in
                let hidden = collapsed && i != selected
                let week = weeks[i]
                let dates = week.map(\.date)
                WeekRow(
                    week: week,
                    segments: MonthBarLayout.segments(forWeek: dates, bars: store.monthBars, calendar: store.calendar),
                    overflow: MonthBarLayout.overflowCounts(forWeek: dates, bars: store.monthBars,
                                                            maxLanes: maxLanes, calendar: store.calendar),
                    calendar: store.calendar,
                    selectedDate: store.selectedDate,
                    numberArea: numberArea,
                    laneHeight: laneHeight,
                    maxLanes: maxLanes,
                    rowHeight: rowHeight,
                    onSelect: { store.select($0) }
                )
                .frame(height: hidden ? 0 : rowHeight)
                .opacity(hidden ? 0 : 1)
                .clipped()
                .allowsHitTesting(!hidden)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WeekRow: View {
    let week: [MonthGrid.Day]
    let segments: [MonthBarLayout.WeekSegment]
    let overflow: [Int: Int]
    let calendar: Calendar
    let selectedDate: Date
    let numberArea: CGFloat
    let laneHeight: CGFloat
    let maxLanes: Int
    let rowHeight: CGFloat
    let onSelect: (Date) -> Void

    private let hInset: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let colW = geo.size.width / 7
            ZStack(alignment: .topLeading) {
                // 날짜 숫자 + 선택 + 탭 타깃
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        dayColumn(day)
                            .frame(width: colW, height: rowHeight, alignment: .top)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(day.date) }
                    }
                }
                // 연속 바(보이는 레인만)
                ForEach(segments.filter { $0.bar.lane < maxLanes }) { seg in
                    BarView(segment: seg)
                        .frame(width: colW * CGFloat(seg.columnSpan) - 2 * hInset, height: laneHeight - 2)
                        .offset(x: colW * CGFloat(seg.startColumn) + hInset,
                                y: numberArea + CGFloat(seg.bar.lane) * laneHeight)
                        .allowsHitTesting(false)
                }
                // 초과("+N")
                ForEach(overflow.sorted { $0.key < $1.key }, id: \.key) { col, count in
                    Text("+\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: colW, alignment: .center)
                        .offset(x: colW * CGFloat(col), y: numberArea + CGFloat(maxLanes) * laneHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: rowHeight)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 0.5)
        }
    }

    private func dayColumn(_ day: MonthGrid.Day) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        return Text("\(calendar.component(.day, from: day.date))")
            .font(.callout)
            .fontWeight(day.isToday ? .bold : .regular)
            .foregroundStyle(day.isToday ? .white : .primary)
            .frame(width: 26, height: 22)
            .background(Circle().fill(day.isToday ? Color.accentColor : .clear))
            .frame(maxWidth: .infinity)
            .padding(.top, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected && !day.isToday ? Color.gray.opacity(0.2) : .clear)
            )
            .opacity(day.isInMonth ? 1 : 0.3)
    }
}

private struct BarView: View {
    let segment: MonthBarLayout.WeekSegment

    private var color: Color { Color(hex: segment.bar.colorHex) }
    private var showTitle: Bool { segment.isStart || segment.startColumn == 0 }
    private var leadingRadius: CGFloat { segment.isStart ? 4 : 0 }
    private var trailingRadius: CGFloat { segment.isEnd ? 4 : 0 }

    var body: some View {
        Text(showTitle ? segment.bar.title : " ")
            .font(.system(size: 9))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(color)
            .background(
                color.opacity(0.22),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: leadingRadius,
                    bottomLeadingRadius: leadingRadius,
                    bottomTrailingRadius: trailingRadius,
                    topTrailingRadius: trailingRadius
                )
            )
    }
}
