import Foundation
import SwiftUI
import Combine

// First-launch profile collected by OnboardingView. Persisted in UserDefaults
// as JSON so it survives reinstalls (within the same iCloud-backed user) and
// killing the app. Phase 3 will move the canonical copy to Supabase, but this
// device-side cache stays as the source of truth for "is onboarding done".

struct UserProfile: Codable, Equatable {
    var myName: String
    var partnerName: String
    var anniversaryISO: String   // yyyy-MM-dd
    var themeId: String          // matches Theme.id ("jbeam", "notion", "cozy")
    var completedAt: Date
}

@MainActor
final class UserProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?

    private let defaultsKey = "us.userProfile.v1"

    init() { load() }

    var isOnboarded: Bool { profile != nil }

    var theme: Theme {
        switch profile?.themeId {
        case "notion": return .notion
        case "cozy":   return .cozy
        default:       return .jbeam
        }
    }

    func save(_ profile: UserProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func reset() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        profile = decoded
    }
}

// Shared yyyy-MM-dd formatter — matches the format MockData / Anniversary /
// Entry already use throughout the app.
extension ISO8601DateFormatter {
    static let fullDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
