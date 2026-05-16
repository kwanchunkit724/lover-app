package michel.kit.us.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import michel.kit.us.domain.Person
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

@Composable
fun DSAvatar(person: Person, size: Dp = 36.dp, modifier: Modifier = Modifier) {
    val palette = LocalLoverColors.current
    val (bg, fg) = when (person.tint) {
        Person.Tint.rose  -> palette.roseSoft to palette.rose
        Person.Tint.sage  -> palette.sageSoft to palette.sage
        Person.Tint.amber -> palette.amberSoft to palette.amber
    }
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(bg),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = person.initial,
            style = DSText.head((size.value * 0.45f).toInt().coerceAtLeast(10)).copy(color = fg)
        )
    }
}
