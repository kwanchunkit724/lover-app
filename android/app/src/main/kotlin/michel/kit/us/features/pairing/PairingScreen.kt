package michel.kit.us.features.pairing

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import michel.kit.us.LocalAppContainer
import michel.kit.us.R
import michel.kit.us.ui.components.ErrorToast
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.util.UUID

@Composable
fun PairingScreen(meId: UUID, onPaired: () -> Unit) {
    val container = LocalAppContainer.current
    val vm: PairingViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                PairingViewModel(container.pairing) as T
        }
    )
    val palette = LocalLoverColors.current
    val step by vm.step.collectAsStateWithLifecycle()
    val anniv by vm.anniversary.collectAsStateWithLifecycle()
    val codeIn by vm.codeInput.collectAsStateWithLifecycle()
    val active by vm.repo.activeCode.collectAsStateWithLifecycle()
    val err by vm.repo.lastError.collectAsStateWithLifecycle()
    val loading by vm.repo.isLoading.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.paper)
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(stringResource(R.string.pairing_title), style = DSText.head(26).copy(color = palette.ink))
        Spacer(Modifier.height(6.dp))
        Text(stringResource(R.string.pairing_subtitle), style = DSText.mono(11).copy(color = palette.inkSoft))
        Spacer(Modifier.height(28.dp))

        // Anniversary input — date picker would be Phase B; raw ISO string for now.
        OutlinedTextField(
            value = anniv.toString(),
            onValueChange = {
                runCatching { vm.setAnniversary(java.time.LocalDate.parse(it)) }
            },
            label = { Text(stringResource(R.string.pairing_anniversary), style = DSText.ui(13)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(20.dp))

        when (step) {
            PairingViewModel.Step.Pick -> {
                Button(
                    onClick = { vm.setStep(PairingViewModel.Step.Generate); vm.generate(meId) },
                    colors = ButtonDefaults.buttonColors(containerColor = palette.rose, contentColor = palette.bubbleMeText),
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) { Text(stringResource(R.string.pairing_generate), style = DSText.ui(15)) }
                Spacer(Modifier.height(10.dp))
                OutlinedButton(
                    onClick = { vm.setStep(PairingViewModel.Step.Redeem) },
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) { Text(stringResource(R.string.pairing_redeem), style = DSText.ui(15).copy(color = palette.ink)) }
            }

            PairingViewModel.Step.Generate -> {
                Text(stringResource(R.string.pairing_share_hint), style = DSText.mono(11).copy(color = palette.inkSoft))
                Spacer(Modifier.height(8.dp))
                Text(
                    text = active?.code ?: if (loading) "..." else "—",
                    style = DSText.mono(36).copy(color = palette.rose)
                )
            }

            PairingViewModel.Step.Redeem -> {
                OutlinedTextField(
                    value = codeIn,
                    onValueChange = vm::setCode,
                    label = { Text(stringResource(R.string.pairing_code_hint), style = DSText.ui(13)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = { vm.redeem(meId, onPaired) },
                    enabled = codeIn.length == 6 && !loading,
                    colors = ButtonDefaults.buttonColors(containerColor = palette.rose, contentColor = palette.bubbleMeText),
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) { Text(stringResource(R.string.pairing_confirm), style = DSText.ui(15)) }
            }
        }

        ErrorToast(message = err)
    }
}
