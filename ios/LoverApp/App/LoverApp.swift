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
    @StateObject private var presence: PresenceService
    // v1.6.1 — Feature 7 (mood/cheer) + Feature 6 (meet-up).
    @StateObject private var mood = MoodService()
    @StateObject private var meetups: MeetupService

    init() {
        let c = CryptoService()
        _crypto         = StateObject(wrappedValue: c)
        _chat           = StateObject(wrappedValue: ChatService(crypto: c))
        _anniversaries  = StateObject(wrappedValue: AnniversaryService(crypto: c))
        _entries        = StateObject(wrappedValue: EntryService(crypto: c))
        _playHistory    = StateObject(wrappedValue: PlayHistoryService(crypto: c))
        _meetups        = StateObject(wrappedValue: MeetupService(crypto: c))
        // Phase C — presence reads myUserId lazily on each start() so it
        // doesn't capture a stale signed-out state.
        _presence       = StateObject(wrappedValue: PresenceService(myUserId: {
            // Read directly from Supabase auth — avoids a cross-singleton
            // dependency on AuthService here in App init.
            SB.client.auth.currentUser?.id
        }))
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
                .environmentObject(presence)
                .environmentObject(mood)
                .environmentObject(meetups)
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
    @EnvironmentObject private var presence: PresenceService
    @EnvironmentObject private var mood: MoodService
    @EnvironmentObject private var meetups: MeetupService

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
                presence.stop()
                mood.stop()
                meetups.stop()
                crypto.reset()
                pairing.resetState()
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
                presence.stop()
                mood.stop()
                meetups.stop()
                crypto.reset()
                pairing.resetState()
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
            // Phase C — heartbeat must NOT fire while backgrounded. Pause on
            // .background / .inactive, resume on .active.
            switch phase {
            case .background, .inactive:
                presence.pause()
                mood.pause()
                meetups.pause()
            case .active:
                if let coupleId = pairing.couple?.id {
                    presence.resume(coupleId: coupleId)
                    mood.resume(coupleId: coupleId)
                    meetups.resume(coupleId: coupleId)
                }
            @unknown default:
                break
            }
        }
    }

    /// v1.3.2 — relentless prepare loop. v1.3.1's 16-second cap still wasn't
    /// enough in the wild — partners on slow networks could take longer to
    /// upload their public key, and once the loop exited the chat key
    /// stayed nil. Now we keep retrying with backoff until either prepare
    /// succeeds OR the user navigates away (state goes signedOut /
    /// unpaired, observed by the .onChange handlers above which would
    /// invalidate the next iteration's preconditions).
    private func preparePaired(meId: UUID) async {
        guard let couple = pairing.couple else { return }
        var delay: UInt64 = 1_000_000_000   // 1s, doubles up to 8s
        for attempt in 0..<60 {             // ~5 minutes worst case
            // Bail if state has changed under us.
            if !pairing.isPaired { return }
            if crypto.isReady { return }    // another caller succeeded
            // v1.6.1 (problem 1) — the caller (RootView.task / onChange) just
            // ran pairing.refresh, so skip the redundant 2-query refresh here
            // when the partner key is already loaded. Only re-fetch while the
            // key is still missing (the retry path this loop exists for).
            if pairing.partner?.publicKey?.isEmpty ?? true {
                await pairing.refresh(meId: meId)
            }
            if let partner = pairing.partner,
               let pub = partner.publicKey, !pub.isEmpty {
                do {
                    try crypto.prepare(coupleId: couple.id, partner: partner)
                    startCoupleServices(coupleId: couple.id)
                    PushService.shared.bootstrap()
                    return
                } catch {
                    // crypto.lastPrepareError already set inside prepare();
                    // keep looping — partner key may be malformed mid-upload
                }
            }
            try? await Task.sleep(nanoseconds: delay)
            if attempt >= 3, delay < 8_000_000_000 { delay *= 2 }
        }
    }

    /// Start every per-couple background service. Idempotent.
    private func startCoupleServices(coupleId: UUID) {
        chat.start(coupleId: coupleId)
        anniversaries.start(coupleId: coupleId)
        entries.start(coupleId: coupleId)
        playHistory.start(coupleId: coupleId)
        presence.start(coupleId: coupleId)
        mood.start(coupleId: coupleId)
        meetups.start(coupleId: coupleId)
    }
}
