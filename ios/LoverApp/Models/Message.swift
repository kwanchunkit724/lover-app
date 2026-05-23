import Foundation

// Mirrors D.messages in design-import/data.js. The wire format on the backend
// holds ciphertext + nonce; this struct is the decrypted in-memory form
// the views render against.

struct Message: Identifiable, Hashable {
    enum Kind: String, Codable, Hashable { case text, kaomoji, photo, voice, video }

    struct ReplyPreview: Hashable {
        let messageID: String
        let kind: Kind
        let preview: String
    }

    struct Reaction: Hashable {
        let from: String       // Person.id
        let kao: String
    }

    let id: String
    let from: String           // Person.id of sender
    let kind: Kind
    let timestamp: String      // "HH:mm" — design uses pre-formatted strings
    var read: Bool

    // Per-kind payloads
    var text: String?          // text / kaomoji
    var photoSrc: String?      // photo placeholder id
    var caption: String?       // photo caption
    var voiceDurationSec: Int? // voice
    var voiceTranscript: String?

    var replyTo: ReplyPreview?
    var reactions: [Reaction] = []

    // v1.5 — IG-style chat features
    var isEdited: Bool = false
    var isDeleted: Bool = false   // soft-delete (unsend); render "已撤回" placeholder
}

extension Message {
    var previewText: String {
        if isDeleted { return "已撤回嘅訊息" }
        switch kind {
        case .text, .kaomoji: return text ?? ""
        case .photo: return caption ?? "📷 相片"
        case .voice: return "🎙 \(voiceDurationSec ?? 0) 秒語音訊息"
        case .video: return "📹 \(voiceDurationSec ?? 0) 秒短片"
        }
    }
}
