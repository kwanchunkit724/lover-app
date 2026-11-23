import XCTest
@testable import Us

/// Partner-row decoding and the chat lock banner. No Keychain, no Supabase.
final class E2EEChannelTests: XCTestCase {

    func test_timestamp_parsesPostgresMicroseconds() {
        let date = PairingTimestamp.parse("2024-05-22T12:00:00.123456+00:00")
        XCTAssertNotNil(date)
        let plain = PairingTimestamp.parse("2024-05-22T12:00:00Z")
        XCTAssertNotNil(plain)
        XCTAssertNil(PairingTimestamp.parse("not-a-date"))
        XCTAssertNil(PairingTimestamp.parse("   "))
    }

    func test_partnerRow_keepsPublicKeyWhenLastSeenIsGarbage() throws {
        let row = try decodePartner("""
        {
          "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "my_name": "阿 B",
          "partner_name": "阿 A",
          "anniversary_iso": "2020-01-01",
          "theme_id": "jbeam",
          "public_key": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
          "last_seen_at": "not-a-date"
        }
        """)
        XCTAssertEqual(row.publicKey, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        XCTAssertNil(row.lastSeenAt)
        XCTAssertEqual(PairingService.classifyPartnerKey(row), .present)
    }

    func test_partnerRow_nullPublicKeyIsNotPresent() throws {
        let row = try decodePartner("""
        {
          "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "my_name": "阿 B",
          "partner_name": "阿 A",
          "anniversary_iso": "2020-01-01",
          "theme_id": "jbeam",
          "public_key": null,
          "last_seen_at": "2024-05-22T12:00:00.123456+00:00"
        }
        """)
        XCTAssertNil(row.publicKey)
        XCTAssertNotNil(row.lastSeenAt)
        XCTAssertEqual(PairingService.classifyPartnerKey(row), .nullKey)
    }

    func test_partnerRow_blankPublicKeyIsNullKey() throws {
        let row = try decodePartner("""
        {
          "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "my_name": "阿 B",
          "public_key": "   "
        }
        """)
        XCTAssertNil(row.publicKey)
        XCTAssertEqual(row.partnerName, "")
        XCTAssertEqual(PairingService.classifyPartnerKey(row), .nullKey)
    }

    func test_partnerRow_missingPublicKeyIsNullKey() throws {
        let row = try decodePartner("""
        {
          "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "my_name": "阿 B"
        }
        """)
        XCTAssertNil(row.publicKey)
        XCTAssertEqual(PairingService.classifyPartnerKey(row), .nullKey)
        XCTAssertEqual(PairingService.classifyPartnerKey(nil), .missingRow)
    }

    func test_channelStatus_mapsBlockersWithoutDebugDump() {
        let samples: [E2EEChannelStatus] = [
            .resolve(partnerKey: .unknown, ownKeyReady: true, ownKeyOnServer: nil, prepareFailed: false),
            .resolve(partnerKey: .nullKey, ownKeyReady: true, ownKeyOnServer: true, prepareFailed: false),
            .resolve(partnerKey: .missingRow, ownKeyReady: true, ownKeyOnServer: true, prepareFailed: false),
            .resolve(partnerKey: .unreadable, ownKeyReady: true, ownKeyOnServer: true, prepareFailed: false),
            .resolve(partnerKey: .present, ownKeyReady: true, ownKeyOnServer: true, prepareFailed: false),
            .resolve(partnerKey: .present, ownKeyReady: true, ownKeyOnServer: true, prepareFailed: true),
            .resolve(partnerKey: .present, ownKeyReady: false, ownKeyOnServer: true, prepareFailed: false),
            .resolve(partnerKey: .nullKey, ownKeyReady: true, ownKeyOnServer: false, prepareFailed: true),
        ]
        XCTAssertEqual(samples[1], .waitingForPartnerKey)
        XCTAssertEqual(samples[2], .partnerMissing)
        XCTAssertEqual(samples[3], .partnerUnreadable)
        XCTAssertEqual(samples[4], .preparing)
        XCTAssertEqual(samples[5], .keyRejected)
        XCTAssertEqual(samples[6], .ownKeyUnavailable)
        XCTAssertEqual(samples[7], .serverOmittedKey)

        let banned = ["publicKey", "public_key", "NIL", "nil", "❌", "last error", "chars"]
        for status in samples {
            let text = status.title + " " + status.detail
            for token in banned {
                XCTAssertFalse(
                    text.localizedCaseInsensitiveContains(token),
                    "\(status) contains \(token): \(text)"
                )
            }
            XCTAssertFalse(status.detail.isEmpty)
            XCTAssertTrue(status.title.contains("加密通道準備緊"))
        }
    }

    private func decodePartner(_ json: String) throws -> PairingService.PartnerRow {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(PairingService.PartnerRow.self, from: data)
    }
}
