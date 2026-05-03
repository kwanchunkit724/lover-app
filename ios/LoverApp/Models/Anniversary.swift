import Foundation

// Mirrors D.anniversaries in design-import/data.js.
// Recurring countdowns surfaced in time + 我哋 tabs.

struct Anniversary: Identifiable, Hashable {
    enum Recur: String, Codable { case yearly, monthly }

    let id: String
    let title: String
    let baseDate: String          // "yyyy-MM-dd"
    let recur: Recur
    let kaomoji: String?
    let emoji: String?
    let subtitle: String?

    /// Compute the next occurrence date and how many days from `today`.
    func nextOccurrence(today: Date = Date()) -> (date: Date, daysAway: Int, ordinal: Int?) {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        let base = formatter.date(from: baseDate) ?? today

        let baseComponents = calendar.dateComponents([.year, .month, .day], from: base)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

        var nextComponents = DateComponents()
        nextComponents.year = todayComponents.year
        nextComponents.day = baseComponents.day

        switch recur {
        case .yearly:
            nextComponents.month = baseComponents.month
        case .monthly:
            nextComponents.month = todayComponents.month
        }

        var next = calendar.date(from: nextComponents) ?? today
        if next < today {
            switch recur {
            case .yearly:
                nextComponents.year = (todayComponents.year ?? 0) + 1
            case .monthly:
                nextComponents.month = (todayComponents.month ?? 0) + 1
            }
            next = calendar.date(from: nextComponents) ?? today
        }

        let days = calendar.dateComponents([.day], from: today, to: next).day ?? 0
        let ordinal: Int? = recur == .yearly
            ? (calendar.component(.year, from: next) - calendar.component(.year, from: base))
            : nil
        return (next, days, ordinal)
    }
}
