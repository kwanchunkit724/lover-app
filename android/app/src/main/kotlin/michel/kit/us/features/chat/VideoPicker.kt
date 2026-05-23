package michel.kit.us.features.chat

import android.content.Context
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * v1.6.0 — video picker: PickVisualMedia(VideoOnly), then re-encode via LiTr
 * to 720p H.264 30fps ≤ 5 MB. Returns raw bytes + duration in seconds.
 *
 * Duration cap is enforced manually after pick because PickVisualMediaRequest
 * has no maxDurationMs parameter on Android.
 */
data class VideoPicked(val bytes: ByteArray, val durationSec: Int)
data class VideoPickerCallbacks(
    val onPicked: (VideoPicked) -> Unit,
    val onCancelled: () -> Unit = {},
    val onTooLong: () -> Unit = {},
    val onError: (Throwable) -> Unit = {}
)

private const val MAX_DURATION_MS = 30_000L
private const val MAX_BYTES = 25_000_000L  // ~25 MB hard cap (Supabase storage limit)

@Composable
fun rememberVideoPickerLauncher(callbacks: VideoPickerCallbacks): () -> Unit {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri == null) {
            callbacks.onCancelled()
            return@rememberLauncherForActivityResult
        }
        scope.launch {
            try {
                val durationMs = withContext(Dispatchers.IO) { readDurationMs(ctx, uri) }
                if (durationMs > MAX_DURATION_MS + 500) {
                    callbacks.onTooLong()
                    return@launch
                }
                val bytes = withContext(Dispatchers.IO) { readUriBytes(ctx, uri) }
                if (bytes.size > MAX_BYTES) {
                    callbacks.onError(RuntimeException("Video too large (>25 MB)"))
                    return@launch
                }
                val sec = (durationMs.coerceAtMost(MAX_DURATION_MS) / 1000L).toInt().coerceAtLeast(1)
                callbacks.onPicked(VideoPicked(bytes, sec))
            } catch (t: Throwable) {
                callbacks.onError(t)
            }
        }
    }
    return {
        launcher.launch(
            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
        )
    }
}

private fun readDurationMs(ctx: Context, uri: Uri): Long {
    val r = MediaMetadataRetriever()
    return try {
        r.setDataSource(ctx, uri)
        r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
    } finally { runCatching { r.release() } }
}

/**
 * v1.6.0 — read raw video bytes from URI. No transcoding (LiTr 1.5.7
 * MediaTransformer.transform signature was incompatible; deferred to v1.6.1).
 * Modern phone cameras output ≤25 MB for 30s clips, which fits Supabase
 * storage. Upstream MAX_BYTES cap rejects larger files with user error.
 */
private fun readUriBytes(ctx: Context, uri: Uri): ByteArray {
    return ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        ?: throw RuntimeException("Cannot open video URI")
}
