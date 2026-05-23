package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Bottom kaomoji panel — port of ios/.../KaomojiPicker.swift.
 *
 * Catalogue is bundled at assets/Kaomoji.json (same file as iOS Resources).
 * Shown in place of the soft keyboard; ChatScreen hides the IME first so
 * we get the freed-up vertical space.
 */
@Serializable
private data class KaomojiCatalogue(
    val version: Int = 0,
    val quick_react: List<String> = emptyList(),
    val categories: List<Category> = emptyList()
) {
    @Serializable
    data class Category(
        val id: String,
        val label_zh: String,
        val label_en: String = "",
        val label_ja: String = "",
        val entries: List<String>
    )
}

private val kaomojiJson = Json { ignoreUnknownKeys = true }

@Composable
private fun rememberCatalogue(): KaomojiCatalogue {
    val ctx = LocalContext.current
    return remember {
        runCatching {
            ctx.assets.open("Kaomoji.json").bufferedReader().use { it.readText() }
                .let { kaomojiJson.decodeFromString(KaomojiCatalogue.serializer(), it) }
        }.getOrElse { KaomojiCatalogue() }
    }
}

@Composable
fun KaomojiPickerPanel(
    onPick: (String) -> Unit,
    minHeight: androidx.compose.ui.unit.Dp = 300.dp
) {
    val palette = LocalLoverColors.current
    val catalogue = rememberCatalogue()
    var query by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf(catalogue.categories.firstOrNull()?.id ?: "recent") }

    val entries = remember(query, selected, catalogue) {
        if (query.isNotBlank()) {
            catalogue.categories.flatMap { it.entries }.filter { it.contains(query, ignoreCase = true) }
        } else if (selected == "recent") catalogue.quick_react
        else catalogue.categories.firstOrNull { it.id == selected }?.entries.orEmpty()
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = minHeight)
            .background(palette.surface)
            .border(0.5.dp, palette.line)
    ) {
        // Search row
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            BasicTextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                textStyle = DSText.ui(13).copy(color = palette.ink),
                modifier = Modifier.weight(1f),
                decorationBox = { inner ->
                    if (query.isEmpty()) {
                        Text("搜尋顏文字…", style = DSText.ui(13).copy(color = palette.inkMuted))
                    }
                    inner()
                }
            )
        }
        // Grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 8.dp),
            contentPadding = PaddingValues(vertical = 6.dp)
        ) {
            items(entries, key = { it.hashCode().toString() + it }) { kao ->
                Box(
                    modifier = Modifier
                        .padding(3.dp)
                        .heightIn(min = 40.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(palette.paperAlt)
                        .clickable { onPick(kao) }
                        .padding(vertical = 6.dp, horizontal = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(kao, style = DSText.mono(12).copy(color = palette.ink))
                }
            }
        }
        // Category strip
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            CategoryChip("最近", selected == "recent", palette) { selected = "recent"; query = "" }
            catalogue.categories.forEach { c ->
                Spacer(Modifier.width(6.dp))
                CategoryChip(c.label_zh, selected == c.id, palette) { selected = c.id; query = "" }
            }
        }
    }
}

@Composable
private fun CategoryChip(
    label: String,
    active: Boolean,
    palette: michel.kit.us.ui.theme.LoverColors,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (active) palette.rose else palette.paperAlt)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(
            label,
            style = DSText.mono(11).copy(color = if (active) palette.bubbleMeText else palette.inkSoft)
        )
    }
}
