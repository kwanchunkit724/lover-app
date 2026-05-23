package michel.kit.us.features.chat

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.view.ViewGroup
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import michel.kit.us.LocalAppContainer
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.io.File
import java.util.UUID

/**
 * Thumbnail + tap-to-fullscreen video bubble for v1.6.0 video messages.
 *
 * On compose: downloads + decrypts the encrypted MP4 to a tmp file once, then
 * extracts the first frame via MediaMetadataRetriever for the still preview.
 * Tap → fullscreen Dialog hosting an ExoPlayer + PlayerView reading the same
 * temp file via MediaItem.fromUri.
 */
@Composable
fun EncryptedVideoThumbnail(
    mediaHandle: String,
    durationSec: Int,
    height: Dp = 240.dp
) {
    val palette = LocalLoverColors.current
    val ctx = LocalContext.current
    val container = LocalAppContainer.current
    val media = container.chat.mediaRepository

    var thumb by remember(mediaHandle) { mutableStateOf<ImageBitmap?>(null) }
    var tempFile by remember(mediaHandle) { mutableStateOf<File?>(null) }
    var failed by remember(mediaHandle) { mutableStateOf(false) }
    var showFullscreen by remember { mutableStateOf(false) }

    LaunchedEffect(mediaHandle) {
        if (thumb != null || failed) return@LaunchedEffect
        try {
            val bytes = media.downloadAndDecrypt(mediaHandle)
            val file = withContext(Dispatchers.IO) {
                val dir = File(ctx.cacheDir, "chat-media").apply { mkdirs() }
                val f = File(dir, "us-video-${UUID.randomUUID()}.mp4")
                f.writeBytes(bytes)
                f
            }
            tempFile = file
            val bmp = withContext(Dispatchers.Default) {
                val r = MediaMetadataRetriever()
                try {
                    r.setDataSource(file.absolutePath)
                    r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                } finally { runCatching { r.release() } }
            }
            thumb = bmp?.asImageBitmap()
            if (bmp == null) failed = true
        } catch (t: Throwable) {
            failed = true
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(14.dp))
            .background(palette.paperAlt)
            .clickable(enabled = tempFile != null) { if (tempFile != null) showFullscreen = true },
        contentAlignment = Alignment.Center
    ) {
        when {
            thumb != null -> Image(
                bitmap = thumb!!,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            failed -> Text("(影片解密失敗)", style = DSText.mono(11).copy(color = palette.inkMuted))
            else -> CircularProgressIndicator(color = palette.inkMuted, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
        }
        // Play overlay
        if (thumb != null) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.45f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Outlined.PlayArrow, null, tint = Color.White, modifier = Modifier.size(32.dp))
            }
        }
        // Duration pill
        if (thumb != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(6.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.Black.copy(alpha = 0.55f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(String.format("0:%02d", durationSec), style = DSText.mono(10).copy(color = Color.White))
            }
        }
    }

    if (showFullscreen && tempFile != null) {
        FullscreenVideoDialog(file = tempFile!!, onClose = { showFullscreen = false })
    }
}

@Composable
private fun FullscreenVideoDialog(file: File, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val player = remember {
        ExoPlayer.Builder(ctx).build().apply {
            setMediaItem(MediaItem.fromUri(file.toURI().toString()))
            prepare()
            playWhenReady = true
        }
    }
    DisposableEffect(Unit) { onDispose { player.release() } }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            AndroidView(
                factory = { c ->
                    PlayerView(c).apply {
                        this.player = player
                        useController = true
                        layoutParams = ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT
                        )
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
            IconButton(
                onClick = onClose,
                modifier = Modifier.align(Alignment.TopEnd).padding(12.dp)
            ) {
                Icon(Icons.Outlined.Close, contentDescription = "關閉", tint = Color.White)
            }
        }
    }
}
