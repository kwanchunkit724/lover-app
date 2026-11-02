import XCTest
@testable import Us

@MainActor
final class KKDailyMoodTests: XCTestCase {
    func test_moodTired_codepoints() {
        let mood = DailyMoodLock.moodTired
        let scalars = DailyMoodLock.codepoints(of: mood).map { String(format: "0x%x", $0) }
        XCTAssertEqual(scalars, ["0x6709", "0x5572", "0x6530"])
        XCTAssertEqual(mood, "\u{6709}\u{5572}" + String(UnicodeScalar(0x6530)!))
        XCTAssertNotEqual(mood, "\u{6709}\u{5572}" + String(UnicodeScalar(0x6536)!))
        XCTAssertNotEqual(mood, "\u{6709}\u{5572}" + String(UnicodeScalar(0x652F)!))
        XCTAssertEqual(mood.count, 3)
    }

    func test_sixMoods_whitelist() {
        let labels = DailyMood.allCases.map(\.label)
        XCTAssertEqual(labels, DailyMoodLock.orderedLabels)
        XCTAssertEqual(labels.count, 6)
        for label in labels {
            XCTAssertTrue(DailyMoodLock.isAllowed(label))
            XCTAssertFalse(DailyMoodLock.codepoints(of: label).contains(0x6536))
            XCTAssertFalse(DailyMoodLock.codepoints(of: label).contains(0x652F))
            XCTAssertLessThanOrEqual(label.count, 3)
        }
        XCTAssertEqual(DailyMood.happy.label, "\u{958B}\u{5FC3}")
        XCTAssertEqual(DailyMood.calm.label, "\u{5E73}\u{975C}")
        XCTAssertEqual(DailyMood.low.label, "\u{4F4E}\u{843D}")
        XCTAssertEqual(DailyMood.missYou.label, "\u{639B}\u{4F4F}\u{4F60}")
        XCTAssertEqual(DailyMood.annoyed.label, "\u{6709}\u{5572}\u{7169}")
    }

    func test_moodDay_rollsAt0600HKT() {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let before = parser.date(from: "2026-11-01T21:59:00Z")!
        let atSix = parser.date(from: "2026-11-01T22:00:00Z")!
        XCTAssertEqual(KKTime.moodDayKey(now: before), "2026-11-01")
        XCTAssertEqual(KKTime.moodDayKey(now: atSix), "2026-11-02")
    }

    func test_kaomojiSleepLabel_isU7761() {
        let catalogue = KaomojiCatalogue.bundled
        let sleep = catalogue.categories.first { $0.id == "sleep" }
        let scalars = sleep?.label.unicodeScalars.map(\.value) ?? []
        XCTAssertEqual(scalars, [0x7761])
        XCTAssertEqual(catalogue.categories.count, 8)
        let total = catalogue.categories.reduce(0) { $0 + $1.entries.count }
        XCTAssertEqual(total, 320)
    }

    func test_aiConsume_rejectsEmptyAndLocksAtTen() {
        let store = AIUsageStore()
        store.bind(userId: UUID(), now: Date())
        XCTAssertFalse(store.consume(userText: "   ", memoryItemIds: []))
        XCTAssertTrue(store.consume(userText: "想去行山", memoryItemIds: []))
        for _ in 0..<9 {
            XCTAssertTrue(store.consume(userText: "再試", memoryItemIds: []))
        }
        XCTAssertTrue(store.snapshot.isLocked)
        XCTAssertFalse(store.consume(userText: "第十一", memoryItemIds: []))
    }
}
