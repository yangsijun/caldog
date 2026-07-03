import Foundation

/// 반복 규칙을 사람이 읽는 한국어 문구로 변환.
public enum RecurrenceFormatter {
    public static func describe(_ recurrence: SimpleRecurrence?) -> String {
        guard let r = recurrence else { return "반복 안 함" }
        let unit: String
        switch r.frequency {
        case .daily: unit = "일"
        case .weekly: unit = "주"
        case .monthly: unit = "개월"
        case .yearly: unit = "년"
        }
        let base = r.interval == 1 ? "매\(unit)" : "\(r.interval)\(unit)마다"
        if let end = r.endDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy.MM.dd"
            return "\(base) (\(df.string(from: end))까지)"
        }
        return base
    }
}
