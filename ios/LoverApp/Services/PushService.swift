import Foundation
import UIKit
import UserNotifications
import Supabase

// Phase 4b — iOS-side scaffold for push notifications.
//
// What ships now:
//   • Request notification permission on first sign-in
//   • Register for remote notifications, capture the APNs device token
//   • Upload the token to public.users.device_token via the
//     set_device_token RPC so future infra can read it
//
// What's deferred to Phase 6:
//   • The Edge Function on Supabase that listens for messages INSERT and
//     calls APNs to deliver an encrypted-body notification
//   • The Apple Push Notifications service key in App Store Connect
//
// The end-user impact today: enabling notifications + token storage works,
// but the locked-screen banner won't fire yet — that needs the server-side
// piece. v0.4.1 still gets you live in-app delivery via Realtime.

@MainActor
final class PushService: NSObject, ObservableObject {

    static let shared = PushService()
    private override init() { super.init() }

    /// Call once after sign-in. Triggers the system permission prompt the
    /// first time, then registers for remote notifications.
    func bootstrap() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                // User denied or system error — silently no-op, no banners.
            }
        }
    }

    /// Called by AppDelegate when APNs hands us a device token. Stores it on
    /// the user's row via RPC so the future edge function can find it.
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            do {
                try await SB.client
                    .rpc("set_device_token", params: TokenArgs(p_token: hex))
                    .execute()
            } catch {
                // Best-effort — chat still works without push.
            }
        }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        // Simulator hits this; real devices on Wi-Fi may also fail
        // intermittently. Silent — Realtime keeps the foreground chat live.
    }

    private struct TokenArgs: Encodable {
        let p_token: String
    }
}
