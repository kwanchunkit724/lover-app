package michel.kit.us.features.pairing

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import michel.kit.us.data.PairingRepository
import java.time.LocalDate
import java.util.UUID

class PairingViewModel(val repo: PairingRepository) : ViewModel() {

    enum class Step { Pick, Generate, Redeem }

    private val _step = MutableStateFlow(Step.Pick)
    val step: StateFlow<Step> = _step.asStateFlow()

    private val _anniversary = MutableStateFlow(LocalDate.now())
    val anniversary: StateFlow<LocalDate> = _anniversary.asStateFlow()

    private val _codeInput = MutableStateFlow("")
    val codeInput: StateFlow<String> = _codeInput.asStateFlow()

    fun setStep(s: Step) { _step.value = s }
    fun setAnniversary(d: LocalDate) { _anniversary.value = d }
    fun setCode(c: String) { _codeInput.value = c.filter(Char::isDigit).take(6) }

    fun generate() {
        viewModelScope.launch { repo.createCode(_anniversary.value) }
    }

    fun redeem(meId: UUID, onSuccess: () -> Unit) {
        viewModelScope.launch {
            if (repo.redeem(_codeInput.value, _anniversary.value, meId)) onSuccess()
        }
    }
}
