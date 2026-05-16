package michel.kit.us.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.json.Json

// Singleton wrapper around the Supabase Kotlin SDK client. Mirror of
// ios/LoverApp/Services/SupabaseClient.swift (the `SB` enum).
//
// Usage:
//   SupabaseClient.instance.auth.signInWith(...)
//   SupabaseClient.instance.postgrest["messages"].select { ... }
object SupabaseClient {
    val instance by lazy {
        createSupabaseClient(
            supabaseUrl = SupabaseConfig.URL,
            supabaseKey = SupabaseConfig.ANON_KEY
        ) {
            install(Auth)
            install(Postgrest)
            install(Realtime)
            install(Storage)
            defaultSerializer = io.github.jan.supabase.serializer.KotlinXSerializer(
                Json {
                    ignoreUnknownKeys = true
                    explicitNulls = false
                    encodeDefaults = true
                }
            )
        }
    }
}
