package michel.kit.us.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import michel.kit.us.LocalAppContainer
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Port of ios/.../EncryptedAsyncImage.swift. Downloads the ciphertext blob
 * from the chat-media bucket via MediaRepository, decrypts it with the
 * shared chat key, and renders the resulting JPEG.
 *
 * Cache: a process-wide LruCache of decoded ImageBitmaps keyed by
 * mediaHandle, so re-scrolling doesn't pay download+AES-GCM+decode each
 * time. Bounded to ~64 MB of RGBA pixel data (same budget as iOS).
 */
private object EncryptedImageCache {
    private const val MAX_BYTES = 64 * 1024 * 1024
    private val lru = object : LruCache<String, ImageBitmap>(MAX_BYTES) {
        override fun sizeOf(key: String, value: ImageBitmap): Int =
            value.width * value.height * 4
    }
    fun get(key: String): ImageBitmap? = synchronized(lru) { lru.get(key) }
    fun put(key: String, value: ImageBitmap) { synchronized(lru) { lru.put(key, value) } }
}

@Composable
fun EncryptedAsyncImage(
    mediaHandle: String,
    modifier: Modifier = Modifier,
    maxHeight: Dp = 240.dp,
    cornerRadius: Dp = 14.dp
) {
    val palette = LocalLoverColors.current
    val container = LocalAppContainer.current
    val media = container.chat.mediaRepository

    var image by remember(mediaHandle) { mutableStateOf<ImageBitmap?>(EncryptedImageCache.get(mediaHandle)) }
    var failed by remember(mediaHandle) { mutableStateOf(false) }

    LaunchedEffect(mediaHandle) {
        if (image != null) return@LaunchedEffect
        try {
            val bytes = media.downloadAndDecrypt(mediaHandle)
            val bmp = withContext(Dispatchers.Default) {
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
            if (bmp != null) {
                val ib = bmp.asImageBitmap()
                EncryptedImageCache.put(mediaHandle, ib)
                image = ib
            } else {
                failed = true
            }
        } catch (t: Throwable) {
            failed = true
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp, max = maxHeight)
            .clip(RoundedCornerShape(cornerRadius))
            .background(palette.paperAlt),
        contentAlignment = Alignment.Center
    ) {
        when {
            image != null -> Image(
                bitmap = image!!,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            failed -> androidx.compose.material3.Text(
                "(相片解密失敗)",
                style = DSText.mono(11).copy(color = palette.inkMuted)
            )
            else -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                androidx.compose.material3.CircularProgressIndicator(
                    color = palette.inkMuted,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(Modifier.height(6.dp))
                androidx.compose.material3.Text(
                    "正在解密…",
                    style = DSText.mono(11).copy(color = palette.inkMuted)
                )
            }
        }
    }
}
