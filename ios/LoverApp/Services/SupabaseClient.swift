import Foundation
import Supabase

// Singleton wrapper around the Supabase Swift SDK client. Used by AuthService
// for sign-in and (Phase 3b+) by PairingService and (Phase 4+) by ChatService.
//
// Usage:
//   try await SB.client.auth.signInWithIdToken(...)
//   try await SB.client.from("users").select().execute()

enum SB {
    static var client: SupabaseClient {
        if UITesting.blocksNetwork {
            preconditionFailure("UITestingScreenshotMode blocks Supabase. This launch must stay offline.")
        }
        return live
    }

    private static let live = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
