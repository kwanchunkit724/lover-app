package michel.kit.us

import android.app.Application
import michel.kit.us.data.PushRepository
import michel.kit.us.data.SupabaseClient

// Application class — bootstraps the Supabase singleton + any other process-
// wide state. Keep this thin: deferring heavy work to first-use keeps cold
// start fast.
class LoverApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Touch the lazy singleton so the Supabase client is constructed on
        // the main thread before any UI tries to read it. Cheap (no network).
        SupabaseClient.instance
        // Phase B Round 2 — create the FCM notification channel as early as
        // possible so a push that arrives between install and first launch
        // surfaces correctly. Token upload still defers to sign-in.
        PushRepository(applicationContext).ensureNotificationChannel()
    }
}
