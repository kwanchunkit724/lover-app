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
import com.linkedin.android.litr.MediaTransformer
import com.linkedin.android.litr.TransformationListener
import com.linkedin.android.litr.analytics.TrackTransformationInfo
import com.linkedin.android.litr.io.MediaRange
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

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
private const val TARGET_WIDTH = 1280
private const val TARGET_HEIGHT = 720
private const val TARGET_FRAME_RATE = 30
private const val TARGET_BITRATE = 2_000_000  // ~2 Mbps → ~7.5 MB / 30s; we trim further

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
                val (bytes, sec) = withContext(Dispatchers.IO) {
                    transcodeToMp4(ctx, uri, durationMs.coerceAtMost(MAX_DURATION_MS))
                }
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
 * Re-encode via LiTr. Output is written to cache, read back into a ByteArray
 * (callers encrypt it via MediaRepository), then deleted.
 */
private suspend fun transcodeToMp4(ctx: Context, src: Uri, durationCapMs: Long): Pair<ByteArray, Int> {
    val outFile = File(ctx.cacheDir, "us-vid-${UUID.randomUUID()}.mp4")
    val requestId = UUID.randomUUID().toString()
    val transformer = MediaTransformer(ctx)
    val done = CompletableDeferred<Unit>()
    try {
        val videoFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, TARGET_WIDTH, TARGET_HEIGHT).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, TARGET_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, TARGET_FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
            setInteger(MediaFormat.KEY_COLOR_FORMAT, 0x7f000789) // COLOR_FormatSurface
        }
        val audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, 44_100, 1).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 96_000)
        }
        val listener = object : TransformationListener {
            override fun onStarted(id: String) {}
            override fun onProgress(id: String, progress: Float) {}
            override fun onCompleted(id: String, stats: MutableList<TrackTransformationInfo>?) { done.complete(Unit) }
            override fun onCancelled(id: String, stats: MutableList<TrackTransformationInfo>?) {
                done.completeExceptionally(RuntimeException("transcode cancelled"))
            }
            override fun onError(id: String, cause: Throwable?, stats: MutableList<TrackTransformationInfo>?) {
                done.completeExceptionally(cause ?: RuntimeException("transcode error"))
            }
        }
        transformer.transform(
            requestId,
            src,
            outFile.absolutePath,
            videoFormat,
            audioFormat,
            listener,
            MediaTransformer.GRANULARITY_DEFAULT,
            /* trackTransforms = */ null,
            MediaRange(0L, durationCapMs * 1000)
        )
        done.await()
        val bytes = outFile.readBytes()
        val sec = (durationCapMs / 1000L).toInt().coerceAtLeast(1)
        return bytes to sec
    } finally {
        runCatching { outFile.delete() }
        runCatching { transformer.release() }
    }
}
