package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Pause
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import michel.kit.us.LocalAppContainer
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.io.File
import java.util.UUID

/**
 * Port of ios/.../EncryptedAudioPlayback.swift.
 *
 * On first tap: downloads the encrypted m4a blob, decrypts to a cached temp
 * file, hands it to ExoPlayer. Subsequent taps toggle play/pause.
 *
 * Waveform is the same deterministic seed-from-messageID pseudo-waveform
 * iOS uses, so a given message renders identical bars on both platforms.
 */
@Composable
fun EncryptedAudioPlayback(
    messageId: String,
    mediaHandle: String,
    durationSec: Int,
    isFromMe: Boolean
) {
    val palette = LocalLoverColors.current
    val ctx = LocalContext.current
    val container = LocalAppContainer.current
    val media = container.chat.mediaRepository
    val scope = rememberCoroutineScope()

    var isLoading by remember(mediaHandle) { mutableStateOf(false) }
    var loadedOnce by remember(mediaHandle) { mutableStateOf(false) }
    var failed by remember(mediaHandle) { mutableStateOf(false) }
    var isPlaying by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var rate by remember { mutableFloatStateOf(1f) }   // v1.6.x playback speed

    val player = remember {
        ExoPlayer.Builder(ctx).build().apply {
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) {
                    isPlaying = playing
                }
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_ENDED) {
                        isPlaying = false
                        progress = 0f
                        seekTo(0)
                    }
                }
            })
        }
    }

    DisposableEffect(Unit) {
        onDispose { player.release() }
    }

    // 80ms tick to drive progress while playing — matches iOS AudioPlayer cadence.
    LaunchedEffect(isPlaying) {
        while (isPlaying) {
            delay(80)
            val dur = player.duration.coerceAtLeast(1L)
            progress = (player.currentPosition.toFloat() / dur.toFloat()).coerceIn(0f, 1f)
        }
    }

    val fg = if (isFromMe) palette.bubbleMeText else palette.ink
    val dim = if (isFromMe) palette.bubbleMeText.copy(alpha = 0.4f) else palette.inkMuted
    val bars = remember(messageId) { waveform(messageId) }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.widthIn(min = 160.dp)
    ) {
        Box(
            modifier = Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(if (isFromMe) palette.bubbleMeText.copy(alpha = 0.2f) else palette.paperAlt),
            contentAlignment = Alignment.Center
        ) {
            when {
                isLoading -> CircularProgressIndicator(
                    color = fg,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(16.dp)
                )
                failed -> Icon(Icons.Outlined.ErrorOutline, contentDescription = null, tint = fg, modifier = Modifier.size(16.dp))
                else -> IconButton(
                    onClick = {
                        if (!loadedOnce) {
                            isLoading = true
                            scope.launch {
                                try {
                                    val bytes = media.downloadAndDecrypt(mediaHandle)
                                    val file = withContext(Dispatchers.IO) {
                                        val dir = File(ctx.cacheDir, "chat-media").apply { mkdirs() }
                                        val f = File(dir, "us-voice-${UUID.randomUUID()}.m4a")
                                        f.writeBytes(bytes)
                                        f
                                    }
                                    player.setMediaItem(MediaItem.fromUri(file.toURI().toString()))
                                    player.prepare()
                                    loadedOnce = true
                                    isLoading = false
                                    player.play()
                                } catch (t: Throwable) {
                                    failed = true
                                    isLoading = false
                                }
                            }
                        } else {
                            if (player.isPlaying) player.pause() else player.play()
                        }
                    },
                    modifier = Modifier.size(30.dp)
                ) {
                    Icon(
                        if (isPlaying) Icons.Outlined.Pause else Icons.Outlined.PlayArrow,
                        contentDescription = null,
                        tint = fg,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.height(28.dp)
        ) {
            bars.forEachIndexed { idx, h ->
                val played = idx.toFloat() / bars.size < progress
                Box(
                    modifier = Modifier
                        .width(2.5.dp)
                        .height((maxOf(6.0, h * 28.0)).dp)
                        .clip(RoundedCornerShape(50))
                        .background(if (played) fg else dim)
                )
            }
        }

        Text(
            String.format("0:%02d", durationSec),
            style = DSText.mono(10).copy(color = dim)
        )

        if (loadedOnce) {
            Text(
                if (rate == 1f) "1x" else if (rate == 1.5f) "1.5x" else "2x",
                style = DSText.mono(10).copy(color = fg),
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (isFromMe) palette.bubbleMeText.copy(alpha = 0.2f) else palette.paperAlt)
                    .clickable {
                        rate = if (rate == 1f) 1.5f else if (rate == 1.5f) 2f else 1f
                        player.setPlaybackSpeed(rate)
                    }
                    .padding(horizontal = 6.dp, vertical = 3.dp)
            )
        }
    }
}

/** Deterministic 22-bar pseudo-waveform. Must match VoicePlayback / iOS. */
private fun waveform(messageId: String): List<Double> {
    val seed = messageId.sumOf { it.code }
    return (1..22).map { i ->
        val n = (seed * (i + 1)) % 100
        0.3 + n / 100.0 * 0.7
    }
}
