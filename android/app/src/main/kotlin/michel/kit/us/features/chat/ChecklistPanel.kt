package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircle
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import michel.kit.us.LocalAppContainer
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Compact top-right checklist panel (~1/4 screen). Port of the iOS
 * ChecklistSheet compact panel. Reads/writes ChecklistRepository.
 */
@Composable
fun ChecklistPanel(onClose: () -> Unit) {
    val palette = LocalLoverColors.current
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val items by container.checklist.items.collectAsStateWithLifecycle()
    val error by container.checklist.lastError.collectAsStateWithLifecycle()
    var draft by remember { mutableStateOf("") }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.12f))
            .clickable(onClick = onClose),
        contentAlignment = Alignment.TopEnd
    ) {
        Column(
            modifier = Modifier
                .padding(top = 52.dp, end = 8.dp)
                .width(252.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(palette.nav)
                // Consume taps so tapping inside the card doesn't fall through
                // to the scrim and close the panel. No ripple.
                .clickable(
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                    indication = null
                ) {}
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 9.dp)
            ) {
                Text("清單", style = DSText.ui(14, androidx.compose.ui.text.font.FontWeight.SemiBold).copy(color = palette.ink))
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onClose, modifier = Modifier.size(24.dp)) {
                    Icon(Icons.Outlined.Close, contentDescription = "關閉", tint = palette.inkMuted, modifier = Modifier.size(16.dp))
                }
            }
            HorizontalDivider(thickness = 0.5.dp, color = palette.line)

            // Add row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    singleLine = true,
                    textStyle = DSText.ui(13).copy(color = palette.ink),
                    modifier = Modifier.weight(1f),
                    decorationBox = { inner ->
                        if (draft.isEmpty()) {
                            Text("買嘢 / 做嘢…", style = DSText.ui(13).copy(color = palette.inkMuted))
                        }
                        inner()
                    }
                )
                IconButton(
                    onClick = {
                        val t = draft.trim()
                        if (t.isNotEmpty()) {
                            draft = ""
                            scope.launch { container.checklist.add(t) }
                        }
                    },
                    enabled = draft.trim().isNotEmpty()
                ) {
                    Icon(
                        Icons.Outlined.AddCircle,
                        contentDescription = "加入",
                        tint = if (draft.trim().isNotEmpty()) palette.rose else palette.inkMuted
                    )
                }
            }

            error?.let { msg ->
                Text(
                    msg,
                    style = DSText.mono(9).copy(color = palette.rose),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp)
                        .padding(bottom = 4.dp)
                        .clickable { container.checklist.clearError() }
                )
            }

            if (items.isEmpty()) {
                Text(
                    "(っ˕ -｡) 空空如也",
                    style = DSText.mono(11).copy(color = palette.inkMuted),
                    modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            } else {
                LazyColumn(modifier = Modifier.heightIn(max = 240.dp)) {
                    items(items, key = { it.id }) { item ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 7.dp)
                        ) {
                            IconButton(onClick = { scope.launch { container.checklist.toggle(item) } }, modifier = Modifier.size(28.dp)) {
                                Icon(
                                    if (item.done) Icons.Outlined.CheckCircle else Icons.Outlined.Circle,
                                    contentDescription = null,
                                    tint = if (item.done) palette.sage else palette.inkMuted,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                            Spacer(Modifier.width(8.dp))
                            Text(
                                item.text,
                                style = DSText.ui(13).copy(
                                    color = if (item.done) palette.inkMuted else palette.ink,
                                    textDecoration = if (item.done) TextDecoration.LineThrough else null
                                ),
                                modifier = Modifier.weight(1f)
                            )
                            IconButton(onClick = { scope.launch { container.checklist.remove(item) } }, modifier = Modifier.size(28.dp)) {
                                Icon(Icons.Outlined.Delete, contentDescription = "刪除", tint = palette.inkMuted, modifier = Modifier.size(14.dp))
                            }
                        }
                        HorizontalDivider(thickness = 0.5.dp, color = palette.line.copy(alpha = 0.6f))
                    }
                }
            }
        }
    }
}
