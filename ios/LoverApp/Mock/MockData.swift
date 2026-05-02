import Foundation

// Direct port of design-import/data.js for use in SwiftUI Previews and dev builds.
// Production builds will replace this with real Supabase + decrypted data.

enum MockData {
    static let me = Person.mockMe
    static let partner = Person.mockPartner

    static let todayDateString = "5月2日 · 星期六"

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
}
