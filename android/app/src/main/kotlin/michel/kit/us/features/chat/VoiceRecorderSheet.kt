package michel.kit.us.features.chat

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.io.File
import java.util.UUID
import kotlin.math.absoluteValue
import kotlin.math.sin

/**
 * Voice-recorder bottom sheet — port of ios/.../VoiceRecorder.swift +
 * AudioRecorder.swift fused into one Compose surface (Compose makes the
 * record/preview cycle simpler when it's all in one place).
 *
 * Audio params (must match iOS m4a output for wire compatibility):
 *   container       : MPEG-4
 *   encoder         : AAC LC
 *   sample rate     : 44 100 Hz
 *   channels        : 1 (mono)
 *   bitrate         : 64 000 bps
 *
 * Output file is `.m4a` in cacheDir. After stop() we read the file bytes
 * and delete the file (caller encrypts + uploads, never the raw file).
 *
 * Mic-permission flow runs inside the composable via
 * ActivityResultContracts.RequestPermission. If the user denies, the sheet
 * shows an inline error and only the Cancel button works.
 */
@Composable
fun VoiceRecorderSheet(
    onSend: (bytes: ByteArray, durationSec: Int) -> Unit,
    onCancel: () -> Unit
) {
    val ctx = LocalContext.current
    val palette = LocalLoverColors.current

    var permissionGranted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    var permissionDenied by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionGranted = granted
        permissionDenied = !granted
    }

    // Request on first composition if not already granted.
    LaunchedEffect(Unit) {
        if (!permissionGranted) {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    val recorder = remember { VoiceRecorderController(ctx) }
    var isRecording by remember { mutableStateOf(false) }
    var seconds by remember { mutableIntStateOf(0) }
    var errorMsg by remember { mutableStateOf<String?>(null) }

    // Start recording once permission lands.
    LaunchedEffect(permissionGranted) {
        if (permissionGranted && !isRecording && !permissionDenied) {
            val ok = runCatching { recorder.start() }
                .onFailure { errorMsg = it.message }
                .isSuccess
            if (ok) isRecording = true
        }
    }

    // 1-second tick driving the duration counter while recording.
    LaunchedEffect(isRecording) {
        while (isRecording) {
            delay(1_000)
            seconds += 1
        }
    }

    // Cleanup on dismissal.
    DisposableEffect(Unit) {
        onDispose { recorder.cancelQuietly() }
    }

    // Pulsing red dot — infinite ease in/out.
    val infinite = rememberInfiniteTransition(label = "pulse")
    val pulse by infinite.animateFloat(
        initialValue = 1f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    ModalBottomSheet(
        onDismissRequest = {
            recorder.cancelQuietly()
            onCancel()
        },
        containerColor = palette.paper
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Recording bar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(palette.roseSoft)
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .scale(if (isRecording) pulse else 1f)
                        .clip(CircleShape)
                        .background(if (isRecording) palette.rose else palette.inkMuted)
                )

                // Animated bars — same visual cadence as iOS VoiceRecorder.
                Row(
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f).height(28.dp)
                ) {
                    for (i in 0 until 28) {
                        val active = i < (seconds * 2) % 28
                        val h = if (active) {
                            8 + (sin(i.toDouble() + seconds).absoluteValue * 8).toInt()
                        } else 5
                        Box(
                            modifier = Modifier
                                .width(2.5.dp)
                                .height(h.dp)
                                .clip(RoundedCornerShape(50))
                                .background(if (active) palette.rose else Color.Black.copy(alpha = 0.15f))
                        )
                    }
                }

                Text(
                    formatSeconds(seconds),
                    style = DSText.mono(13).copy(color = palette.rose)
                )
            }

            errorMsg?.let {
                Text(
                    it,
                    style = DSText.mono(11).copy(color = palette.rose)
                )
            }
            if (permissionDenied) {
                Text(
                    "需要授權麥克風先可以錄音",
                    style = DSText.mono(11).copy(color = palette.rose)
                )
            }

            // Buttons row
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                OutlinedButton(
                    onClick = {
                        recorder.cancelQuietly()
                        onCancel()
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("取消", style = DSText.ui(14).copy(color = palette.inkSoft))
                }
                Button(
                    onClick = {
                        val result = recorder.stop()
                        isRecording = false
                        if (result != null && result.durationSec > 0) {
                            onSend(result.bytes, result.durationSec)
                        } else {
                            onCancel()
                        }
                    },
                    enabled = isRecording,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = palette.rose,
                        contentColor = Color.White,
                        disabledContainerColor = palette.line
                    ),
                    modifier = Modifier.weight(1f)
                ) {
                    Text("傳送 (${formatSeconds(seconds)})",
                        style = DSText.ui(14, androidx.compose.ui.text.font.FontWeight.SemiBold))
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

private fun formatSeconds(s: Int): String = String.format("0:%02d", s)

/**
 * Wraps MediaRecorder lifecycle. Not Composable — held in a `remember { }`
 * inside the sheet so it survives recompositions but dies with the sheet.
 */
internal class VoiceRecorderController(private val ctx: Context) {

    data class Result(val bytes: ByteArray, val durationSec: Int)

    private var recorder: MediaRecorder? = null
    private var outFile: File? = null
    private var startedAt: Long = 0L

    fun start() {
        val file = File(ctx.cacheDir, "us-voice-${UUID.randomUUID()}.m4a")
        outFile = file
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(ctx)
        } else {
            @Suppress("DEPRECATION") MediaRecorder()
        }
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioChannels(1)
        r.setAudioSamplingRate(44_100)
        r.setAudioEncodingBitRate(64_000)
        r.setOutputFile(file.absolutePath)
        r.prepare()
        r.start()
        recorder = r
        startedAt = System.currentTimeMillis()
    }

    /** Stops recording, reads + deletes the temp file, returns bytes + duration. */
    fun stop(): Result? {
        val r = recorder ?: return null
        val file = outFile
        val durationSec = ((System.currentTimeMillis() - startedAt) / 1000L)
            .toInt()
            .coerceAtLeast(1)
        recorder = null
        outFile = null
        runCatching { r.stop() }
        runCatching { r.release() }
        if (file == null || !file.exists() || file.length() == 0L) {
            file?.delete()
            return null
        }
        val bytes = file.readBytes()
        file.delete()
        return Result(bytes, durationSec)
    }

    fun cancelQuietly() {
        val r = recorder ?: return
        recorder = null
        runCatching { r.stop() }
        runCatching { r.release() }
        outFile?.delete()
        outFile = null
    }
}
