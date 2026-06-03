package michel.kit.us.features.chat

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/**
 * Port of ios/.../CameraSheet.swift + iOS PhotoPickerSheet. Provides:
 *
 *   - [rememberPhotoPickerLauncher]: gallery picker via
 *     ActivityResultContracts.PickVisualMedia. Returns a JPEG ByteArray
 *     downscaled to ~1600px / Q≈85 to match the iOS preprocessing in
 *     MediaService (iOS pre-compresses to 0.8 jpegData).
 *
 *   - [rememberCameraLauncher]: full-resolution camera capture via
 *     ActivityResultContracts.TakePicture + FileProvider. Same JPEG
 *     downscale before returning.
 *
 *   - [PhotoSourcePickerSheet]: a tiny bottom sheet asking 相機 vs 相簿,
 *     invoked when the composer's 📷 button is tapped.
 *
 * Both launchers return null on cancel.
 */
data class PhotoPickerCallbacks(
    val onPicked: (ByteArray) -> Unit,
    val onCancelled: () -> Unit = {}
)

@Composable
fun rememberPhotoGalleryLauncher(callbacks: PhotoPickerCallbacks): () -> Unit {
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
            val bytes = withContext(Dispatchers.IO) { readUriAsCompressedJpeg(ctx, uri) }
            if (bytes != null) callbacks.onPicked(bytes) else callbacks.onCancelled()
        }
    }
    return {
        launcher.launch(
            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        )
    }
}

@Composable
fun rememberCameraLauncher(callbacks: PhotoPickerCallbacks): () -> Unit {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    // Buffer the temp URI between launch() and the result callback.
    var pendingUri by remember { mutableStateOf<Uri?>(null) }
    var pendingFile by remember { mutableStateOf<File?>(null) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        val file = pendingFile
        pendingUri = null
        pendingFile = null
        if (!success || file == null || !file.exists() || file.length() == 0L) {
            file?.delete()
            callbacks.onCancelled()
            return@rememberLauncherForActivityResult
        }
        scope.launch {
            val bytes = withContext(Dispatchers.IO) { readFileAsCompressedJpeg(file) }
            file.delete()
            if (bytes != null) callbacks.onPicked(bytes) else callbacks.onCancelled()
        }
    }

    return {
        val file = File(ctx.cacheDir, "us-cam-${UUID.randomUUID()}.jpg")
        pendingFile = file
        val uri = FileProvider.getUriForFile(
            ctx,
            "${ctx.packageName}.fileprovider",
            file
        )
        pendingUri = uri
        launcher.launch(uri)
    }
}

/**
 * Bottom-sheet asking "相機 / 相簿". Mirrors iOS ChatActionSheet which
 * presents both options when the 📷 composer button is tapped.
 */
@Composable
fun PhotoSourcePickerSheet(
    onCamera: () -> Unit,
    onAlbum: () -> Unit,
    onDismiss: () -> Unit
) {
    val palette = LocalLoverColors.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 8.dp)
        ) {
            SheetOptionRow("📷  影相", palette) { onDismiss(); onCamera() }
            Spacer(Modifier.height(6.dp))
            SheetOptionRow("🖼  相簿", palette) { onDismiss(); onAlbum() }
            Spacer(Modifier.height(10.dp))
            SheetOptionRow("取消", palette, isDestructive = true) { onDismiss() }
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun SheetOptionRow(
    label: String,
    palette: michel.kit.us.ui.theme.LoverColors,
    isDestructive: Boolean = false,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color = palette.paperAlt,
        modifier = Modifier.fillMaxWidth()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 14.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                label,
                style = DSText.ui(15).copy(
                    color = if (isDestructive) palette.inkMuted else palette.ink
                )
            )
        }
    }
}

// ---------------------------------------------------------------------------
// JPEG preprocessing — downscale to max 1600px, re-encode at quality 85.
// Matches iOS MediaService preprocessing in spirit (iOS uses
// img.jpegData(compressionQuality: 0.8) without explicit resize; we resize
// because Android cameras commonly produce 4000×3000 12MP files that would
// otherwise blow past Storage limits and per-message AES-GCM cost.)

private const val MAX_DIMENSION = 1600
private const val JPEG_QUALITY = 85

private fun readUriAsCompressedJpeg(ctx: Context, uri: Uri): ByteArray? = runCatching {
    // 1) Decode bounds-only to compute inSampleSize. NOTE: an inJustDecodeBounds
    //    decode ALWAYS returns a null Bitmap by design (it only fills outWidth/
    //    outHeight), so we must NOT null-check its result — the old
    //    `?: return null` here fired every time and aborted the whole decode,
    //    which is why picking a gallery photo silently sent nothing. Only guard
    //    that the stream opened.
    val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    (ctx.contentResolver.openInputStream(uri) ?: return@runCatching null).use {
        BitmapFactory.decodeStream(it, null, boundsOpts)
    }
    val sample = computeSampleSize(boundsOpts.outWidth, boundsOpts.outHeight, MAX_DIMENSION)

    // 2) Decode at sample size.
    val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sample }
    val bitmap = ctx.contentResolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, decodeOpts)
    } ?: return@runCatching null

    // 3) Apply EXIF orientation (some Android galleries don't auto-rotate).
    //    ExifInterface(InputStream) can THROW on PNG/HEIC/screenshot streams on
    //    some platforms — guard it so a missing/invalid EXIF block never aborts
    //    the whole send (previously this threw inside the IO coroutine with no
    //    catch, so picking a PNG silently sent nothing).
    val orientation = runCatching {
        ctx.contentResolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)

    val rotated = applyExifOrientation(bitmap, orientation)
    val resized = scaleIfNeeded(rotated, MAX_DIMENSION)
    compressToJpeg(resized)
}.onFailure {
    android.util.Log.e("PhotoPicker", "readUriAsCompressedJpeg failed", it)
}.getOrNull()

private fun readFileAsCompressedJpeg(file: File): ByteArray? {
    val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.absolutePath, boundsOpts)
    val sample = computeSampleSize(boundsOpts.outWidth, boundsOpts.outHeight, MAX_DIMENSION)
    val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sample }
    val bitmap = BitmapFactory.decodeFile(file.absolutePath, decodeOpts) ?: return null

    val orientation = runCatching {
        ExifInterface(file.absolutePath).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )
    }.getOrElse { ExifInterface.ORIENTATION_NORMAL }

    val rotated = applyExifOrientation(bitmap, orientation)
    val resized = scaleIfNeeded(rotated, MAX_DIMENSION)
    return compressToJpeg(resized)
}

private fun computeSampleSize(w: Int, h: Int, max: Int): Int {
    var sample = 1
    var half = maxOf(w, h)
    while (half / 2 >= max) {
        half /= 2
        sample *= 2
    }
    return sample
}

private fun scaleIfNeeded(src: Bitmap, max: Int): Bitmap {
    val w = src.width; val h = src.height
    val longer = maxOf(w, h)
    if (longer <= max) return src
    val scale = max.toFloat() / longer
    val newW = (w * scale).toInt().coerceAtLeast(1)
    val newH = (h * scale).toInt().coerceAtLeast(1)
    val out = Bitmap.createScaledBitmap(src, newW, newH, /*filter=*/true)
    if (out !== src) src.recycle()
    return out
}

private fun applyExifOrientation(src: Bitmap, orientation: Int): Bitmap {
    val matrix = Matrix()
    when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
        ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
        else -> return src
    }
    val out = Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
    if (out !== src) src.recycle()
    return out
}

private fun compressToJpeg(bitmap: Bitmap): ByteArray {
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
    bitmap.recycle()
    return out.toByteArray()
}
