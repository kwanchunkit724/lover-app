import Foundation

// Direct port of design-import/data.js for use in SwiftUI Previews and dev builds.
// Production builds will replace this with real Supabase + decrypted data.

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
    // 1:1 mirror of data.js D.entries.

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
        Entry(id: "m1", date: "2026-04-26", time: "15:00",
              title: "荔枝角散步", location: "荔枝角公園",
              proposedBy: "michel", who: .both, tag: .walk, isSpecial: false, notes: nil,
              cover: "walk", photos: 4, voiceClips: 1, messages: 23,
              kaomoji: "(´｡• ω •｡`)",
              reflection: Reflection(from: "michel",
                                     text: "個日好曬但係陽光好靚",
                                     kaomoji: "(´｡• ω •｡`)"),
              onThisDay: false),
        Entry(id: "m2", date: "2026-04-19", time: "20:00",
              title: "第一次煮意粉", location: "我哋屋企",
              proposedBy: "kit", who: .both, tag: .home, isSpecial: false, notes: nil,
              cover: "pasta-first", photos: 7, voiceClips: 0, messages: 41,
              kaomoji: "(っ˘ڡ˘ς)",
              reflection: Reflection(from: "kit",
                                     text: "燒燶咗少少但係好開心 — Michel 話下次佢嚟煮",
                                     kaomoji: "(*ˊᗜˋ*)"),
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
        Entry(id: "m4", date: "2026-04-05", time: "19:00",
              title: "Michel 生日會", location: "我哋屋企",
              proposedBy: "kit", who: .both, tag: .special, isSpecial: true, notes: nil,
              cover: "birthday", photos: 9, voiceClips: 0, messages: 102,
              kaomoji: "(♡˙︶˙♡)",
              reflection: Reflection(from: "kit",
                                     text: "Surprise 成功，你喊咗 — 我都喊埋",
                                     kaomoji: "(♡˙︶˙♡)"),
              onThisDay: false),

        // ── 一年前嘅今日 — surfaces in 回望 panel ──
        Entry(id: "mly", date: "2025-05-02", time: "14:00",
              title: "第一次去你屋企見家姐", location: "Michel 屋企",
              proposedBy: "michel", who: .both, tag: .special, isSpecial: false, notes: nil,
              cover: "family", photos: 6, voiceClips: 0, messages: 38,
              kaomoji: "(´｡• ω •｡`)",
              reflection: Reflection(from: "kit",
                                     text: "我緊張到食唔落飯，家姐話我好乖",
                                     kaomoji: "(´；ω；`)"),
              onThisDay: true),

        // ── More past entries to populate the month grid ──
        Entry(id: "m5", date: "2026-04-29", time: nil,
              title: "街市買餸", location: nil,
              proposedBy: "kit", who: .both, tag: .home, isSpecial: false, notes: nil,
              cover: "market", photos: 2, voiceClips: 0, messages: 12,
              kaomoji: "(´｡• ᵕ •｡`)", reflection: nil, onThisDay: false),
        Entry(id: "m6", date: "2026-04-27", time: nil,
              title: "夜晚散步", location: nil,
              proposedBy: "michel", who: .both, tag: .walk, isSpecial: false, notes: nil,
              cover: "night", photos: 3, voiceClips: 0, messages: 8,
              kaomoji: "(˘ω˘)", reflection: nil, onThisDay: false),
        Entry(id: "m7", date: "2026-04-22", time: nil,
              title: "週年月誌 ♡", location: nil,
              proposedBy: "kit", who: .both, tag: .special, isSpecial: true, notes: nil,
              cover: "monthly", photos: 4, voiceClips: 0, messages: 22,
              kaomoji: "(♡˙︶˙♡)", reflection: nil, onThisDay: false),
        Entry(id: "m8", date: "2026-04-17", time: nil,
              title: "茶餐廳食 lunch", location: nil,
              proposedBy: "kit", who: .both, tag: .food, isSpecial: false, notes: nil,
              cover: "cha", photos: 1, voiceClips: 0, messages: 5,
              kaomoji: "(っ˘ڡ˘ς)", reflection: nil, onThisDay: false),
        Entry(id: "m9", date: "2026-04-15", time: nil,
              title: "揀盆栽", location: nil,
              proposedBy: "michel", who: .both, tag: .outing, isSpecial: false, notes: nil,
              cover: "plants", photos: 5, voiceClips: 0, messages: 19,
              kaomoji: "(´｡• ω •｡`)", reflection: nil, onThisDay: false),
        Entry(id: "m10", date: "2026-04-09", time: nil,
              title: "睇日落 @ 西環", location: nil,
              proposedBy: "kit", who: .both, tag: .walk, isSpecial: false, notes: nil,
              cover: "sunset", photos: 6, voiceClips: 0, messages: 15,
              kaomoji: "(◕‿◕)", reflection: nil, onThisDay: false),
        Entry(id: "m11", date: "2026-04-02", time: nil,
              title: "咖啡店打 work", location: nil,
              proposedBy: "michel", who: .both, tag: .outing, isSpecial: false, notes: nil,
              cover: "cafe", photos: 2, voiceClips: 0, messages: 7,
              kaomoji: "(˘ω˘)", reflection: nil, onThisDay: false),
    ]

    // MARK: - Anniversaries
    // Mirrors data.js D.anniversaries — yearly + monthly recurrence.

    static let anniversaries: [Anniversary] = [
        Anniversary(id: "an1", title: "我哋一齊嘅日子",
                    baseDate: "2024-05-22", recur: .yearly,
                    kaomoji: "(♡˙︶˙♡)", emoji: "♡", subtitle: nil),
        Anniversary(id: "an2", title: "第一次見面",
                    baseDate: "2023-11-08", recur: .yearly,
                    kaomoji: "(´｡• ω •｡`)", emoji: "☕", subtitle: nil),
        Anniversary(id: "an3", title: "搬入嚟一齊住",
                    baseDate: "2025-09-14", recur: .yearly,
                    kaomoji: "(´♡‿♡`)", emoji: "🏠", subtitle: nil),
        Anniversary(id: "an4", title: "每月 22 號",
                    baseDate: "2024-05-22", recur: .monthly,
                    kaomoji: "(˘∇˘)♡", emoji: "♡", subtitle: "月誌"),
        Anniversary(id: "an5", title: "Michel 生日",
                    baseDate: "1996-04-05", recur: .yearly,
                    kaomoji: "(≧▽≦)", emoji: "🎂", subtitle: nil),
        Anniversary(id: "an6", title: "Kit 生日",
                    baseDate: "1997-08-19", recur: .yearly,
                    kaomoji: "(*ˊᗜˋ*)", emoji: "🎂", subtitle: nil),
    ]
}
