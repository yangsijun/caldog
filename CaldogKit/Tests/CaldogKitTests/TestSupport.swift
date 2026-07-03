import Foundation

enum Fixtures {
    /// DST 없는 결정적 달력(Asia/Seoul, Gregorian).
    static func calendar(firstWeekday: Int = 1) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.firstWeekday = firstWeekday
        c.locale = Locale(identifier: "ko_KR")
        return c
    }

    static func date(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0, _ mm: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hh; comps.minute = mm
        return cal.date(from: comps)!
    }
}
