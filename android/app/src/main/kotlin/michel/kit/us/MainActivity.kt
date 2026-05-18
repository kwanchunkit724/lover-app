package michel.kit.us

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import michel.kit.us.ui.theme.LoverAppTheme

class MainActivity : ComponentActivity() {

    // Android 13+: POST_NOTIFICATIONS is a runtime permission. We request it
    // here once at launch — denial is fine (we silently skip pushes). The
    // FCM token still uploads either way; the channel just won't surface
    // banners until the user toggles it in OS settings.
    private val requestNotificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* no-op */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestNotificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            // Outer LoverAppTheme is a placeholder — RootRouter re-wraps with
            // the per-couple variant once the profile row loads. The outer
            // wrap exists so the OnboardingScreen + AuthScreen have a
            // sensible default palette before sign-in.
            LoverAppTheme {
                LoverApp()
            }
        }
    }
}
