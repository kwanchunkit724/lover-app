import SwiftUI

@main
struct LoverApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var profileStore = UserProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(profileStore)
                .theme(profileStore.theme)
                .task { await session.bootstrap() }
        }
    }
}

// Top-level routing. Decides which surface to show:
//   1. Onboarding (no UserProfile saved yet) — Phase 2
//   2. Pairing (signed in, no couple) — Phase 3 (TODO)
//   3. MainTabView (paired or mock-paired)
struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var profileStore: UserProfileStore

    var body: some View {
        Group {
            if !profileStore.isOnboarded {
                OnboardingView()
            } else {
                switch session.state {
                case .loading:
                    ProgressView()
                case .signedOut, .signedInUnpaired:
                    // Phase 3 will replace this with PairingView; for now drop into mock chat.
                    MainTabView()
                case .paired:
                    MainTabView()
                }
            }
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedInUnpaired
        case paired(coupleId: UUID, partnerUserId: UUID)
    }

    @Published private(set) var state: State = .loading

    func bootstrap() async {
        // Phase 3 wires this to KeyManager + Supabase. For now we drop straight
        // into the paired state so chat/timetable/profile UIs render with mock data.
        state = .paired(coupleId: UUID(), partnerUserId: UUID())
    }
}
