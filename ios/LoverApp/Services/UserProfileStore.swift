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

// Shared yyyy-MM-dd formatter pinned to LOCAL time zone — matches what the
// user picked in the date wheel. ISO8601DateFormatter defaults to GMT, which
// in HK shifts a freshly picked midnight backwards a day ("May 22" → 16:00 UTC
// May 21 → "2024-05-21"). That bit two phones during pairing because the
// anniversary cross-check started rejecting visually-identical dates.
//
// Both onboarding (storing the picked date as a string) and pairing redeem
// (sending the picked date to the RPC) MUST use this same helper.
enum LocalDate {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }

    static func date(from iso: String) -> Date? { formatter.date(from: iso) }
}

// Pretty display: "yyyy.MM.dd" in local time zone.
enum DisplayDate {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Convert a "yyyy-MM-dd" iso string into a "yyyy.MM.dd" display string.
    static func from(iso: String) -> String {
        guard let d = LocalDate.date(from: iso) else {
            return iso.replacingOccurrences(of: "-", with: ".")
        }
        return formatter.string(from: d)
    }
}
