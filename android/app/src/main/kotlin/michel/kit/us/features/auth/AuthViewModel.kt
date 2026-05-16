package michel.kit.us.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import michel.kit.us.data.AuthRepository

class AuthViewModel(private val repo: AuthRepository) : ViewModel() {

    enum class Mode { SignIn, SignUp }

    private val _mode = MutableStateFlow(Mode.SignIn)
    val mode: StateFlow<Mode> = _mode.asStateFlow()

    private val _email = MutableStateFlow("")
    val email: StateFlow<String> = _email.asStateFlow()

    private val _password = MutableStateFlow("")
    val password: StateFlow<String> = _password.asStateFlow()

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun setEmail(v: String) { _email.value = v }
    fun setPassword(v: String) { _password.value = v }
    fun toggleMode() {
        _mode.value = if (_mode.value == Mode.SignIn) Mode.SignUp else Mode.SignIn
        _error.value = null
    }

    fun submit() {
        if (_busy.value) return
        val e = _email.value.trim()
        val p = _password.value
        if (!e.contains("@")) { _error.value = "唔似一個 email 地址喎"; return }
        if (p.length < 6) { _error.value = "密碼至少要 6 個字符"; return }

        _busy.value = true
        _error.value = null
        viewModelScope.launch {
            runCatching {
                if (_mode.value == Mode.SignIn) repo.signInWithEmail(e, p)
                else repo.signUpWithEmail(e, p)
            }.onFailure { _error.value = it.message }
            _busy.value = false
        }
    }
}
