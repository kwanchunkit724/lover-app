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
    @Environment(\.scenePhase) private var scenePhase
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
        // v1.3.1 — bug surfaced in v1.3.0 testing: chatKey often stayed nil
        // after pairing because crypto.prepare ran ONCE before the partner
        // had finished uploading their public key. Result: every subsequent
        // entry / chat message / play history insert silently failed at the
        // seal step (crypto.notReady), and existing rows showed
        // "(無法解密)". Re-attempt prepare every time the app comes back to
        // the foreground if we're paired but still keyless. This is cheap
        // (one DB read + 1 HKDF) and idempotent.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active,
               crypto.chatKey == nil,
               pairing.isPaired,
               case .signedIn(let id) = auth.state {
                Task { await preparePaired(meId: id) }
            }
        }
    }

    /// v1.3.1 — robust prepare loop. Earlier version retried once and then
    /// gave up; if the partner hadn't uploaded their public key in those
    /// ~hundreds of milliseconds, chatKey stayed nil forever (until the
    /// user reopened the app). Now we poll for up to ~16 seconds, refreshing
    /// the partner row each pass. Returns immediately on success.
    private func preparePaired(meId: UUID) async {
        guard let couple = pairing.couple else { return }
        for _ in 0..<8 {
            await pairing.refresh(meId: meId)
            if let partner = pairing.partner, partner.publicKey != nil {
                do {
                    try crypto.prepare(coupleId: couple.id, partner: partner)
                    startCoupleServices(coupleId: couple.id)
                    PushService.shared.bootstrap()
                    return
                } catch {
                    // partner row exists but key parse failed — try again
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    /// Start every per-couple background service. Idempotent.
    private func startCoupleServices(coupleId: UUID) {
        chat.start(coupleId: coupleId)
        anniversaries.start(coupleId: coupleId)
        entries.start(coupleId: coupleId)
        playHistory.start(coupleId: coupleId)
    }
}
