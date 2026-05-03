import SwiftUI

@main
struct LoverApp: App {
    @StateObject private var profileStore = UserProfileStore()
    @StateObject private var auth         = AuthService()
    @StateObject private var pairing      = PairingService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(auth)
                .environmentObject(pairing)
                .theme(profileStore.theme)
                .task { await auth.bootstrap() }
        }
    }
}

// Top-level routing decides which surface to show based on three pieces of
// state, in this order:
//
//   1. profileStore.isOnboarded false  → OnboardingView    (Phase 2 — local only)
//   2. auth.state .unknown             → ProgressView       (still checking session)
//   3. auth.state .signedOut/.error    → SignInView         (Phase 3a)
//   4. auth.state .signedIn, no couple → PairingView        (Phase 3b)
//   5. couple exists                   → MainTabView        (mock data still drives
//                                         chat/timetable until Phase 4)

struct RootView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService

    var body: some View {
        Group {
            if !profileStore.isOnboarded {
                OnboardingView()
            } else {
                switch auth.state {
                case .unknown:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut, .error:
                    SignInView()
                case .signedIn(let userId):
                    if pairing.isPaired {
                        MainTabView()
                    } else {
                        PairingView()
                            .task { await pairing.refresh(meId: userId) }
                    }
                }
            }
        }
        .onChange(of: auth.state) { _, newState in
            // When a new sign-in completes, kick off a couple lookup so the
            // UI either drops straight into the paired surface or surfaces
            // PairingView.
            if case .signedIn(let id) = newState {
                Task { await pairing.refresh(meId: id) }
            }
        }
    }
}
