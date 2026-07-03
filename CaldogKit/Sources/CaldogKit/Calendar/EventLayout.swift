import Foundation

/// 일정이 달력 칸에서 어떤 날짜들을 점유하는지 계산하는 순수 로직.
///
/// 앱 월 뷰와 위젯이 동일 규칙을 쓰도록 공유한다(불일치 방지).
/// - 종료 시각은 **배타적**으로 본다: 22:00~익일 00:00 일정은 시작일에만 표시(다음날 미점유).
/// - 여러 날에 진짜로 걸친 일정(예: 6/4~6/6)은 걸친 모든 날에 표시(애플 캘린더 월 뷰 방식).
public enum EventLayout {
    /// 일정이 점유하는 날짜들(각 날의 자정, 전달 `calendar` 기준)을 오름차순으로 반환.
    ///
    /// - Parameters:
    ///   - start: 시작 시각.
    ///   - end: 종료 시각(배타적으로 처리).
    ///   - calendar: 자정 계산에 쓸 달력.
    ///   - range: 주어지면 이 기간과 겹치는 날짜로 클램프(그리드 밖 폭주 방지). `end`는 배타적.
    /// - Returns: 점유 날짜 배열. 0 길이/역전 일정도 최소 시작일 1칸은 보장(단, range 밖이면 빈 배열).
    public static func coveredDays(
        start: Date,
        end: Date,
        calendar: Calendar,
        clampedTo range: DateInterval? = nil
    ) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        // 배타적 종료: 종료가 시작보다 뒤일 때만 1초 차감해 "자정 종료=그날 미점유"를 구현.
        let endReference = end > start ? end.addingTimeInterval(-1) : start
        let endDay = calendar.startOfDay(for: endReference)

        var lower = startDay
        var upper = Swift.max(startDay, endDay)

        if let range {
            let rangeLower = calendar.startOfDay(for: range.start)
            let rangeUpper = calendar.startOfDay(for: range.end.addingTimeInterval(-1))
            lower = Swift.max(lower, rangeLower)
            upper = Swift.min(upper, rangeUpper)
        }

        guard lower <= upper else { return [] }

        var days: [Date] = []
        var cursor = lower
        while cursor <= upper {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
