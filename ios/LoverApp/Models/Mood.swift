import Foundation

// v1.6.1 Feature 7 — mood + cheer.
//
// A mood is a generalized "emotion the partner can react to": it carries an
// emoji, a target tap-count for the cheer interaction, and the copy shown
// during/after cheering. Adding a mood is a one-line change here.
//
// Wire value (Mood.rawValue) MUST match the server CHECK constraint in
// 0018_mood.sql and any Android/web client: happy, sad, angry, love, tired.
enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case happy, sad, angry, love, tired

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad:   return "😢"
        case .angry: return "😠"
        case .love:  return "🥰"
        case .tired: return "😩"
        }
    }

    var label: String {
        switch self {
        case .happy: return "開心"
        case .sad:   return "唔開心"
        case .angry: return "嬲嬲"
        case .love:  return "好愛你"
        case .tired: return "好攰"
        }
    }

    /// How many taps the partner must give to "cheer" this mood.
    /// happy/love = a single clap; sad/angry need 100; tired in between.
    var targetTaps: Int {
        switch self {
        case .happy, .love: return 1
        case .tired:        return 30
        case .sad, .angry:  return 100
        }
    }

    /// What the cheerer is doing, for button/overlay copy.
    var cheerVerb: String {
        switch self {
        case .happy: return "同佢擊掌"
        case .love:  return "錫返佢一啖"
        case .sad:   return "氹返佢開心"
        case .angry: return "氹返佢唔好嬲"
        case .tired: return "幫佢叉電"
        }
    }

    /// Big kaomoji shown while cheering (the "before" face).
    var cheerKao: String {
        switch self {
        case .happy: return "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"
        case .love:  return "(づ｡◕‿‿◕｡)づ"
        case .sad:   return "(｡•́︿•̀｡)"
        case .angry: return "(╬ Ò﹏Ó)"
        case .tired: return "(ᴗ_ᴗ｡)"
        }
    }

    /// Celebration kaomoji shown on completion (the "after" face).
    var doneKao: String { "٩(◕‿◕)۶" }

    /// Whether this mood is one the partner should be nudged to cheer.
    var needsCheer: Bool { self == .sad || self == .angry || self == .tired }
}
