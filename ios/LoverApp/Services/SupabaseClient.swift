import Foundation
import Supabase

// Singleton wrapper around the Supabase Swift SDK client. Used by AuthService
// for sign-in and (Phase 3b+) by PairingService and (Phase 4+) by ChatService.
//
// Usage:
//   try await SB.client.auth.signInWithIdToken(...)
//   try await SB.client.from("users").select().execute()

enum SB {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
