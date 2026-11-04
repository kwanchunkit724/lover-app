import XCTest

// Captures the key SwiftUI screens as XCUIScreenshot attachments.
// `-UITestingScreenshotMode 1` is the offline shell fixture (same as `shell`):
// no Supabase session and no production write. Tab buttons are addressed by
// accessibilityIdentifier because inactive tabs hide their title.

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestingScreenshotMode", "1"]
        app.launch()
    }

    func test_screenshot_chatTab() throws {
        XCTAssertTrue(app.descendants(matching: .any)["tab-chat"].waitForExistence(timeout: 30))
        snapshot(name: "01-chat")
    }

    func test_screenshot_memoryTab() throws {
        let memory = app.descendants(matching: .any)["tab-memory"]
        XCTAssertTrue(memory.waitForExistence(timeout: 30))
        memory.tap()
        sleep(1)
        snapshot(name: "02-memory")
    }

    func test_screenshot_wantTab() throws {
        let want = app.descendants(matching: .any)["tab-want"]
        XCTAssertTrue(want.waitForExistence(timeout: 30))
        want.tap()
        sleep(1)
        snapshot(name: "03-want")
    }

    func test_screenshot_usTab() throws {
        let us = app.descendants(matching: .any)["tab-us"]
        XCTAssertTrue(us.waitForExistence(timeout: 30))
        us.tap()
        sleep(1)
        snapshot(name: "04-us")
    }

    func test_screenshot_chatKaomojiPicker() throws {
        let kao = app.buttons["composer-kaomoji"]
        XCTAssertTrue(kao.waitForExistence(timeout: 15))
        kao.tap()
        sleep(1)
        let sleepChip = app.buttons["kaomoji-category-sleep"]
        if sleepChip.waitForExistence(timeout: 5) {
            if !sleepChip.isHittable {
                app.swipeLeft()
            }
            if sleepChip.isHittable {
                sleepChip.tap()
                sleep(1)
            }
        }
        snapshot(name: "05-chat-kaomoji")
    }

    private func snapshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
