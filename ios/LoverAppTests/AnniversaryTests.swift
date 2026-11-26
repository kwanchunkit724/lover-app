import XCTest
@testable import Us

final class AnniversaryTests: XCTestCase {

    private func date(_ iso: String, time: String = "00:00:00") -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        return f.date(from: "\(iso) \(time)")!
    }

    private func make(base: String, recur: Anniversary.Recur) -> Anniversary {
        Anniversary(
            id: "a1",
            title: "一齊",
            baseDate: base,
            recur: recur,
            kaomoji: "(´∀｀)",
            emoji: "💕",
            subtitle: nil
        )
    }

    func test_yearly_sameDay_returnsZeroDaysAway() {
        // Bug fix: comparing midnight < "now with time" used to roll forward a year.
        let a = make(base: "2024-05-22", recur: .yearly)
        let today = date("2026-05-22", time: "15:30:00")
        let occ = a.nextOccurrence(today: today)
        XCTAssertEqual(occ.daysAway, 0)
        XCTAssertEqual(occ.ordinal, 2) // 2026 - 2024
    }

    func test_yearly_beforeAnniversary_countsDown() {
        let a = make(base: "2024-05-22", recur: .yearly)
        let today = date("2026-05-20", time: "08:00:00")
        let occ = a.nextOccurrence(today: today)
        XCTAssertEqual(occ.daysAway, 2)
        XCTAssertEqual(occ.ordinal, 2)
    }

    func test_yearly_afterAnniversary_rollsToNextYear() {
        let a = make(base: "2024-05-22", recur: .yearly)
        let today = date("2026-05-23", time: "08:00:00")
        let occ = a.nextOccurrence(today: today)
        // 2026-05-23 → 2027-05-22 = 364 days
        XCTAssertEqual(occ.daysAway, 364)
        XCTAssertEqual(occ.ordinal, 3)
    }

    func test_monthly_sameDay_returnsZero() {
        let a = make(base: "2024-01-15", recur: .monthly)
        let today = date("2026-10-15", time: "22:00:00")
        let occ = a.nextOccurrence(today: today)
        XCTAssertEqual(occ.daysAway, 0)
        XCTAssertNil(occ.ordinal)
    }

    func test_monthly_afterDay_rollsToNextMonth() {
        let a = make(base: "2024-01-15", recur: .monthly)
        let today = date("2026-10-16", time: "10:00:00")
        let occ = a.nextOccurrence(today: today)
        // 2026-10-16 → 2026-11-15 = 30 days
        XCTAssertEqual(occ.daysAway, 30)
    }

    func test_monthly_beforeDay_sameMonth() {
        let a = make(base: "2024-01-28", recur: .monthly)
        let today = date("2026-10-01", time: "09:00:00")
        let occ = a.nextOccurrence(today: today)
        XCTAssertEqual(occ.daysAway, 27)
    }
}
