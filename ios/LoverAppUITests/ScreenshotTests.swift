import XCTest

// Captures the key SwiftUI screens as XCUIScreenshot attachments.
// Codemagic uploads these as build artefacts so the user (developing on
// Windows without SwiftUI Preview) can see the rendered UI after every push.
//
// Add a new test method per screen you want to verify visually.
// Each method must navigate to the screen, settle, then call `snapshot(name:)`.

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestingScreenshotMode", "1"]
        app.launch()
    }

    // 對話 tab — the chat detail view (default landing screen)
    func test_screenshot_chatTab() throws {
        sleep(1)   // allow scroll-to-bottom animation to settle
        snapshot(name: "01-chat")
    }

    // 時間 tab — placeholder until v0.3 builds the real tab
    func test_screenshot_timeTab() throws {
        app.buttons["時間"].firstMatch.tap()
        sleep(1)
        snapshot(name: "02-time")
    }

    // 玩樂 tab — placeholder until v0.5
    func test_screenshot_playTab() throws {
        app.buttons["玩樂"].firstMatch.tap()
        sleep(1)
        snapshot(name: "03-play")
    }

    // 我哋 tab — placeholder until v0.4
    func test_screenshot_usTab() throws {
        app.buttons["我哋"].firstMatch.tap()
        sleep(1)
        snapshot(name: "04-us")
    }

    // Composer + kaomoji picker open
    func test_screenshot_chatKaomojiPicker() throws {
        sleep(1)
        // The kao button is the only image-button labelled "kao" inside the composer.
        // Tap it to open the picker.
        let kaoButtons = app.buttons.matching(identifier: "kao")
        if kaoButtons.count > 0 {
            kaoButtons.firstMatch.tap()
            sleep(1)
        }
        snapshot(name: "05-chat-kaomoji")
    }

    // MARK: - helpers

    private func snapshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
