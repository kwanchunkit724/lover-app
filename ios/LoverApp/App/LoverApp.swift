import SwiftUI

@main
struct LoverApp: App {
    @StateObject private var profileStore = UserProfileStore()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(auth)
                .theme(profileStore.theme)
                .task { await auth.bootstrap() }
        }
    }
}

// Top-level routing decides which surface to show based on two pieces of
// state, in this order:
//
//   1. profileStore.isOnboarded false  → OnboardingView   (Phase 2 — local only)
//   2. auth.state .unknown             → ProgressView      (still checking session)
//   3. auth.state .signedOut/.error    → SignInView        (Phase 3a — Sign in with Apple)
//   4. auth.state .signedIn, no couple → PairingPlaceholderView
//                                        (Phase 3b will replace with real PairingView,
//                                         Phase 3c will detect couple via Supabase)
//   5. (Phase 3b+) couple exists       → MainTabView with real backend
//
// For Phase 3a we stop at #4 — once you sign in successfully, you see the
// "已登入" placeholder. Phase 3b ships the actual pairing UI.

struct RootView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService

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
                case .signedIn:
                    PairingPlaceholderView()
                }
            }
        }
    }
}
