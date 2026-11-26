import XCTest
@testable import Us

final class PairingCodeTests: XCTestCase {

    func test_sanitize_stripsNonDigitsAndCapsAtSix() {
        XCTAssertEqual(PairingCode.sanitize("12ab34cd56ef78"), "123456")
        XCTAssertEqual(PairingCode.sanitize("999"), "999")
        XCTAssertEqual(PairingCode.sanitize(""), "")
        XCTAssertEqual(PairingCode.sanitize("1 2 3-4.5_6"), "123456")
        XCTAssertEqual(PairingCode.sanitize("abcdef"), "")
    }

    func test_isValid_requiresExactlySixDigits() {
        XCTAssertTrue(PairingCode.isValid("000000"))
        XCTAssertTrue(PairingCode.isValid("123456"))
        XCTAssertFalse(PairingCode.isValid("12345"))
        XCTAssertFalse(PairingCode.isValid("1234567"))
        XCTAssertFalse(PairingCode.isValid("12a456"))
        XCTAssertFalse(PairingCode.isValid(""))
        XCTAssertFalse(PairingCode.isValid(" 123456 "))
    }

    func test_secondsRemaining_floorsAtZero() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let future = now.addingTimeInterval(125)
        XCTAssertEqual(PairingCode.secondsRemaining(until: future, now: now), 125)
        XCTAssertEqual(PairingCode.secondsRemaining(until: now.addingTimeInterval(-10), now: now), 0)
    }

    func test_ttl_isTenMinutes() {
        XCTAssertEqual(PairingCode.ttlSeconds, 600)
    }

    func test_couple_partnerId() throws {
        let a = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let b = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let json = """
        {
          "id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
          "user_a_id": "\(a.uuidString)",
          "user_b_id": "\(b.uuidString)",
          "paired_at": "2024-05-22T12:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let couple = try decoder.decode(PairingService.Couple.self, from: json)
        XCTAssertEqual(couple.partnerId(forMe: a), b)
        XCTAssertEqual(couple.partnerId(forMe: b), a)
        XCTAssertNil(couple.partnerId(forMe: UUID()))
    }
}
