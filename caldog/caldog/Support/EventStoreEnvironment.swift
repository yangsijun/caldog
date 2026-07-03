import SwiftUI
import CaldogKit

extension EnvironmentValues {
    /// 일정 원본 게이트웨이. 프리뷰 기본값은 인메모리 Mock.
    @Entry var eventStore: EventStoreGateway = MockEventStore(events: SampleData.events)
}

/// 프리뷰/Mock용 샘플 일정.
enum SampleData {
    static var events: [CalendarEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: dayOffset, to: today)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
        }
        return [
            CalendarEvent(id: "s1", title: "팀 스탠드업", start: at(0, 9), end: at(0, 9, 30),
                          isAllDay: false, calendarID: "cal-work", calendarColorHex: "#E53935"),
            CalendarEvent(id: "s2", title: "점심 약속", start: at(0, 12), end: at(0, 13),
                          isAllDay: false, calendarID: "cal-personal", calendarColorHex: "#1E88E5"),
            CalendarEvent(id: "s3", title: "치과", start: at(2, 15), end: at(2, 16),
                          isAllDay: false, calendarID: "cal-personal", calendarColorHex: "#1E88E5"),
            CalendarEvent(id: "s4", title: "프로젝트 마감", start: at(5, 0), end: at(6, 0),
                          isAllDay: true, calendarID: "cal-work", calendarColorHex: "#E53935"),
        ]
    }
}
