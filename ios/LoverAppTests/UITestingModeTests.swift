import XCTest
@testable import Us

// The launch hook is the only thing that keeps Simulator smoke off production.
// These cases lock the argument parser so a typo cannot inject a fixture
// and the screenshot value "1" still means the offline shell.

final class UITestingModeTests: XCTestCase {
    func test_mode_isOffWithoutTheFlag() {
        XCTAssertEqual(UITesting.mode(in: ["/Us"]), .off)
        XCTAssertEqual(UITesting.mode(in: ["-UITestingScreenshotMode"]), .off)
        XCTAssertEqual(UITesting.mode(in: ["-UITestingScreenshotMode", "nope"]), .off)
        XCTAssertFalse(UITesting.blocksNetwork(in: []))
    }

    func test_mode_authDoesNotOpenTheShell() {
        let args = ["-UITestingScreenshotMode", "auth"]
        XCTAssertEqual(UITesting.mode(in: args), .auth)
        XCTAssertTrue(UITesting.blocksNetwork(in: args))
    }

    func test_mode_screenshotAndShellAreTheOfflineShell() {
        XCTAssertEqual(UITesting.mode(in: ["-UITestingScreenshotMode", "1"]), .shell)
        XCTAssertEqual(UITesting.mode(in: ["-UITestingScreenshotMode", "shell"]), .shell)
        XCTAssertEqual(UITesting.mode(in: ["-UITestingScreenshotMode", "screenshot"]), .shell)
        XCTAssertNotEqual(UITesting.fixtureUserId, UITesting.fixturePartnerId)
        XCTAssertNotEqual(UITesting.fixtureUserId, UITesting.fixtureCoupleId)
    }
}
