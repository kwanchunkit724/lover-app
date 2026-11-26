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
    @StateObject private var checklist: ChecklistService
    @StateObject private var kk = KKAppModel()

    init() {
        let c = CryptoService()
        _crypto         = StateObject(wrappedValue: c)
        _chat           = StateObject(wrappedValue: ChatService(crypto: c))
        _anniversaries  = StateObject(wrappedValue: AnniversaryService(crypto: c))
        _entries        = StateObject(wrappedValue: EntryService(crypto: c))
        _playHistory    = StateObject(wrappedValue: PlayHistoryService(crypto: c))
        _meetups        = StateObject(wrappedValue: MeetupService(crypto: c))
        _checklist      = StateObject(wrappedValue: ChecklistService(crypto: c))
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
                .environmentObject(checklist)
                .environmentObject(kk)
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
    @EnvironmentObject private var checklist: ChecklistService
    @EnvironmentObject private var kk: KKAppModel

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
                    signedInShell()
                        .task {
                            kk.bind(userId: userId)
                            if UITesting.blocksNetwork { return }
                            await auth.ensurePublicKeyUploaded(userId: userId)
                            await publishLocalName()
                            pairing.startSessionWatch(meId: userId)
                            await pairing.refresh(meId: userId)
                            if pairing.isPaired {
                                kickPrepare(meId: userId)
                            }
                        }
                }
            }
        }
        .onChange(of: auth.state) { _, newState in
            if case .signedIn(let id) = newState {
                kk.bind(userId: id)
                if UITesting.blocksNetwork { return }
                Task {
                    await auth.ensurePublicKeyUploaded(userId: id)
                    await publishLocalName()
                    pairing.startSessionWatch(meId: id)
                    await pairing.refresh(meId: id)
                    if pairing.isPaired {
                        kickPrepare(meId: id)
                    }
                }
            } else {
                kk.clearSession()
                pairing.stopSessionWatch()
                // Sign-out / error: tear down per-couple services + chat key.
                chat.stop()
                anniversaries.stop()
                entries.stop()
                playHistory.stop()
                presence.stop()
                mood.stop()
                meetups.stop()
                checklist.stop()
                crypto.reset()
                pairing.resetState()
            }
        }
        .onChange(of: pairing.isPaired) { _, isPaired in
            if isPaired {
                if UITesting.blocksNetwork { return }
                if case .signedIn(let id) = auth.state {
                    kickPrepare(meId: id)
                }
            } else {
                chat.stop()
                anniversaries.stop()
                entries.stop()
                playHistory.stop()
                presence.stop()
                mood.stop()
                meetups.stop()
                checklist.stop()
                crypto.reset()
                pairing.resetState()
            }
        }
        .onChange(of: pairing.channelRetryNonce) { _, _ in
            if UITesting.blocksNetwork { return }
            guard pairing.isPaired, case .signedIn(let id) = auth.state else { return }
            kickPrepare(meId: id)
        }
        // Realtime (or the fallback poll) can fill partner_public_key while
        // a prepare loop is sleeping. Derive as soon as the key is non-empty.
        .onChange(of: pairing.partner?.publicKey) { _, key in
            if UITesting.blocksNetwork { return }
            guard let key, !key.isEmpty, !crypto.isReady, pairing.isPaired,
                  case .signedIn(let id) = auth.state else { return }
            kickPrepare(meId: id)
        }
        // v1.3.1 — chatKey often stayed nil after pairing because prepare ran
        // once before the partner had uploaded public_key. Foreground retries
        // when we're still keyless, republishes OUR key via kk_set_public_key,
        // and restarts the pairing realtime channel if the subscribe failed.
        // The code-screen poll is only the fallback for a missed event.
        .onChange(of: scenePhase) { _, phase in
            if UITesting.blocksNetwork { return }
            // Phase C — heartbeat must NOT fire while backgrounded. Pause on
            // .background / .inactive, resume on .active.
            switch phase {
            case .background, .inactive:
                presence.pause()
                checklist.pause()
            case .active:
                if case .signedIn(let id) = auth.state {
                    Task {
                        await auth.ensurePublicKeyUploaded(userId: id)
                        await publishLocalName()
                        pairing.startSessionWatch(meId: id)
                        // Refresh even when already paired so the partner's
                        // saved my_name replaces the 「我」 default.
                        await pairing.refresh(meId: id, quiet: true)
                        if pairing.isPaired {
                            if !crypto.isReady {
                                kickPrepare(meId: id)
                            }
                        } else if pairing.activeCode != nil {
                            pairing.startWaitingForPartner(meId: id)
                        }
                    }
                }
                if let coupleId = pairing.couple?.id {
                    presence.resume(coupleId: coupleId)
                    checklist.resume(coupleId: coupleId)
                }
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private func signedInShell() -> some View {
        if UITesting.mode == .shell {
            MainTabView()
        } else if !kk.dailyMood.isReady {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if kk.dailyMood.needsGate() {
            DailyMoodGateView()
        } else {
            MainTabView()
        }
    }

    /// Writes the on-device name onto `users.my_name` when it is a real name.
    /// Session restore does not re-run the sign-in upsert, and
    /// `kk_ensure_profile()` will not replace the default 「我」.
    private func publishLocalName() async {
        guard let name = profileStore.profile?.myName else { return }
        await auth.publishMyName(name)
    }

    /// Re-publish our key and derive the chat key. Keeps polling while the
    /// partner row's `public_key` is empty: a null column is not success.
    /// A newer attempt (retry, foreground, sign-out, unpair) bumps the
    /// token on `PairingService` and this loop exits.
    private func kickPrepare(meId: UUID) {
        let generation = pairing.beginPrepareAttempt()
        Task { await preparePaired(meId: meId, generation: generation) }
    }

    private func preparePaired(meId: UUID, generation: Int) async {
        if UITesting.blocksNetwork { return }
        guard pairing.prepareAttemptIsCurrent(generation) else { return }
        _ = await auth.ensurePublicKeyUploaded(userId: meId)
        guard pairing.prepareAttemptIsCurrent(generation) else { return }
        var delay: UInt64 = 1_000_000_000   // 1s, doubles up to 8s
        var attempt = 0
        while pairing.prepareAttemptIsCurrent(generation) {
            if !pairing.isPaired { return }
            if crypto.isReady { return }
            if case .signedIn = auth.state {} else { return }
            // Re-write our key occasionally so a blip during the first
            // upload still lands before the partner's next read.
            if attempt > 0, attempt % 5 == 0, auth.ownPublicKeyOnServer != true {
                _ = await auth.ensurePublicKeyUploaded(userId: meId)
            }
            if pairing.partner?.publicKey?.isEmpty ?? true {
                await pairing.refresh(meId: meId, quiet: true)
            }
            if !pairing.prepareAttemptIsCurrent(generation) { return }
            if let couple = pairing.couple,
               let partner = pairing.partner,
               let pub = partner.publicKey, !pub.isEmpty {
                do {
                    try crypto.prepare(coupleId: couple.id, partner: partner)
                    guard pairing.isPaired, pairing.prepareAttemptIsCurrent(generation) else {
                        crypto.reset()
                        return
                    }
                    startCoupleServices(coupleId: couple.id)
                    PushService.shared.bootstrap()
                    return
                } catch {
                    // lastPrepareError is a Cantonese string. Keep polling —
                    // the partner may still be replacing a bad upload.
                }
            }
            try? await Task.sleep(nanoseconds: delay)
            if attempt >= 3, delay < 8_000_000_000 { delay *= 2 }
            attempt += 1
        }
    }

    /// Chat, presence, and the short checklist still run.
    /// Time, activities, anniversaries, and meetups are not started:
    /// those screens are gone from the KK shell. The service objects stay
    /// so sign-out can stop them, and so a later PR can delete the files.
    private func startCoupleServices(coupleId: UUID) {
        chat.start(coupleId: coupleId)
        presence.start(coupleId: coupleId)
        checklist.start(coupleId: coupleId)
    }
}
