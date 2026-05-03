import Foundation

// Supabase project credentials. The publishable (anon) key is intentionally
// embedded in the client — it's safe by design because Row-Level Security
// policies on every table enforce per-user access. The "secret" service_role
// key is NOT shipped; it lives only in the Supabase dashboard.
//
// Project: us-app, region ap-northeast-1 (Tokyo)
// Schema:  see supabase/migrations/0001_initial_schema.sql

enum SupabaseConfig {
    static let url = URL(string: "https://stzfhdjuiupejonyckdu.supabase.co")!
    static let anonKey = "sb_publishable_4wk4zetQjR-E73b9D7QvKg_CdQmNil_"
}
