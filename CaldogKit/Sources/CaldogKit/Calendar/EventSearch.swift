import Foundation

/// 일정 검색/필터 순수 로직. 제목·메모·위치 키워드 + 캘린더 필터.
public enum EventSearch {
    public static func filter(
        _ events: [CalendarEvent],
        keyword: String = "",
        calendarIDs: Set<String>? = nil,
        allowedEventIDs: Set<String>? = nil
    ) -> [CalendarEvent] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return events.filter { event in
            if let ids = calendarIDs, !ids.contains(event.calendarID) { return false }
            if let allowed = allowedEventIDs, !allowed.contains(event.id) { return false }
            if !kw.isEmpty {
                let haystack = [event.title, event.location ?? "", event.notes ?? ""]
                    .joined(separator: " ")
                    .lowercased()
                if !haystack.contains(kw) { return false }
            }
            return true
        }
        .sorted { $0.start < $1.start }
    }
}
