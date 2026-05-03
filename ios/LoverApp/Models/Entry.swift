import Foundation

// Mirrors D.entries in design-import/data.js — the unified time/memory entry.
// Status is derived from `startsAt` vs now: `upcoming` if future, `past` if past.

struct Entry: Identifiable, Hashable {
    enum Tag: String, CaseIterable, Codable {
        case special = "特別日子"
        case outing  = "出遊"
        case food    = "食"
        case home    = "屋企"
        case walk    = "散步"
        case solo    = "solo"
    }

    enum Who: String, Codable, Hashable {
        case both, mine, theirs
    }

    let id: String
    let date: String              // "yyyy-MM-dd" — matches data.js
    let time: String?             // "HH:mm" — matches data.js
    let title: String
    let location: String?
    let proposedBy: String        // Person.id
    let who: Who
    let tag: Tag
    let isSpecial: Bool
    let notes: String?

    // Past-only fields
    let cover: String?            // photo placeholder id
    let photos: Int               // count
    let voiceClips: Int
    let messages: Int
    let kaomoji: String?
    let reflection: Reflection?
    let onThisDay: Bool

    /// Whether this entry has graduated from upcoming → past based on `date` vs today.
    func isPast(today: String) -> Bool {
        date < today
    }

    func isToday(_ today: String) -> Bool {
        date == today
    }
}

struct Reflection: Hashable, Codable {
    let from: String      // Person.id of author
    let text: String
    let kaomoji: String?
}
