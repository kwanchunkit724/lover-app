package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import michel.kit.us.R
import michel.kit.us.data.ChatPayload
import michel.kit.us.domain.DecryptedMessage
import michel.kit.us.ui.components.BubbleShape
import michel.kit.us.ui.components.DSPhotoPlaceholder
import michel.kit.us.ui.components.EncryptedAsyncImage
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Single message bubble — port of ios/.../MessageBubble.swift.
 *
 * Layout invariant: HStack with one Spacer on the OPPOSITE side of `isFromMe`
 * so the bubble hugs the correct edge instead of floating mid-row.
 *
 * Long-press triggers [onLongPress] which the screen turns into a context
 * menu (React / Reply / Unsend). We expose it as a callback rather than a
 * baked-in ContextMenu because Compose's DropdownMenu anchor-on-long-press
 * pattern is screen-level state.
 */
@Composable
fun MessageBubble(
    message: DecryptedMessage,
    isFromMe: Boolean,
    isContinuation: Boolean,
    replyPreview: ReplyPreviewData?,
    onReact: () -> Unit,
    onReply: () -> Unit,
    onUnsend: () -> Unit,
) {
    val palette = LocalLoverColors.current
    var menuOpen by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = if (isContinuation) 0.dp else 8.dp, bottom = if (message.reactions.isEmpty()) 4.dp else 18.dp),
        horizontalAlignment = if (isFromMe) Alignment.End else Alignment.Start
    ) {
        if (replyPreview != null) {
            ReplyPreviewRow(replyPreview, isFromMe)
        }

        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isFromMe) Spacer(modifier = Modifier.weight(1f, fill = true))

            Box {
                BubbleContent(
                    message = message,
                    isFromMe = isFromMe,
                    onLongPress = { menuOpen = true }
                )
                DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false }
                ) {
                    if (!message.isDeleted) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.chat_action_react)) },
                            onClick = { menuOpen = false; onReact() }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.chat_action_reply)) },
                            onClick = { menuOpen = false; onReply() }
                        )
                    }
                    if (isFromMe && !message.isDeleted) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.chat_action_unsend), color = palette.rose) },
                            onClick = { menuOpen = false; onUnsend() }
                        )
                    }
                }
            }

            Timestamp(message, isFromMe)

            if (!isFromMe) Spacer(modifier = Modifier.weight(1f, fill = true))
        }

        if (message.reactions.isNotEmpty()) {
            ReactionsRow(message, isFromMe)
        }
    }
}

@Composable
private fun BubbleContent(
    message: DecryptedMessage,
    isFromMe: Boolean,
    onLongPress: () -> Unit
) {
    val palette = LocalLoverColors.current
    val shape = BubbleShape.forSender(isFromMe)

    when {
        message.isDeleted -> Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier
                .clip(shape)
                .border(1.dp, palette.line, shape)
                .padding(horizontal = 14.dp, vertical = 9.dp)
        ) {
            Icon(
                Icons.Outlined.Block,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = palette.inkMuted
            )
            Text(
                text = stringResource(R.string.chat_deleted_placeholder),
                style = DSText.ui(14, FontWeight.Normal).copy(color = palette.inkMuted, fontStyle = FontStyle.Italic)
            )
        }

        message.payload.kind == ChatPayload.Kind.text ||
        message.payload.kind == ChatPayload.Kind.kaomoji -> {
            Text(
                text = message.payload.text.orEmpty(),
                style = DSText.ui(15).copy(
                    color = if (isFromMe) palette.bubbleMeText else palette.bubbleThemText
                ),
                modifier = Modifier
                    .widthIn(max = 270.dp)
                    .clip(shape)
                    .background(if (isFromMe) palette.bubbleMe else palette.bubbleThem)
                    .then(
                        if (!isFromMe) Modifier.border(0.5.dp, palette.bubbleThemBorder, shape)
                        else Modifier
                    )
                    .padding(horizontal = 14.dp, vertical = 9.dp)
                    .combinedLongPress(onLongPress)
            )
        }

        message.payload.kind == ChatPayload.Kind.photo -> {
            val handle = message.payload.mediaHandle
            Column(
                modifier = Modifier
                    .width(220.dp)
                    .clip(shape)
                    .combinedLongPress(onLongPress)
            ) {
                // Real encrypted blobs live under `couple-<uuid>/...` paths.
                // Anything else (legacy / mock) falls back to the placeholder.
                if (handle != null && handle.startsWith("couple-")) {
                    EncryptedAsyncImage(
                        mediaHandle = handle,
                        maxHeight = 260.dp,
                        cornerRadius = 0.dp
                    )
                } else {
                    DSPhotoPlaceholder(
                        id = handle ?: message.id.toString(),
                        height = 260.dp
                    )
                }
                val caption = message.payload.text
                if (!caption.isNullOrEmpty()) {
                    Text(
                        text = caption,
                        style = DSText.ui(14).copy(
                            color = if (isFromMe) palette.bubbleMeText else palette.bubbleThemText
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(if (isFromMe) palette.bubbleMe else palette.bubbleThem)
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    )
                }
            }
        }

        message.payload.kind == ChatPayload.Kind.voice -> {
            val handle = message.payload.mediaHandle
            val durationSec = parseDuration(message.payload.text)
            Box(
                modifier = Modifier
                    .clip(shape)
                    .background(if (isFromMe) palette.bubbleMe else palette.bubbleThem)
                    .then(
                        if (!isFromMe) Modifier.border(0.5.dp, palette.bubbleThemBorder, shape)
                        else Modifier
                    )
                    .padding(horizontal = 10.dp, vertical = 8.dp)
                    .combinedLongPress(onLongPress)
            ) {
                if (handle != null && handle.startsWith("couple-")) {
                    EncryptedAudioPlayback(
                        messageId = message.id.toString(),
                        mediaHandle = handle,
                        durationSec = durationSec,
                        isFromMe = isFromMe
                    )
                } else {
                    // Mock / legacy — keep a simple visual placeholder.
                    Text(
                        "🎙 ${message.payload.text ?: "0:00"}",
                        style = DSText.mono(12).copy(
                            color = if (isFromMe) palette.bubbleMeText else palette.bubbleThemText
                        )
                    )
                }
            }
        }
    }
}

@Composable
private fun Timestamp(message: DecryptedMessage, isFromMe: Boolean) {
    val palette = LocalLoverColors.current
    val time = remember(message.createdAt) {
        DateTimeFormatter.ofPattern("HH:mm")
            .withZone(ZoneId.systemDefault())
            .format(message.createdAt)
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.padding(bottom = 2.dp)
    ) {
        if (message.isEdited && !message.isDeleted) {
            Text(stringResource(R.string.chat_edited_marker), style = DSText.mono(9).copy(color = palette.inkMuted))
        }
        Text(time, style = DSText.mono(10).copy(color = palette.inkMuted))
        if (isFromMe) {
            val read = message.readAt != null
            Text(
                if (read) "✓✓" else "✓",
                style = DSText.mono(10).copy(color = if (read) palette.sage else palette.inkMuted)
            )
        }
    }
}

@Composable
private fun ReactionsRow(message: DecryptedMessage, isFromMe: Boolean) {
    val palette = LocalLoverColors.current
    // Dedup by emoji — couples app has ≤2 users so "❤️ 😂" not "❤️❤️ 😂".
    val emojis = remember(message.reactions) {
        message.reactions.map { it.emoji }.distinct()
    }
    val text = emojis.joinToString(" ")
    Row(
        modifier = Modifier
            .padding(top = (-10).dp, start = 8.dp, end = 8.dp)
    ) {
        Text(
            text = text,
            style = DSText.mono(12).copy(color = palette.ink),
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(palette.surface)
                .border(0.5.dp, palette.line, RoundedCornerShape(50))
                .padding(horizontal = 8.dp, vertical = 3.dp)
        )
    }
}

data class ReplyPreviewData(
    val originalId: UUID,
    val isFromMe: Boolean,
    val preview: String
)

@Composable
private fun ReplyPreviewRow(data: ReplyPreviewData, isFromMe: Boolean) {
    val palette = LocalLoverColors.current
    Box(
        modifier = Modifier
            .widthIn(max = 200.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(palette.paperAlt)
            .padding(start = 4.dp)
            .padding(bottom = 3.dp)
    ) {
        Row {
            // Rose accent stripe
            Box(
                modifier = Modifier
                    .width(2.dp)
                    .fillMaxHeight()
                    .background(palette.rose)
            )
            Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
                Text("↰ ${stringResource(R.string.chat_action_reply)}",
                    style = DSText.mono(10).copy(color = palette.inkSoft))
                Text(
                    data.preview,
                    style = DSText.ui(11).copy(color = palette.inkMuted),
                    maxLines = 1
                )
            }
        }
    }
}

/** Parses "0:NN" voice duration strings produced by ChatRepository.sendVoice. */
private fun parseDuration(s: String?): Int {
    if (s.isNullOrEmpty()) return 0
    val parts = s.split(":")
    return parts.lastOrNull()?.toIntOrNull() ?: 0
}

/**
 * Compose doesn't have a clean "long-press only" modifier on Text without
 * also intercepting click. This extension wraps pointerInput → detectTapGestures
 * with just the long-press callback wired. NOT @Composable — Modifier
 * extensions that take a lambda parameter are plain functions.
 */
private fun Modifier.combinedLongPress(onLongPress: () -> Unit): Modifier =
    this.pointerInput(onLongPress) {
        detectTapGestures(onLongPress = { onLongPress() })
    }
