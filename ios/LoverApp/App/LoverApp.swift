import SwiftUI

@main
struct LoverApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var profileStore = UserProfileStore()
    @StateObject private var auth         = AuthService()
    @StateObject private var pairing      = PairingService()
    @StateObject private var crypto       = CryptoService()
    @StateObject private var chat: ChatService
    @StateObject private var anniversaries: AnniversaryService
    @StateObject private var entries: EntryService
    @StateObject private var playHistory: PlayHistoryService

    init() {
        let c = CryptoService()
        _crypto         = StateObject(wrappedValue: c)
        _chat           = StateObject(wrappedValue: ChatService(crypto: c))
        _anniversaries  = StateObject(wrappedValue: AnniversaryService(crypto: c))
        _entries        = StateObject(wrappedValue: EntryService(crypto: c))
        _playHistory    = StateObject(wrappedValue: PlayHistoryService(crypto: c))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(auth)
                .environmentObject(pairing)
                .environmentObject(crypto)
                .environmentObject(chat)
                .environmentObject(anniversaries)
                .environmentObject(entries)
                .environmentObject(playHistory)
                .theme(profileStore.theme)
                .task { await auth.bootstrap() }
        }
    }
}

// Top-level routing decides which surface to show:
//
//   1. profileStore.isOnboarded false  → OnboardingView
//   2. auth.state .unknown             → ProgressView (checking session)
//   3. auth.state .signedOut/.error    → SignInView
//   4. auth.state .signedIn            → MainTabView
//
// Phase 9 (v0.9.0): pairing is no longer a gate before MainTabView. A
// signed-in user can use the app solo — Profile, Settings, Themes work
// fully, Chat / Time / Anniversary / Play tabs show an "未配對" prompt
// with a "去配對" button that opens PairingView as a sheet. This lets
// users iterate on the app with one Apple ID instead of needing two
// devices for every test.
//
// Per-couple services (chat, anniversaries, entries, playHistory) only
// start when a couple actually exists — driven by `onChange(of: pairing.isPaired)`.

struct RootView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService
    @EnvironmentObject private var crypto: CryptoService
    @EnvironmentObject private var chat: ChatService
    @EnvironmentObject private var anniversaries: AnniversaryService
    @EnvironmentObject private var entries: EntryService
    @EnvironmentObject private var playHistory: PlayHistoryService

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
                    MainTabView()
                        .task {
                            await pairing.refresh(meId: userId)
                            if pairing.isPaired {
                                await preparePaired(meId: userId)
                            }
                        }
                }
            }
        }
        .onChange(of: auth.state) { _, newState in
            if case .signedIn(let id) = newState {
                Task {
                    await pairing.refresh(meId: id)
                    if pairing.isPaired {
                        await preparePaired(meId: id)
                    }
                }
            } else {
                // Sign-out / error: tear down per-couple services + chat key.
                chat.stop()
                anniversaries.stop()
                entries.stop()
                playHistory.stop()
                crypto.reset()
            }
        }
        .onChange(of: pairing.isPaired) { _, isPaired in
            if isPaired {
                if case .signedIn(let id) = auth.state {
                    Task { await preparePaired(meId: id) }
                }
            } else {
                chat.stop()
                anniversaries.stop()
                entries.stop()
                playHistory.stop()
                crypto.reset()
            }
        }
    }

    private func preparePaired(meId: UUID) async {
        guard let couple = pairing.couple, let partner = pairing.partner else { return }
        do {
            try crypto.prepare(coupleId: couple.id, partner: partner)
            startCoupleServices(coupleId: couple.id)
        } catch {
            // Likely partner hasn't uploaded their public key yet (first
            // sign-in race) — refresh once more to pick it up, then retry.
            await pairing.refresh(meId: meId)
            if let partner = pairing.partner {
                try? crypto.prepare(coupleId: couple.id, partner: partner)
                startCoupleServices(coupleId: couple.id)
            }
        }
        // Ask for notification permission + register APNs once paired.
        PushService.shared.bootstrap()
    }

    /// Start every per-couple background service. Idempotent.
    private func startCoupleServices(coupleId: UUID) {
        chat.start(coupleId: coupleId)
        anniversaries.start(coupleId: coupleId)
        entries.start(coupleId: coupleId)
        playHistory.start(coupleId: coupleId)
    }
}
