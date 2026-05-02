import XCTest
@testable import Us

// Tiny smoke test — ensures the target compiles and basic types initialise.
// Real unit tests for crypto, mock data, and view models land in v0.1.5.

final class SmokeTests: XCTestCase {
    func test_themeJbeam_hasExpectedID() {
        XCTAssertEqual(Theme.jbeam.id, "jbeam")
    }

    func test_mockData_messagesNonEmpty() {
        XCTAssertFalse(MockData.messages.isEmpty)
    }

    func test_kaomojiCatalogue_loadsFromBundle() {
        let cat = KaomojiCatalogue.bundled
        XCTAssertGreaterThan(cat.categories.count, 0,
                             "Kaomoji.json must be bundled into Us.app")
        XCTAssertGreaterThan(cat.quick_react.count, 0)
    }
}
