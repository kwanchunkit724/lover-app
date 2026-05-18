import Foundation

// Direct port of design-import/data.js. v1.5.1: scoped DOWN to PREVIEW /
// TEST use ONLY. Anything that was a real production fallback was stripped
// in v1.5.1. Feature catalogs (activities, date cards, quiz questions) were
// moved to Core/Catalogs.swift since those are static feature definitions,
// not mock user data.
//
// Audit rule: `MockData.*` may only be referenced inside `#Preview { … }`
// macros and `LoverAppTests`. Any reference from a real screen = bug.

enum MockData {
    static let me = Person.mockMe
    static let partner = Person.mockPartner

    /// Anchored to 2026-05-02 to match data.js's TODAY_ISO. Lets the mock data
    /// produce stable past/upcoming/today buckets in previews and on TestFlight.
    static let todayISO = "2026-05-02"
    static let todayDateString = "5月2日 · 星期六"

    /// Couple base — mirrors design-import/screens.jsx Profile (`daysBetween('2024-05-22', TODAY)`).
    static let togetherSinceISO = "2024-05-22"

    static let quickReact = ["(♡˙︶˙♡)", "(≧▽≦)", "(╥﹏╥)", "(¬‿¬)", "(⊙_⊙)", "(っ´ω`c)"]

    static let messages: [Message] = [
        .init(id: "1", from: "michel", kind: .text, timestamp: "08:42", read: true,
              text: "早安 (´｡• ω •｡`)"),
        .init(id: "2", from: "michel", kind: .text, timestamp: "08:42", read: true,
              text: "夢到我哋去咗京都食雪糕"),
        .init(id: "3", from: "kit", kind: .text, timestamp: "08:51", read: true,
              text: "(◕‿◕) 我都想去"),
        .init(id: "4", from: "kit", kind: .text, timestamp: "08:51", read: true,
              text: "今晚記得六點半西營盤地鐵口見",
              reactions: [.init(from: "michel", kao: "(♡˙︶˙♡)")]),
        .init(id: "5", from: "michel", kind: .photo, timestamp: "09:14", read: true,
              photoSrc: "morning-coffee", caption: "今朝嘅咖啡 ☕"),
        .init(id: "6", from: "kit", kind: .text, timestamp: "09:16", read: true,
              text: "靚！你拉花越嚟越叻 (≧▽≦)"),
        .init(id: "7", from: "michel", kind: .voice, timestamp: "12:30", read: true,
              voiceDurationSec: 8, voiceTranscript: "中午食緊嗰個沙律真係好食"),
        .init(id: "8", from: "kit", kind: .text, timestamp: "12:32", read: true,
              text: "哈哈我估到你會錄",
              replyTo: .init(messageID: "7", kind: .voice, preview: "0:08 語音訊息")),
        .init(id: "9", from: "michel", kind: .text, timestamp: "17:58", read: true,
              text: "六點半見 (´♡‿♡`)"),
        .init(id: "10", from: "kit", kind: .text, timestamp: "18:24", read: false,
              text: "行緊嚟"),
    ]

    // MARK: - Entries (time tab)
    // 1:1 mirror of data.js D.entries. Preview-only after v1.5.1.

    static let entries: [Entry] = [
        // ── UPCOMING ──
        Entry(id: "e_today1", date: "2026-05-02", time: "18:30",
              title: "西營盤食晚飯", location: "Bistro 1968",
              proposedBy: "kit", who: .both, tag: .food, isSpecial: false,
              notes: "記得訂位 · 我之前 mark 咗想試",
              cover: nil, photos: 0, voiceClips: 0, messages: 0,
              kaomoji: nil, reflection: nil, onThisDay: false),
        Entry(id: "e_today2", date: "2026-05-02", time: "21:00",
              title: "睇戲：Past Lives", location: "Broadway Cinema",
              proposedBy: "michel", who: .both, tag: .outing, isSpecial: false,
              notes: nil,
              cover: nil, photos: 0, voiceClips: 0, messages: 0,
              kaomoji: nil, reflection: nil, onThisDay: false),
        Entry(id: "e_w1", date: "2026-05-04", time: "14:00",
              title: "Michel 牙醫", location: nil,
              proposedBy: "michel", who: .theirs, tag: .solo, isSpecial: false,
              notes: nil,
              cover: nil, photos: 0, voiceClips: 0, messages: 0,
              kaomoji: nil, reflection: nil, onThisDay: false),
        Entry(id: "e_w2", date: "2026-05-07", time: "19:30",
              title: "行山：龍脊", location: "石澳",
              proposedBy: "kit", who: .both, tag: .outing, isSpecial: false,
              notes: "帶水同零食",
              cover: nil, photos: 0, voiceClips: 0, messages: 0,
              kaomoji: nil, reflection: nil, onThisDay: false),
        Entry(id: "e_anniv", date: "2026-05-22", time: "19:00",
              title: "我哋兩週年 ♡", location: "TBD",
              proposedBy: "kit", who: .both, tag: .special, isSpecial: true,
              notes: "兩個人一齊諗去邊",
              cover: nil, photos: 0, voiceClips: 0, messages: 0,
              kaomoji: nil, reflection: nil, onThisDay: false),

        // ── PAST · enriched with reflection + media counts ──
        Entry(id: "m_recent", date: "2026-05-01", time: "19:00",
              title: "屋企煮意粉", location: "我哋屋企",
              proposedBy: "kit", who: .both, tag: .home, isSpecial: false, notes: nil,
              cover: "pasta", photos: 5, voiceClips: 0, messages: 28,
              kaomoji: "(っ˘ڡ˘ς)",
              reflection: Reflection(from: "kit",
                                     text: "你話我落鹽落多咗 (¬‿¬) 但係你食晒成碟",
                                     kaomoji: "(っ´ω`c)"),
              onThisDay: false),
        Entry(id: "m3", date: "2026-04-12", time: "10:30",
              title: "南丫島一日遊", location: "南丫島",
              proposedBy: "kit", who: .both, tag: .outing, isSpecial: false, notes: nil,
              cover: "lamma", photos: 12, voiceClips: 3, messages: 67,
              kaomoji: "(≧▽≦)",
              reflection: Reflection(from: "michel",
                                     text: "搭船嗰陣風好大，你頭髮好亂但好得意 (´♡‿♡`)",
                                     kaomoji: "(≧▽≦)"),
              onThisDay: false),
    ]

    // MARK: - Anniversaries
    // Mirrors data.js D.anniversaries — yearly + monthly recurrence.
    // Preview-only after v1.5.1.

    static let anniversaries: [Anniversary] = [
        Anniversary(id: "an1", title: "我哋一齊嘅日子",
                    baseDate: "2024-05-22", recur: .yearly,
                    kaomoji: "(♡˙︶˙♡)", emoji: "♡", subtitle: nil),
        Anniversary(id: "an2", title: "第一次見面",
                    baseDate: "2023-11-08", recur: .yearly,
                    kaomoji: "(´｡• ω •｡`)", emoji: "☕", subtitle: nil),
        Anniversary(id: "an5", title: "Michel 生日",
                    baseDate: "1996-04-05", recur: .yearly,
                    kaomoji: "(≧▽≦)", emoji: "🎂", subtitle: nil),
    ]
}
