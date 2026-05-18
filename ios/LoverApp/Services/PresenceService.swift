import Foundation
import Combine
import Supabase

// Phase C — real partner presence.
//
// Two signals work together:
//   1. Supabase Realtime presence channel keyed by couple id. Each client
//      joins `presence:<lowercase couple uuid>` and tracks its own state
//      with `{ online: true, userId: <me> }`. The other client observes
//      presenceChange events and flips `partnerOnline` whenever the
//      partner's payload appears / disappears.
//   2. A 30s heartbeat that calls `update_last_seen()` RPC so the chat
//      header can show "上次在線 X 分鐘前" when the partner is offline.
//
// Channel naming MUST match Android: both use `presence:<lowercase couple
// uuid>` (no other prefix/suffix) so the two clients land in the same room.
//
// Lifecycle: heartbeat MUST pause when the app is backgrounded — RootView's
// scenePhase handler calls pause()/resume().

@MainActor
final class PresenceService: ObservableObject {

    @Published private(set) var partnerOnline: Bool = false

    private let myUserId: () -> UUID?
    private var coupleId: UUID?
    private var channel: RealtimeChannelV2?
    private var partnerKeys: Set<String> = []   // presence keys we believe are the partner
    private var presenceTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    init(myUserId: @escaping () -> UUID?) {
        self.myUserId = myUserId
    }

    // MARK: - Lifecycle

    /// Join the presence channel for this couple + start the heartbeat. If
    /// already started for the same couple this is a no-op.
    func start(coupleId: UUID) {
        if self.coupleId == coupleId, channel != nil { return }
        stop()
        self.coupleId = coupleId
        guard let me = myUserId() else { return }

        let key = "presence:\(coupleId.uuidString.lowercased())"
        let ch  = SB.client.channel(key)
        self.channel = ch

        let presenceStream = ch.presenceChange()

        presenceTask = Task { [weak self] in
            do {
                try await ch.subscribeWithError()
                // Track our own state once subscribed.
                try await ch.track(state: [
                    "online": .bool(true),
                    "userId": .string(me.uuidString)
                ])
            } catch {
                // Channel join failed — leave partnerOnline false.
                return
            }
            for await action in presenceStream {
                if Task.isCancelled { break }
                await self?.apply(action: action, me: me)
            }
        }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.beat()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    /// Leave the channel + cancel heartbeat. Called on sign-out, unpair, or
    /// when the app backgrounds.
    func stop() {
        presenceTask?.cancel(); presenceTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        if let ch = channel {
            Task { await ch.unsubscribe() }
        }
        channel = nil
        coupleId = nil
        partnerKeys.removeAll()
        partnerOnline = false
    }

    /// Background → leave channel + clear UI. Honest because we can't
    /// reliably receive frames while suspended; also stops the heartbeat.
    func pause() {
        stop()
    }

    /// Foreground → rejoin if we have a couple.
    func resume(coupleId: UUID) {
        start(coupleId: coupleId)
    }

    // MARK: - Internals

    /// Re-derive `partnerOnline` from join/leave deltas. We track presence
    /// keys (random per-tab identifiers) we believe belong to the partner;
    /// joins add, leaves remove. Anything left ⇒ partner online.
    private func apply(action: PresenceAction, me: UUID) async {
        // Walk joins — anything whose payload userId != me is the partner.
        for joinKey in action.joinedKeys {
            if let json = action.joinPayload(for: joinKey),
               json["userId"]?.stringValue != me.uuidString {
                partnerKeys.insert(joinKey)
            }
        }
        for leaveKey in action.leftKeys {
            partnerKeys.remove(leaveKey)
        }
        let next = !partnerKeys.isEmpty
        if partnerOnline != next { partnerOnline = next }
    }

    private func beat() async {
        do {
            _ = try await SB.client.rpc("update_last_seen").execute()
        } catch {
            // Heartbeat is best-effort; presence dot still works without it.
        }
    }
}

// MARK: - PresenceAction adapter
//
// supabase-swift 2.x evolved its presence types across minor versions:
// `joins`/`leaves` may be `[String: Presence]` (v2.0–2.10) or
// `[String: PresenceV2]` (later), with the payload reachable as `.state` or
// just by treating Presence as a [String: AnyJSON]. The adapter below
// reaches in via the public protocol surface so we don't pin to one shape.

private extension PresenceAction {
    var joinedKeys: [String] { Array(joins.keys) }
    var leftKeys:   [String] { Array(leaves.keys) }

    func joinPayload(for key: String) -> [String: AnyJSON]? {
        guard let presence = joins[key] else { return nil }
        // Try direct .state, fall back to JSON-encode/decode round trip so we
        // don't have to special-case private property names.
        if let mirror = Mirror(reflecting: presence).children.first(where: { $0.label == "state" }),
           let dict = mirror.value as? [String: AnyJSON] {
            return dict
        }
        return nil
    }
}

private extension AnyJSON {
    var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }
}
