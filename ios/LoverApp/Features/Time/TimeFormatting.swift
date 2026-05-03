import Foundation

// Date / weekday formatting helpers shared across the time tab.
// Mirrors the helpers at the top of design-import/screens.jsx.

enum TimeFormatting {
    static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    static let monthsTC = [
        "一月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "十一月", "十二月"
    ]

    /// "yyyy-MM-dd" → "M.d"
    static func mdString(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return iso }
        return "\(m).\(d)"
    }

    /// "yyyy-MM-dd" → "2026 · 五月 2 日 · 星期六"
    static func fullString(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return iso }
        let cal = Calendar(identifier: .gregorian)
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let w = cal.component(.weekday, from: date) - 1   // 1-based → 0-based
        return "\(y) · \(monthsTC[m - 1]) \(d) 日 · 星期\(weekdays[w])"
    }

    /// "yyyy-MM-dd" → weekday char ("日"/"一"/...)
    static func weekday(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let cal = Calendar(identifier: .gregorian)
        let w = cal.component(.weekday, from: date) - 1
        return weekdays[w]
    }

    static func parseDate(_ iso: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        return f.date(from: iso)
    }

    static func daysBetween(_ start: String, _ end: String) -> Int {
        guard let a = parseDate(start), let b = parseDate(end) else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
