import XCTest
@testable import Us

@MainActor
final class AIExpandMappingTests: XCTestCase {
    private let leakedNote = "quota_consumed; wire Gemini Edge for real plan output"

    func test_screenshotStubDoesNotConsumeOrLeak() {
        let store = AIUsageStore()
        store.bind(userId: UUID())
        let decision = AIExpandMapping.decide(
            ok: true,
            status: "stub",
            note: leakedNote,
            plan: nil,
            text: nil,
            reportedUsed: 1,
            period: "2026-11"
        )
        let outcome = store.applyServer(decision)
        XCTAssertFalse(outcome.ok)
        XCTAssertFalse(decision.succeeded)
        XCTAssertNil(decision.used)
        XCTAssertFalse(decision.exhaustsQuota)
        XCTAssertEqual(store.snapshot.used, 0)
        XCTAssertFalse(store.snapshot.isLocked)
        XCTAssertEqual(AIExpandMapping.Button.title(didConsume: outcome.ok), "展開（扣 1 次）")
        XCTAssertFalse(AIExpandMapping.Button.isDisabled(didConsume: outcome.ok, quotaLocked: store.snapshot.isLocked))
        assertFriendly(outcome.message)
        XCTAssertFalse(outcome.message.contains("次數已扣"))
    }

    func test_unavailableResponseKeepsPreviousCount() {
        let store = AIUsageStore()
        store.bind(userId: UUID())
        let first = store.applyServer(AIExpandMapping.decide(
            ok: true,
            status: "ok",
            note: nil,
            plan: "今晚去食拉麵",
            text: nil,
            reportedUsed: 1,
            period: "2026-11"
        ))
        XCTAssertTrue(first.ok)
        XCTAssertEqual(first.message, "今晚去食拉麵")
        XCTAssertEqual(store.snapshot.used, 1)
        XCTAssertTrue(AIExpandMapping.Button.isDisabled(didConsume: true, quotaLocked: false))

        let failed = store.applyServer(AIExpandMapping.decide(
            ok: false,
            status: "unavailable",
            note: leakedNote,
            plan: nil,
            text: nil,
            reportedUsed: 2,
            period: "2026-11"
        ))
        XCTAssertFalse(failed.ok)
        XCTAssertEqual(store.snapshot.used, 1)
        XCTAssertEqual(failed.message, AIExpandMapping.unavailableMessage)
        assertFriendly(failed.message)
    }

    func test_missingPlanIsNotSuccess() {
        let decision = AIExpandMapping.decide(
            ok: true,
            status: "ok",
            note: leakedNote,
            plan: leakedNote,
            text: nil,
            reportedUsed: 4,
            period: "2026-11"
        )
        XCTAssertFalse(decision.succeeded)
        XCTAssertNil(decision.used)
        assertFriendly(decision.userMessage)

        let notePlan = AIExpandMapping.decide(
            ok: true,
            status: nil,
            note: "今晚去食拉麵",
            plan: nil,
            text: nil,
            reportedUsed: 2,
            period: "2026-11"
        )
        XCTAssertTrue(notePlan.succeeded)
        XCTAssertEqual(notePlan.userMessage, "今晚去食拉麵")
        XCTAssertEqual(notePlan.used, 2)
    }

    func test_thrownCodesStayOffScreenAndQuotaLockIsExplicit() {
        let leaked = NSError(
            domain: "Postgrest",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "kk_ai_consume_and_run",
                "message": leakedNote
            ]
        )
        let stub = AIExpandMapping.decision(forThrown: leaked)
        XCTAssertFalse(stub.succeeded)
        XCTAssertFalse(stub.exhaustsQuota)
        XCTAssertNil(stub.used)
        assertFriendly(stub.userMessage)

        let exhausted = AIExpandMapping.decision(forThrownRaw: "ai_quota_exhausted")
        XCTAssertFalse(exhausted.succeeded)
        XCTAssertTrue(exhausted.exhaustsQuota)
        XCTAssertEqual(exhausted.used, KKAIQuota.monthlyCap)
        assertFriendly(exhausted.userMessage)

        let store = AIUsageStore()
        store.bind(userId: UUID())
        let outcome = store.applyServer(exhausted)
        XCTAssertFalse(outcome.ok)
        XCTAssertEqual(store.snapshot.used, KKAIQuota.monthlyCap)
        XCTAssertTrue(store.snapshot.isLocked)
        XCTAssertTrue(AIExpandMapping.Button.isDisabled(didConsume: false, quotaLocked: true))
        XCTAssertEqual(AIExpandMapping.Button.title(didConsume: false), "展開（扣 1 次）")
    }

    func test_emptyInputDoesNotDeduct() async {
        let store = AIUsageStore()
        store.bind(userId: UUID())
        let outcome = await store.consumeOnServer(userText: "   ", memories: [])
        XCTAssertFalse(outcome.ok)
        XCTAssertEqual(store.snapshot.used, 0)
        XCTAssertEqual(outcome.message, AIExpandMapping.emptyInputMessage)
        assertFriendly(outcome.message)
    }

    func test_applyingLeavesCountAloneUntilARealPlan() {
        let before = AIExpandMapping.UsageSnapshot(period: "2026-11", used: 3)
        let stub = AIExpandMapping.decide(
            ok: nil,
            status: "stub",
            note: leakedNote,
            plan: nil,
            text: nil,
            reportedUsed: 4,
            period: "2026-11"
        )
        XCTAssertEqual(AIExpandMapping.applying(stub, to: before), before)

        let plan = AIExpandMapping.decide(
            ok: true,
            status: "done",
            note: nil,
            plan: nil,
            text: "聽日見",
            reportedUsed: 4,
            period: "2026-11"
        )
        XCTAssertEqual(
            AIExpandMapping.applying(plan, to: before),
            AIExpandMapping.UsageSnapshot(period: "2026-11", used: 4)
        )
        XCTAssertEqual(plan.userMessage, "聽日見")
    }

    private func assertFriendly(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lowered = text.lowercased()
        let banned = [
            "quota_consumed", "gemini", "wire", "kk_ai", "edge", "stub",
            "rpc", "unavailable", "_"
        ]
        for token in banned {
            XCTAssertFalse(lowered.contains(token), "\(text) contains \(token)", file: file, line: line)
        }
        XCTAssertTrue(
            text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) },
            text,
            file: file,
            line: line
        )
    }
}
