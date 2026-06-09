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
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.Companion.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
import kotlinx.coroutines.launch
import michel.kit.us.LocalAppContainer
import michel.kit.us.R
import michel.kit.us.data.SupabaseConfig
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
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
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

        Spacer(Modifier.height(12.dp))

        // --- Continue with Google (Phase B Round 2) ---
        OutlinedButton(
            onClick = {
                val webClientId = SupabaseConfig.GOOGLE_WEB_CLIENT_ID
                if (webClientId.startsWith("TODO")) {
                    vm.showError("Google 登入未設定 — Web Client ID 仲未填")
                    return@OutlinedButton
                }
                vm.setBusy(true)
                coroutineScope.launch {
                    runCatching {
                        val credentialManager = CredentialManager.create(context)
                        val googleIdOption = GetGoogleIdOption.Builder()
                            .setFilterByAuthorizedAccounts(false)
                            .setServerClientId(webClientId)
                            .setAutoSelectEnabled(true)
                            .build()
                        val request = GetCredentialRequest.Builder()
                            .addCredentialOption(googleIdOption)
                            .build()
                        val result = credentialManager.getCredential(context, request)
                        val cred = result.credential
                        if (cred is CustomCredential &&
                            cred.type == TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                        ) {
                            val googleCred = GoogleIdTokenCredential.createFrom(cred.data)
                            vm.submitGoogleIdToken(googleCred.idToken)
                        } else {
                            vm.showError("唔識嘅憑證類型")
                        }
                    }.onFailure {
                        // On a Play-signed build the upload/app-signing-key SHA-1
                        // may not be registered in Google Cloud yet, so
                        // CredentialManager fails with a cryptic error. Point the
                        // tester at the always-working email/password path instead
                        // of surfacing the raw exception.
                        vm.showError("Google 登入暫時用唔到，請用上面 Email / 密碼註冊登入")
                        vm.setBusy(false)
                    }
                }
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(48.dp)
        ) {
            Text(
                text = "Continue with Google",
                style = DSText.ui(14).copy(color = palette.ink)
            )
        }

        // Debug-only anonymous sign-in — lets emulator/sideloaded testing work
        // where Google can't (signing SHA-1 not registered). Tree-shaken from
        // release behaviour by the runtime debuggable check; never shown to
        // real users.
        val isDebuggable = (context.applicationInfo.flags and
            android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebuggable) {
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = vm::signInAnonymously,
                enabled = !busy,
                modifier = Modifier.fillMaxWidth().height(46.dp)
            ) {
                Text("🧪 試玩（匿名）", style = DSText.ui(14).copy(color = palette.rose))
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
