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
}
