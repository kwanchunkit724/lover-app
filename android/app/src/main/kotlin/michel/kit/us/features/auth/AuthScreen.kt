package michel.kit.us.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import michel.kit.us.LocalAppContainer
import michel.kit.us.R
import michel.kit.us.ui.components.ErrorToast
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

@Composable
fun AuthScreen() {
    val container = LocalAppContainer.current
    val vm: AuthViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                AuthViewModel(container.auth) as T
        }
    )
    val palette = LocalLoverColors.current
    val mode by vm.mode.collectAsStateWithLifecycle()
    val email by vm.email.collectAsStateWithLifecycle()
    val password by vm.password.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.paper)
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            stringResource(
                if (mode == AuthViewModel.Mode.SignIn) R.string.auth_title
                else R.string.auth_title_signup
            ),
            style = DSText.head(28).copy(color = palette.ink)
        )
        Spacer(Modifier.height(20.dp))

        OutlinedTextField(
            value = email,
            onValueChange = vm::setEmail,
            label = { Text(stringResource(R.string.auth_email_hint), style = DSText.ui(13)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = password,
            onValueChange = vm::setPassword,
            label = { Text(stringResource(R.string.auth_password_hint), style = DSText.ui(13)) },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(20.dp))

        Button(
            onClick = vm::submit,
            enabled = !busy,
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.rose,
                contentColor = palette.bubbleMeText
            ),
            modifier = Modifier.fillMaxWidth().height(48.dp)
        ) {
            if (busy) {
                CircularProgressIndicator(
                    color = palette.bubbleMeText,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp)
                )
            } else {
                Text(
                    text = stringResource(
                        if (mode == AuthViewModel.Mode.SignIn) R.string.auth_signin
                        else R.string.auth_signup
                    ),
                    style = DSText.ui(15)
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        TextButton(onClick = vm::toggleMode, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(
                text = stringResource(
                    if (mode == AuthViewModel.Mode.SignIn) R.string.auth_switch_to_signup
                    else R.string.auth_switch_to_signin
                ),
                style = DSText.mono(11).copy(color = palette.inkSoft)
            )
        }

        ErrorToast(message = error)
    }
}
