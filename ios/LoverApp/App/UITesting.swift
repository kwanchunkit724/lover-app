import Foundation

// Launch hook for Simulator UI tests. Production launches never set the flag,
// so AuthService still bootstraps a real session and every Supabase call works
// as before.
//
// `-UITestingScreenshotMode auth` shows SignInView with no session lookup.
// `-UITestingScreenshotMode 1` and `shell` show the four-tab shell with an
// in-memory couple fixture. Neither mode may touch SB.client: a session
// refresh, pairing RPC, or `kk_purge_expired_messages` would write production.

enum UITesting {
    enum Mode: Equatable {
        case off
        case auth
        case shell
    }

    /// Stable ids for the in-memory shell. They are not production user ids.
    static let fixtureUserId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static let fixturePartnerId = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
    static let fixtureCoupleId = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!

    static func mode(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Mode {
        guard let flag = arguments.firstIndex(of: "-UITestingScreenshotMode"),
              arguments.indices.contains(flag + 1) else { return .off }
        switch arguments[flag + 1] {
        case "auth":
            return .auth
        case "1", "shell", "screenshot":
            return .shell
        default:
            return .off
        }
    }

    static var mode: Mode { mode(in: ProcessInfo.processInfo.arguments) }

    static func blocksNetwork(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        mode(in: arguments) != .off
    }

    static var blocksNetwork: Bool { blocksNetwork() }

    static var isEnabled: Bool { blocksNetwork }
}
