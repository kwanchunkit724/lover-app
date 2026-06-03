package michel.kit.us.features.chat

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.util.UUID

/**
 * Voice message recorder (parity with iOS VoiceRecorder). Records AAC/m4a to a
 * temp file; stop() returns the bytes + duration for ChatRepository.sendVoice
 * (E2EE upload). Same container/codec as iOS so bubbles interoperate.
 */
class VoiceRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var startMs = 0L

    val isRecording: Boolean get() = recorder != null

    fun start(): Boolean {
        if (recorder != null) return false
        val f = File(context.cacheDir, "voice-rec-${UUID.randomUUID()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context)
                else @Suppress("DEPRECATION") MediaRecorder()
        return try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(64000)
            r.setAudioSamplingRate(24000)
            r.setOutputFile(f.absolutePath)
            r.prepare()
            r.start()
            recorder = r
            file = f
            startMs = System.currentTimeMillis()
            true
        } catch (t: Throwable) {
            runCatching { r.release() }
            f.delete()
            false
        }
    }

    /** Stop + return (bytes, durationSec). null if too short / failed. */
    fun stop(): Pair<ByteArray, Int>? {
        val r = recorder ?: return null
        val durSec = ((System.currentTimeMillis() - startMs) / 1000).toInt().coerceAtLeast(1)
        recorder = null
        return try {
            r.stop(); r.release()
            val bytes = file?.readBytes()
            file?.delete(); file = null
            if (bytes != null && bytes.isNotEmpty()) bytes to durSec else null
        } catch (t: Throwable) {
            runCatching { r.release() }
            file?.delete(); file = null
            null
        }
    }

    fun cancel() {
        val r = recorder ?: return
        recorder = null
        runCatching { r.stop() }
        runCatching { r.release() }
        file?.delete(); file = null
    }
}
