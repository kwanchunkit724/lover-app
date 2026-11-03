import Foundation

/// Pure helpers for the 6-digit pairing code shown / entered in PairingView.
/// Kept free of SwiftUI / Supabase so unit tests can cover format rules without UI.
enum PairingCode {
    static let length = 6
    /// Server-side TTL mirrored for countdown UI (see PairingService.ActiveCode).
    static let ttlSeconds: TimeInterval = 10 * 60

    /// Strip non-digits and cap at `length` — same transform the enter-mode TextField applies.
    static func sanitize(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(length))
    }

    /// True iff the string is exactly 6 ASCII digits (ready to redeem).
    static func isValid(_ code: String) -> Bool {
        code.count == length && code.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    /// Seconds remaining until `expiresAt`, floored at 0.
    static func secondsRemaining(until expiresAt: Date, now: Date = Date()) -> Int {
        max(0, Int(expiresAt.timeIntervalSince(now)))
    }
}
