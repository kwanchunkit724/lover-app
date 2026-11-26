import Foundation

// KK product models. Wire strings for the daily mood whitelist are built from
// Unicode scalars in `DailyMoodLock` so the third mood cannot drift.
//
// Python lock (mood 3, called MOOD6 in the product note):
//   MOOD6 = '\u6709\u5572' + chr(0x6530)
//   assert list(map(hex, map(ord, MOOD6))) == ['0x6709', '0x5572', '0x6530']
//   assert MOOD6 != '\u6709\u5572' + chr(0x6536)

enum DailyMoodLock {
    /// CJK UNIFIED IDEOGRAPH-6530. Tired. Not U+6536 and not U+652F.
    static let tiredScalar = UnicodeScalar(0x6530)!
    static let forbiddenCollect = UnicodeScalar(0x6536)!
    static let forbiddenZhi = UnicodeScalar(0x652F)!

    static let moodHappy = "\u{958B}\u{5FC3}"
    static let moodCalm = "\u{5E73}\u{975C}"
    static let moodTired = "\u{6709}\u{5572}" + String(tiredScalar)
    static let moodLow = "\u{4F4E}\u{843D}"
    static let moodMissYou = "\u{639B}\u{4F4F}\u{4F60}"
    static let moodAnnoyed = "\u{6709}\u{5572}\u{7169}"

    static let orderedLabels: [String] = [
        moodHappy, moodCalm, moodTired, moodLow, moodMissYou, moodAnnoyed
    ]

    static func codepoints(of text: String) -> [UInt32] {
        text.unicodeScalars.map(\.value)
    }

    /// True only for the six locked labels, each checked by scalar.
    static func isAllowed(_ label: String) -> Bool {
        guard orderedLabels.contains(label) else { return false }
        let scalars = codepoints(of: label)
        if scalars.contains(forbiddenCollect.value) || scalars.contains(forbiddenZhi.value) {
            return false
        }
        if label == moodTired {
            return scalars == [0x6709, 0x5572, 0x6530]
        }
        return label.count <= 3
    }
}

enum DailyMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case happy, calm, tired, low, missYou, annoyed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .happy:   return DailyMoodLock.moodHappy
        case .calm:    return DailyMoodLock.moodCalm
        case .tired:   return DailyMoodLock.moodTired
        case .low:     return DailyMoodLock.moodLow
        case .missYou: return DailyMoodLock.moodMissYou
        case .annoyed: return DailyMoodLock.moodAnnoyed
        }
    }

    var kao: String {
        switch self {
        case .happy:   return "(◕‿◕)"
        case .calm:    return "(´｡• ω •｡`)"
        case .tired:   return "(-_-)"
        case .low:     return "(´;ω;`)"
        case .missYou: return "(´ε｀ )♡"
        case .annoyed: return "(；￢＿￢)"
        }
    }

    static func from(label: String) -> DailyMood? {
        allCases.first { $0.label == label }
    }
}

/// Copy for the daily mood gate. Postgres `raise exception` codes such as
/// `profile_missing` stay off the screen; the gate shows these sentences.
enum MoodGateCopy {
    static func message(for error: Error) -> String {
        let ns = error as NSError
        var parts = [ns.localizedDescription]
        if let message = ns.userInfo["message"] as? String {
            parts.append(message)
        }
        if let reason = ns.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            parts.append(reason)
        }
        return message(from: parts.joined(separator: "\n"))
    }

    static func message(from raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("partner_profile_missing") {
            return "對方未完成註冊 — 等對方再開一次"
        }
        if lowered.contains("profile_missing") {
            return "未完成註冊 — 再試一次"
        }
        if lowered.contains("not_authenticated") || lowered.contains("not authenticated") {
            return "未登入 — 重新登入"
        }
        if lowered.contains("invalid_mood") {
            return "呢個心情伺服器唔收 — 再揀一次"
        }
        if lowered.contains("mood_gate_before_0600") {
            return "香港時間 06:00 之前伺服器唔收心情。"
        }
        if lowered.contains("mood_date_must_be_today") {
            return "日子對唔上 — 再試一次"
        }
        if lowered.contains("not_paired") {
            return "未配對 — 請先配對"
        }
        if isHumanCopy(raw) {
            return raw
        }
        return "暫時做唔到 — 再試一次"
    }

    /// Sentences we wrote ourselves. A CJK string that also carries a
    /// snake_case token is still a leaked code.
    private static func isHumanCopy(_ raw: String) -> Bool {
        let hasCJK = raw.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        return hasCJK && !containsMachineCode(raw)
    }

    private static func containsMachineCode(_ raw: String) -> Bool {
        var token = ""
        func isCode(_ token: String) -> Bool {
            guard let first = token.first, first.isASCII, first.isLetter else { return false }
            guard token.contains("_") else { return false }
            return token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
        }
        for ch in raw.lowercased() {
            if ch.isASCII, ch.isLetter || ch.isNumber || ch == "_" {
                token.append(ch)
            } else if isCode(token) {
                return true
            } else {
                token.removeAll(keepingCapacity: true)
            }
        }
        return isCode(token)
    }
}

/// Not actor-isolated. Codable snapshots and views both read this.
enum KKAIQuota {
    static let monthlyCap = 10
}

enum KKTime {
    static let zone = TimeZone(identifier: "Asia/Hong_Kong")!

    /// Mood day rolls at 06:00 HKT. Before that, yesterday's choice still covers.
    static func moodDayKey(now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let hour = cal.component(.hour, from: now)
        let base = hour < 6 ? (cal.date(byAdding: .day, value: -1, to: now) ?? now) : now
        let parts = cal.dateComponents([.year, .month, .day], from: base)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Calendar date in Hong Kong, with no 06:00 roll.
    /// `kk_set_daily_mood` requires this date and rejects anything else.
    static func calendarDayKey(now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let parts = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Server opens the daily mood write at 06:00 HKT. Before that the RPC rejects the call.
    static func isMoodGateOpen(now: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.component(.hour, from: now) >= 6
    }

    static func yearMonthKey(now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let parts = cal.dateComponents([.year, .month], from: now)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}

enum MemoryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily, date, plan, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "日常"
        case .date:  return "約會"
        case .plan:  return "計劃"
        case .other: return "其他"
        }
    }
}

struct MemoryItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var originalText: String
    var category: MemoryCategory
    var noteSummary: String
    var sourceMessageIds: [String]
    /// Local stand-in for a copied photo thumb. Not chat ciphertext.
    var photoThumbMarkers: [String]
    /// Video / file markers only. Binary stays out of this record.
    var attachmentMarkers: [String]
    var reminderAt: Date?
    var createdAt: Date
}

struct MemoryDraft: Equatable {
    var title: String = ""
    var originalText: String = ""
    var category: MemoryCategory = .daily
    var noteSummary: String = ""
    var sourceMessageIds: [String] = []
    var photoThumbMarkers: [String] = []
    var attachmentMarkers: [String] = []
    var reminderAt: Date? = nil
    var editingId: UUID? = nil
}

struct WantYouKnowNote: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var deadline: Date?
    var remindAtNineHKT: Bool
    var readByMe: Bool
    var readByPartner: Bool
    var deletedByMe: Bool
    var deletedByPartner: Bool
    var createdAt: Date

    var isVisible: Bool { !(deletedByMe && deletedByPartner) }
}

struct AIExpandRequest: Identifiable, Equatable {
    let id = UUID()
    var userText: String
    var memoryItemIds: [UUID]
}

struct PendingDailyMoodRPC: Equatable {
    /// `kk_set_daily_mood` — not called. See KK_IOS_BACKEND_CONTRACT.md.
    var rpcName: String { "kk_set_daily_mood" }
    var mood: String
    var hktDate: String
}
