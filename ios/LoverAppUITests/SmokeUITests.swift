import XCTest

// Simulator smoke for the KK shell. Every launch passes
// `-UITestingScreenshotMode` so AuthService never reads a Supabase session
// and the app never sends a production write.
//
// auth  — cold launch lands on SignInView. No guest control.
// shell — in-memory signed-in fixture, four tabs, bundled sleep kaomoji.
// A real email OTP is not used.

final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_coldLaunch_authScreenHasNoGuest() throws {
        let app = launch("auth")
        XCTAssertEqual(app.state, .runningForeground)

        let subtitle = app.staticTexts["auth-subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 30), "auth screen did not appear")
        XCTAssertTrue(subtitle.label.contains("無訪客模式"))

        let email = app.buttons["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        XCTAssertTrue(email.label.contains("用 Email 登入"), "email button label was \(email.label)")

        let apple = app.descendants(matching: .any)["auth-apple"]
        if !apple.waitForExistence(timeout: 5) {
            let appleByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple")).firstMatch
            XCTAssertTrue(appleByLabel.waitForExistence(timeout: 5), "Sign in with Apple was not on the auth screen")
        }

        let guestLabels = [
            "訪客", "以訪客繼續", "以訪客身份繼續", "訪客登入", "匿名登入",
            "Guest", "Continue as Guest", "Sign in anonymously", "auth-guest"
        ]
        for name in guestLabels {
            XCTAssertFalse(app.buttons[name].exists, "guest control present: \(name)")
        }
        let guestButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "訪客"))
        XCTAssertEqual(guestButtons.count, 0)

        XCTAssertFalse(app.buttons["tab-chat"].exists, "auth launch entered the tab shell")
        snapshot(app, name: "smoke-auth")
    }

    func test_shell_fourTabsPresent_oldTabsAbsent() throws {
        let app = launch("shell")
        let expected = [
            ("tab-chat", "對話"),
            ("tab-memory", "記憶空間"),
            ("tab-want", "想你知道"),
            ("tab-us", "我哋")
        ]

        for (identifier, label) in expected {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 30), "missing \(identifier)")
            XCTAssertEqual(tab.label, label)
        }

        for identifier in ["tab-chat", "tab-memory", "tab-want", "tab-us"] {
            XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1, identifier)
        }

        for gone in ["tab-time", "tab-play", "tab-activities", "tab-date", "時間", "玩樂", "時間簿", "約會活動"] {
            XCTAssertFalse(app.buttons[gone].exists, "old tab still present: \(gone)")
        }
        // 約會 is a Memory Space filter chip, not a tab. It must not be a
        // button on the chat shell.
        XCTAssertFalse(app.buttons["約會"].exists)

        XCTAssertTrue(app.buttons["composer-kaomoji"].waitForExistence(timeout: 10))
        snapshot(app, name: "smoke-tab-chat")

        app.buttons["tab-memory"].tap()
        XCTAssertTrue(app.staticTexts["記憶空間"].waitForExistence(timeout: 8))
        snapshot(app, name: "smoke-tab-memory")

        app.buttons["tab-want"].tap()
        XCTAssertTrue(app.staticTexts["想你知道"].waitForExistence(timeout: 8))
        snapshot(app, name: "smoke-tab-want")

        app.buttons["tab-us"].tap()
        XCTAssertTrue(app.staticTexts["我哋"].waitForExistence(timeout: 8))
        snapshot(app, name: "smoke-tab-us")

        app.buttons["tab-chat"].tap()
        XCTAssertTrue(app.buttons["composer-kaomoji"].waitForExistence(timeout: 8))

        for gone in ["tab-time", "tab-play", "tab-activities", "時間", "玩樂"] {
            XCTAssertFalse(app.buttons[gone].exists, "old tab appeared after navigation: \(gone)")
        }
    }

    func test_shell_sleepKaomojiReachable() throws {
        let app = launch("shell")
        let kao = app.buttons["composer-kaomoji"]
        XCTAssertTrue(kao.waitForExistence(timeout: 30))
        kao.tap()

        let search = app.textFields["kaomoji-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 8), "kaomoji picker did not open")

        let sleep = app.buttons["kaomoji-category-sleep"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 8), "sleep category missing from the bundled catalogue")
        XCTAssertEqual(sleep.label, "睡")
        reveal(sleep, in: app)
        sleep.tap()

        let entry = app.buttons["kk-kaomoji-0"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        let showedSleep = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "zzZ"),
            object: entry
        )
        XCTAssertEqual(XCTWaiter().wait(for: [showedSleep], timeout: 8), .completed,
                       "sleep category did not show a bundled sleep kaomoji")
        snapshot(app, name: "smoke-sleep-kaomoji")
    }

    // MARK: - helpers

    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingScreenshotMode", mode]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable { return }
        let strip = categoryStrip(app)
        for _ in 0..<6 {
            if strip.exists { strip.swipeLeft() } else { app.swipeLeft() }
            if element.isHittable { return }
        }
        for _ in 0..<6 {
            if strip.exists { strip.swipeRight() } else { app.swipeRight() }
            if element.isHittable { return }
        }
    }

    private func categoryStrip(_ app: XCUIApplication) -> XCUIElement {
        let scroll = app.scrollViews["kaomoji-categories"]
        if scroll.exists { return scroll }
        return app.otherElements["kaomoji-categories"]
    }

    private func snapshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
