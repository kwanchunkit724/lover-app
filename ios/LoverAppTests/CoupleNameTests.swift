import XCTest
@testable import Us

final class CoupleNameTests: XCTestCase {
    func test_defaultsAreNotDisplayNames() {
        let bothDefaults = CoupleNames.identity(
            myName: "我",
            partnerMyName: "我",
            localPartnerName: "對方"
        )
        XCTAssertEqual(bothDefaults.title, "… & …")
        XCTAssertNotEqual(bothDefaults.title, "我 & 我")
        XCTAssertEqual(bothDefaults.meInitial, "…")
        XCTAssertEqual(bothDefaults.partnerInitial, "…")
        XCTAssertNil(CoupleNames.persistable("我"))
        XCTAssertNil(CoupleNames.persistable("對方"))
        XCTAssertNil(CoupleNames.persistable("  我  "))
        XCTAssertNil(CoupleNames.persistable(""))
        XCTAssertNil(CoupleNames.persistable("…"))
    }

    func test_screenshot_localKitBeatsServerDefault() {
        let card = CoupleNames.identity(
            myName: "kit",
            partnerMyName: "我",
            localPartnerName: "對方"
        )
        XCTAssertEqual(card.meName, "kit")
        XCTAssertEqual(card.meInitial, "k")
        XCTAssertEqual(card.partnerName, "…")
        XCTAssertEqual(card.partnerInitial, "…")
        XCTAssertEqual(card.title, "kit & …")
        XCTAssertFalse(card.title.contains("我"))
    }

    func test_localNicknameShowsUntilPartnerSavesRealName() {
        let waiting = CoupleNames.identity(
            myName: "kit",
            partnerMyName: "我",
            localPartnerName: "阿明"
        )
        XCTAssertEqual(waiting.title, "kit & 阿明")
        XCTAssertEqual(waiting.partnerInitial, "阿")

        let saved = CoupleNames.identity(
            myName: "kit",
            partnerMyName: "阿明",
            localPartnerName: "舊名"
        )
        XCTAssertEqual(saved.partnerName, "阿明")
        XCTAssertEqual(saved.meInitial, "k")
        XCTAssertEqual(saved.partnerInitial, "阿")
    }

    func test_blankRemoteFallsThroughToLocalName() {
        let card = CoupleNames.identity(
            myName: "kit",
            partnerMyName: "",
            localPartnerName: "阿明"
        )
        XCTAssertEqual(card.partnerName, "阿明")
        XCTAssertEqual(
            CoupleNames.identity(myName: nil, partnerMyName: nil, localPartnerName: nil).title,
            "… & …"
        )
    }

    func test_appleGivenNameFillsPlaceholderOnly() {
        XCTAssertEqual(
            CoupleNames.adoptingAppleName(myName: "我", givenName: "kit", familyName: "Chan", nickname: nil),
            "kit"
        )
        XCTAssertEqual(
            CoupleNames.adoptingAppleName(myName: "kit", givenName: "Other", familyName: "Chan", nickname: "阿明"),
            "kit"
        )
        XCTAssertEqual(
            CoupleNames.adoptingAppleName(myName: "我", givenName: " ", familyName: nil, nickname: "阿明"),
            "阿明"
        )
        XCTAssertEqual(
            CoupleNames.adoptingAppleName(myName: "我", givenName: nil, familyName: "Chan", nickname: nil),
            "Chan"
        )
    }

    func test_rejectionMessagesStayCantonese() {
        XCTAssertEqual(CoupleNames.rejection(of: "   "), .empty)
        XCTAssertEqual(CoupleNames.rejection(of: "對方"), .placeholder)
        XCTAssertEqual(CoupleNames.rejection(of: String(repeating: "名", count: 41)), .tooLong)
        XCTAssertNil(CoupleNames.rejection(of: "kit"))
        XCTAssertEqual(CoupleNames.persistable(String(repeating: "名", count: 40))?.count, 40)
        for rejection in [CoupleNames.Rejection.empty, .placeholder, .tooLong] {
            let message = CoupleNames.message(for: rejection)
            XCTAssertFalse(message.contains("_"))
            XCTAssertTrue(message.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) })
        }
    }

    func test_upsertSendsRealNameAndNullAnniversary() throws {
        let profile = UserProfile(
            myName: "kit",
            partnerName: "阿明",
            anniversaryISO: "",
            themeId: "jbeam",
            completedAt: Date(timeIntervalSince1970: 0)
        )
        let row = UserProfileUpsert(
            userId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            profile: profile,
            publicKey: "public-key"
        )
        let object = try json(row)
        XCTAssertEqual(object["my_name"] as? String, "kit")
        XCTAssertEqual(object["partner_name"] as? String, "阿明")
        XCTAssertTrue(object["anniversary_iso"] is NSNull)
        XCTAssertFalse(object.values.contains { ($0 as? String) == "" })
    }

    func test_upsertKeepsRealAnniversaryAndDoesNotInventName() throws {
        let dated = UserProfile(
            myName: "kit",
            partnerName: "對方",
            anniversaryISO: "2025-12-08",
            themeId: "jbeam",
            completedAt: Date(timeIntervalSince1970: 0)
        )
        let object = try json(UserProfileUpsert(
            userId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            profile: dated,
            publicKey: "public-key"
        ))
        XCTAssertEqual(object["anniversary_iso"] as? String, "2025-12-08")
        XCTAssertEqual(object["partner_name"] as? String, "對方")

        let placeholder = UserProfile(
            myName: "我",
            partnerName: "對方",
            anniversaryISO: "",
            themeId: "jbeam",
            completedAt: Date(timeIntervalSince1970: 0)
        )
        let fallback = try json(UserProfileUpsert(
            userId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            profile: placeholder,
            publicKey: "public-key"
        ))
        XCTAssertEqual(fallback["my_name"] as? String, "我")
        XCTAssertNil(CoupleNames.persistable(placeholder.myName))
    }

    private func json(_ row: UserProfileUpsert) throws -> [String: Any] {
        let data = try JSONEncoder().encode(row)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
