import Foundation

/// 사용자 설정(주 시작 요일)을 반영한 `Calendar` 생성.
public enum CalendarFactory {
    public static func calendar(firstWeekday: Int, base: Calendar = .current) -> Calendar {
        var c = base
        c.firstWeekday = min(7, max(1, firstWeekday))
        return c
    }
}

/// 보조 로컬 알림의 발사 시각 계산(순수).
public enum NotificationPlan {
    /// 이벤트 시작 `minutesBefore`분 전 발사 시각. 이미 지난 시각이면 nil.
    public static func fireDate(eventStart: Date, minutesBefore: Int, now: Date) -> Date? {
        let fire = eventStart.addingTimeInterval(-Double(minutesBefore) * 60)
        return fire > now ? fire : nil
    }
}
