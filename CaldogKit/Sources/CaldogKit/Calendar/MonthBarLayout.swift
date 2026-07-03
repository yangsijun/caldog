import Foundation

/// 월 그리드에서 일정을 "연속 바"로 그리기 위한 레인 배치/주별 분할 로직(순수).
///
/// 애플 캘린더 월 뷰처럼:
/// - 여러 날에 걸친 일정은 하나의 가로 바로 그리고, 주 경계에서 분할된다.
/// - 겹치는 일정은 서로 다른 레인(세로 줄)에 놓이며, 한 일정은 달 전체에서 같은 레인을 유지한다.
/// 렌더링(SwiftUI)은 앱/위젯이 각자 담당하고, 위치 계산만 여기서 공유한다.
public enum MonthBarLayout {

    /// 레인이 배정된 일정 바 1개(occurrence 단위).
    public struct MonthBar: Sendable, Hashable, Identifiable {
        public let id: String          // occurrence 고유 키(반복 일정 중복 id 회피)
        public let eventID: String
        public let title: String
        public let colorHex: String
        public let isAllDay: Bool
        public let lane: Int           // 0부터. 같은 일정은 달 전체에서 동일.
        public let firstDay: Date      // 점유 첫날(자정, 그리드로 클램프)
        public let lastDay: Date       // 점유 끝날(자정, 포함, 클램프)

        public init(id: String, eventID: String, title: String, colorHex: String,
                    isAllDay: Bool, lane: Int, firstDay: Date, lastDay: Date) {
            self.id = id; self.eventID = eventID; self.title = title; self.colorHex = colorHex
            self.isAllDay = isAllDay; self.lane = lane; self.firstDay = firstDay; self.lastDay = lastDay
        }
    }

    /// 한 주 안에서의 바 한 토막.
    public struct WeekSegment: Sendable, Hashable, Identifiable {
        public let id: String
        public let bar: MonthBar
        public let startColumn: Int    // 0...6
        public let columnSpan: Int     // >= 1
        public let isStart: Bool       // 이 주에서 바가 진짜 시작(왼쪽 둥글게)
        public let isEnd: Bool         // 이 주에서 바가 진짜 끝(오른쪽 둥글게)

        public init(id: String, bar: MonthBar, startColumn: Int, columnSpan: Int, isStart: Bool, isEnd: Bool) {
            self.id = id; self.bar = bar; self.startColumn = startColumn
            self.columnSpan = columnSpan; self.isStart = isStart; self.isEnd = isEnd
        }
    }

    /// 일정들에 레인을 배정한다(겹치면 다른 레인, 최소 레인 수, 시작일 기준 안정 정렬).
    public static func assignLanes(
        events: [CalendarEvent],
        calendar: Calendar,
        gridInterval: DateInterval
    ) -> [MonthBar] {
        struct Occurrence {
            let event: CalendarEvent
            let first: Date
            let last: Date
            let key: String
        }

        var occurrences: [Occurrence] = []
        for (index, event) in events.enumerated() {
            let days = EventLayout.coveredDays(start: event.start, end: event.end,
                                               calendar: calendar, clampedTo: gridInterval)
            guard let first = days.first, let last = days.last else { continue }
            occurrences.append(Occurrence(event: event, first: first, last: last, key: "\(event.id)#\(index)"))
        }

        // 시작일 오름차순 → 더 긴 일정 먼저 → 종일 먼저 → 시작 시각 → 제목(안정성).
        // 시작 시각이 제목보다 먼저여야 같은 날 일정이 시간 순서대로 레인에 쌓인다.
        occurrences.sort { a, b in
            if a.first != b.first { return a.first < b.first }
            let aSpan = a.last.timeIntervalSince(a.first)
            let bSpan = b.last.timeIntervalSince(b.first)
            if aSpan != bSpan { return aSpan > bSpan }
            if a.event.isAllDay != b.event.isAllDay { return a.event.isAllDay && !b.event.isAllDay }
            if a.event.start != b.event.start { return a.event.start < b.event.start }
            return a.event.title < b.event.title
        }

        // 그리디 구간 분할: laneLastDay[lane] = 그 레인이 점유한 마지막 날.
        var laneLastDay: [Date] = []
        var bars: [MonthBar] = []
        for occ in occurrences {
            var lane = 0
            while lane < laneLastDay.count && laneLastDay[lane] >= occ.first {
                lane += 1
            }
            if lane == laneLastDay.count {
                laneLastDay.append(occ.last)
            } else {
                laneLastDay[lane] = occ.last
            }
            bars.append(MonthBar(
                id: occ.key,
                eventID: occ.event.id,
                title: occ.event.title.isEmpty ? "(제목 없음)" : occ.event.title,
                colorHex: occ.event.calendarColorHex,
                isAllDay: occ.event.isAllDay,
                lane: lane,
                firstDay: occ.first,
                lastDay: occ.last
            ))
        }
        return bars
    }

    /// 한 주(7칸)의 날짜들에 대해, 그 주와 겹치는 바들을 토막으로 분할.
    public static func segments(
        forWeek weekDays: [Date],
        bars: [MonthBar],
        calendar: Calendar
    ) -> [WeekSegment] {
        guard let weekFirst = weekDays.first, let weekLast = weekDays.last else { return [] }
        var result: [WeekSegment] = []
        for bar in bars {
            let segStart = Swift.max(bar.firstDay, weekFirst)
            let segEnd = Swift.min(bar.lastDay, weekLast)
            guard segStart <= segEnd else { continue }
            let startCol = calendar.dateComponents([.day], from: weekFirst, to: segStart).day ?? 0
            let endCol = calendar.dateComponents([.day], from: weekFirst, to: segEnd).day ?? 0
            result.append(WeekSegment(
                id: "\(bar.id)@\(startCol)",
                bar: bar,
                startColumn: startCol,
                columnSpan: Swift.max(1, endCol - startCol + 1),
                isStart: segStart == bar.firstDay,
                isEnd: segEnd == bar.lastDay
            ))
        }
        return result.sorted { $0.bar.lane < $1.bar.lane }
    }

    /// 한 주에서 maxLanes 이상(숨겨진) 레인에 있는 바를 날짜 칸(0...6)별 개수로 집계 → "+N" 표기용.
    public static func overflowCounts(
        forWeek weekDays: [Date],
        bars: [MonthBar],
        maxLanes: Int,
        calendar: Calendar
    ) -> [Int: Int] {
        guard let weekFirst = weekDays.first, let weekLast = weekDays.last else { return [:] }
        var counts: [Int: Int] = [:]
        for bar in bars where bar.lane >= maxLanes {
            let segStart = Swift.max(bar.firstDay, weekFirst)
            let segEnd = Swift.min(bar.lastDay, weekLast)
            guard segStart <= segEnd else { continue }
            let startCol = calendar.dateComponents([.day], from: weekFirst, to: segStart).day ?? 0
            let endCol = calendar.dateComponents([.day], from: weekFirst, to: segEnd).day ?? 0
            for col in startCol...endCol { counts[col, default: 0] += 1 }
        }
        return counts
    }
}
