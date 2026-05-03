import SwiftUI

@main
struct LoverApp: App {
    @StateObject private var profileStore = UserProfileStore()
    @StateObject private var auth         = AuthService()
    @StateObject private var pairing      = PairingService()
    @StateObject private var crypto       = CryptoService()
    @StateObject private var chat: ChatService

    init() {
        let c = CryptoService()
        _crypto = StateObject(wrappedValue: c)
        _chat   = StateObject(wrappedValue: ChatService(crypto: c))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(auth)
                .environmentObject(pairing)
                .environmentObject(crypto)
                .environmentObject(chat)
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
//   5. couple exists                   → MainTabView        (Phase 4 — real chat)

struct RootView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService
    @EnvironmentObject private var crypto: CryptoService
    @EnvironmentObject private var chat: ChatService

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
                            .task { await preparePaired(meId: userId) }
                    } else {
                        PairingView()
                            .task { await pairing.refresh(meId: userId) }
                    }
                }
            }
        }
        .onChange(of: auth.state) { _, newState in
            if case .signedIn(let id) = newState {
                Task { await pairing.refresh(meId: id) }
            } else {
                // Sign-out / error: tear down chat polling + chat key.
                chat.stop()
                crypto.reset()
            }
        }
        .onChange(of: pairing.isPaired) { _, isPaired in
            if !isPaired {
                chat.stop()
                crypto.reset()
            }
        }
    }

    private func preparePaired(meId: UUID) async {
        guard let couple = pairing.couple, let partner = pairing.partner else { return }
        do {
            try crypto.prepare(coupleId: couple.id, partner: partner)
            chat.start(coupleId: couple.id)
        } catch {
            // Likely partner hasn't uploaded their public key yet (first
            // sign-in race) — refresh once more to pick it up, then retry.
            await pairing.refresh(meId: meId)
            if let partner = pairing.partner {
                try? crypto.prepare(coupleId: couple.id, partner: partner)
                chat.start(coupleId: couple.id)
            }
        }
    }
}
