package michel.kit.us.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Phase A onboarding is a single welcome screen with a "Continue" CTA. The
 * iOS app has a multi-step flow (name / partner name / anniversary / theme);
 * Phase B will port it. For now we collect this data later in settings.
 */
@Composable
fun OnboardingScreen(onContinue: () -> Unit) {
    val palette = LocalLoverColors.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.paper)
            .padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Us", style = DSText.head(56).copy(color = palette.ink))
        Spacer(Modifier.height(12.dp))
        Text(
            "畀你哋兩個人嘅小天地 ૮ ˶ˆ ﻌ ˆ˶ ა",
            style = DSText.ui(15).copy(color = palette.inkSoft)
        )
        Spacer(Modifier.height(48.dp))
        Button(
            onClick = onContinue,
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.rose,
                contentColor = palette.bubbleMeText
            )
        ) {
            Text("開始", style = DSText.ui(15))
        }
    }
}
