import Foundation

// Lightweight identity card for either user. Mirrors D.ME / D.PARTNER in data.js.
// Real production data is decrypted from `users` rows; this struct is the in-memory shape.

struct Person: Identifiable, Hashable {
    enum Tint: String, Codable { case rose, sage, amber }

    let id: String
    let name: String        // display name (will be decrypted from ciphertext in production)
    let initial: String     // single-letter or single-CJK avatar character
    let tint: Tint
}

extension Person {
    static let mockMe = Person(id: "kit", name: "Kit", initial: "K", tint: .rose)
    static let mockPartner = Person(id: "michel", name: "Michel", initial: "M", tint: .sage)
}
