package michel.kit.us.features.activities

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import michel.kit.us.data.ActivityCatalog
import michel.kit.us.data.CatalogActivity
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * 活動 tab — port of ios/.../ActivitiesView.swift. Featured "本週推介" hero
 * card on top, then a 2-column grid of catalog tiles. Tile actions are stubs
 * in Round 1 (card-deck / quiz / districts / mtr detail screens are Round 2).
 */
@Composable
fun ActivitiesScreen() {
    val palette = LocalLoverColors.current
    val scroll = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.paper)
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp, bottom = 24.dp)
    ) {
        // Header
        Text("玩樂", style = DSText.head(32).copy(color = palette.ink))
        Spacer(Modifier.height(2.dp))
        Text("約會點子、小遊戲、測驗",
            style = DSText.mono(11).copy(color = palette.inkMuted))
        Spacer(Modifier.height(16.dp))

        // Featured card
        FeatureCard(rose = palette.rose)
        Spacer(Modifier.height(16.dp))

        // Grid (use a non-scrollable LazyVerticalGrid with a fixed height fallback)
        val tiles = ActivityCatalog.all
        // Avoid nested-scroll: render manually in 2-column rows.
        tiles.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { a ->
                    Box(Modifier.weight(1f)) { ActivityTile(a) }
                }
                if (row.size == 1) Box(Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
private fun FeatureCard(rose: Color) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(rose)
            .padding(20.dp)
    ) {
        Column {
            Text("本週推介", style = DSText.mono(10).copy(color = Color.White.copy(alpha = 0.7f)))
            Spacer(Modifier.height(4.dp))
            Text("抽張卡，今晚做乜？",
                style = DSText.head(22).copy(color = Color.White))
            Spacer(Modifier.height(6.dp))
            Text("24 個冇做過嘅約會點子\n由 random 揀",
                style = DSText.ui(13).copy(color = Color.White.copy(alpha = 0.85f)))
            Spacer(Modifier.height(14.dp))
            Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Color.White)
                    .padding(horizontal = 18.dp, vertical = 10.dp)
            ) {
                Text("抽卡 →",
                    style = DSText.ui(13, androidx.compose.ui.text.font.FontWeight.SemiBold)
                        .copy(color = rose))
            }
        }
    }
}

@Composable
private fun ActivityTile(activity: CatalogActivity) {
    val palette = LocalLoverColors.current
    val (fg, bg) = when (activity.kind) {
        CatalogActivity.Kind.cards     -> palette.rose to palette.roseSoft
        CatalogActivity.Kind.quiz      -> palette.sage to palette.sageSoft
        CatalogActivity.Kind.map,
        CatalogActivity.Kind.journal   -> palette.amber to palette.amberSoft
        CatalogActivity.Kind.districts -> palette.rose to palette.roseSoft
        CatalogActivity.Kind.mtr       -> palette.sage to palette.sageSoft
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(palette.surface)
            .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
            .clickable(onClick = { /* Round 2: detail sheets */ })
            .padding(14.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(bg),
            contentAlignment = Alignment.Center
        ) {
            Text("✦", style = DSText.head(16).copy(color = fg))
        }
        Spacer(Modifier.height(10.dp))
        Text(activity.title,
            style = DSText.ui(14, androidx.compose.ui.text.font.FontWeight.SemiBold)
                .copy(color = palette.ink))
        Spacer(Modifier.height(3.dp))
        Text(activity.subtitle,
            style = DSText.ui(11).copy(color = palette.inkSoft))
        if (activity.count != null) {
            Spacer(Modifier.height(8.dp))
            Text("${activity.count} 個",
                style = DSText.mono(10).copy(color = palette.inkMuted))
        }
    }
}
