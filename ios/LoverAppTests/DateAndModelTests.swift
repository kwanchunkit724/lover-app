import XCTest
@testable import Us

final class LocalDateTests: XCTestCase {

    func test_stringRoundTrip_preservesCalendarDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var comps = DateComponents()
        comps.year = 2024; comps.month = 5; comps.day = 22
        comps.hour = 12
        let d = cal.date(from: comps)!
        XCTAssertEqual(LocalDate.string(from: d), "2024-05-22")
        let back = LocalDate.date(from: "2024-05-22")
        XCTAssertNotNil(back)
        XCTAssertEqual(LocalDate.string(from: back!), "2024-05-22")
    }

    func test_displayDate_fromIso() {
        XCTAssertEqual(DisplayDate.from(iso: "2024-05-22"), "2024.05.22")
        XCTAssertEqual(DisplayDate.from(iso: "not-a-date"), "not.a.date")
    }
}

final class TimeFormattingTests: XCTestCase {

    func test_mdString() {
        XCTAssertEqual(TimeFormatting.mdString("2026-05-22"), "5.22")
        XCTAssertEqual(TimeFormatting.mdString("2026-12-01"), "12.1")
        XCTAssertEqual(TimeFormatting.mdString("bad"), "bad")
    }

    func test_weekday_knownDate() {
        // 2024-05-22 was a Wednesday → 三
        XCTAssertEqual(TimeFormatting.weekday("2024-05-22"), "三")
        XCTAssertEqual(TimeFormatting.weekday("2024-05-26"), "日")
    }

    func test_fullString_containsYearAndWeekday() {
        let s = TimeFormatting.fullString("2024-05-22")
        XCTAssertTrue(s.contains("2024"))
        XCTAssertTrue(s.contains("五月"))
        XCTAssertTrue(s.contains("22 日"))
        XCTAssertTrue(s.contains("星期三"))
    }

    func test_daysBetween() {
        XCTAssertEqual(TimeFormatting.daysBetween("2024-05-22", "2024-05-22"), 0)
        XCTAssertEqual(TimeFormatting.daysBetween("2024-05-22", "2024-05-25"), 3)
        XCTAssertEqual(TimeFormatting.daysBetween("2024-05-25", "2024-05-22"), -3)
        XCTAssertEqual(TimeFormatting.daysBetween("bad", "2024-05-22"), 0)
    }
}

final class MessageModelTests: XCTestCase {

    private func msg(
        kind: Message.Kind,
        text: String? = nil,
        caption: String? = nil,
        voiceDurationSec: Int? = nil,
        isDeleted: Bool = false
    ) -> Message {
        Message(
            id: "m1",
            from: "me",
            kind: kind,
            timestamp: "12:00",
            read: false,
            text: text,
            photoSrc: nil,
            caption: caption,
            voiceDurationSec: voiceDurationSec,
            voiceTranscript: nil,
            replyTo: nil,
            reactions: [],
            isEdited: false,
            isDeleted: isDeleted
        )
    }

    func test_previewText_textAndKaomoji() {
        XCTAssertEqual(msg(kind: .text, text: "嗨").previewText, "嗨")
        XCTAssertEqual(msg(kind: .kaomoji, text: "(´∀｀)").previewText, "(´∀｀)")
    }

    func test_previewText_photo() {
        XCTAssertEqual(msg(kind: .photo, caption: "靚景").previewText, "靚景")
        XCTAssertEqual(msg(kind: .photo).previewText, "📷 相片")
    }

    func test_previewText_voiceAndVideo() {
        XCTAssertEqual(msg(kind: .voice, voiceDurationSec: 8).previewText, "🎙 8 秒語音訊息")
        XCTAssertEqual(msg(kind: .video, voiceDurationSec: 15).previewText, "📹 15 秒短片")
    }

    func test_previewText_deletedOverridesKind() {
        XCTAssertEqual(msg(kind: .text, text: "secret", isDeleted: true).previewText, "已撤回嘅訊息")
    }
}

final class EntryModelTests: XCTestCase {

    private func entry(date: String) -> Entry {
        Entry(
            id: "e1",
            date: date,
            time: nil,
            title: "晚餐",
            location: nil,
            proposedBy: "me",
            who: .both,
            tag: .food,
            isSpecial: false,
            notes: nil,
            cover: nil,
            photos: 0,
            voiceClips: 0,
            messages: 0,
            kaomoji: nil,
            reflection: nil,
            onThisDay: false
        )
    }

    func test_isPast_lexicographicIso() {
        let e = entry(date: "2024-05-21")
        XCTAssertTrue(e.isPast(today: "2024-05-22"))
        XCTAssertFalse(e.isPast(today: "2024-05-21"))
        XCTAssertFalse(e.isPast(today: "2024-05-20"))
    }

    func test_isToday() {
        let e = entry(date: "2024-05-22")
        XCTAssertTrue(e.isToday("2024-05-22"))
        XCTAssertFalse(e.isToday("2024-05-23"))
    }

    func test_tag_rawValues_matchDesign() {
        XCTAssertEqual(Entry.Tag.special.rawValue, "特別日子")
        XCTAssertEqual(Entry.Tag.outing.rawValue, "出遊")
        XCTAssertEqual(Entry.Tag.food.rawValue, "食")
        XCTAssertEqual(Entry.Tag.home.rawValue, "屋企")
        XCTAssertEqual(Entry.Tag.walk.rawValue, "散步")
        XCTAssertEqual(Entry.Tag.solo.rawValue, "solo")
    }
}
