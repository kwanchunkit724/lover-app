import Foundation

/// Row written on sign-in. `anniversary_iso` is a nullable `date`.
/// Onboarding leaves it blank (the couple day is optional), and posting `""`
/// fails the whole upsert, so `my_name` never reaches the server.
/// An empty anniversary is JSON null. A real name is sent as `my_name`.
struct UserProfileUpsert: Encodable, Equatable {
    let id: UUID
    let myName: String
    let partnerName: String
    let anniversaryISO: String?
    let themeId: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case id
        case myName = "my_name"
        case partnerName = "partner_name"
        case anniversaryISO = "anniversary_iso"
        case themeId = "theme_id"
        case publicKey = "public_key"
    }

    init(userId: UUID, profile: UserProfile, publicKey: String) {
        id = userId
        myName = CoupleNames.columnValue(profile.myName, fallback: CoupleNames.mePlaceholder)
        partnerName = CoupleNames.columnValue(profile.partnerName, fallback: CoupleNames.partnerPlaceholder)
        let anniversary = profile.anniversaryISO.trimmingCharacters(in: .whitespacesAndNewlines)
        anniversaryISO = anniversary.isEmpty ? nil : anniversary
        themeId = profile.themeId
        self.publicKey = publicKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(myName, forKey: .myName)
        try container.encode(partnerName, forKey: .partnerName)
        if let anniversaryISO {
            try container.encode(anniversaryISO, forKey: .anniversaryISO)
        } else {
            try container.encodeNil(forKey: .anniversaryISO)
        }
        try container.encode(themeId, forKey: .themeId)
        try container.encode(publicKey, forKey: .publicKey)
    }
}
