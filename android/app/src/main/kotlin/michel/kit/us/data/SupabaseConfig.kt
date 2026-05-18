package michel.kit.us.data

// Supabase project credentials. The publishable (anon) key is intentionally
// embedded in the client — it's safe by design because Row-Level Security
// policies on every table enforce per-user access. The "secret" service_role
// key is NOT shipped; it lives only in the Supabase dashboard.
//
// Mirror of ios/LoverApp/Services/SupabaseConfig.swift — keep in sync.
object SupabaseConfig {
    const val URL: String = "https://stzfhdjuiupejonyckdu.supabase.co"
    const val ANON_KEY: String = "sb_publishable_4wk4zetQjR-E73b9D7QvKg_CdQmNil_"

    /**
     * Phase B Round 2 — Google Sign-In (Android) Web Client ID.
     *
     * Where to find it:
     *   Firebase Console → Project Settings → General → "Your apps" Android
     *   block → after enabling Google Sign-In once, a Web Client (auto-
     *   created by Google) appears in Google Cloud Console → APIs & Services
     *   → Credentials → OAuth 2.0 Client IDs → "Web client (auto created by
     *   Google Service)". Copy its Client ID (looks like
     *   `1234567890-abcdef…apps.googleusercontent.com`).
     *
     * This same value must also be entered in Supabase Dashboard →
     * Authentication → Providers → Google → "Client ID (for OAuth)". The
     * Client Secret field is required by Supabase but unused for the ID
     * Token flow we use here — paste any non-empty string or copy the web
     * client's secret from the same Google Cloud Console page.
     *
     * While this is still TODO, the AuthScreen "Continue with Google"
     * button shows an error toast instead of launching CredentialManager.
     */
    const val GOOGLE_WEB_CLIENT_ID: String = "TODO_FILL_IN_FROM_FIREBASE_CONSOLE"
}
