package michel.kit.us.features.time

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import michel.kit.us.data.AnniversaryPayload
import michel.kit.us.data.AnniversaryRepository
import michel.kit.us.data.DecryptedAnniversary
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.data.EntryPayload
import michel.kit.us.data.EntryRepository
import michel.kit.us.util.TimeFormatting
import java.time.LocalDate
import java.util.UUID

class TimeViewModel(
    private val entries: EntryRepository,
    private val anniv: AnniversaryRepository,
    private val meIdProvider: () -> UUID?
) : ViewModel() {

    val items: StateFlow<List<DecryptedEntry>> = entries.items
    val anniversaries: StateFlow<List<DecryptedAnniversary>> = anniv.items

    private val _selectedISO = MutableStateFlow(TimeFormatting.todayISO())
    val selectedISO: StateFlow<String> = _selectedISO.asStateFlow()

    private val _viewYear = MutableStateFlow(LocalDate.now().year)
    val viewYear: StateFlow<Int> = _viewYear.asStateFlow()

    private val _viewMonth = MutableStateFlow(LocalDate.now().monthValue)
    val viewMonth: StateFlow<Int> = _viewMonth.asStateFlow()

    fun selectISO(iso: String) { _selectedISO.value = iso }

    fun prevMonth() {
        if (_viewMonth.value == 1) { _viewMonth.value = 12; _viewYear.value -= 1 }
        else _viewMonth.value -= 1
    }

    fun nextMonth() {
        if (_viewMonth.value == 12) { _viewMonth.value = 1; _viewYear.value += 1 }
        else _viewMonth.value += 1
    }

    fun addEntry(payload: EntryPayload) {
        val me = meIdProvider() ?: return
        viewModelScope.launch { entries.add(payload, me) }
    }

    fun updateEntry(id: UUID, payload: EntryPayload) {
        viewModelScope.launch { entries.update(id, payload) }
    }

    fun addAnniversary(payload: AnniversaryPayload) {
        val me = meIdProvider() ?: return
        viewModelScope.launch { anniv.add(payload, me) }
    }

    fun deleteEntry(id: UUID) {
        viewModelScope.launch { entries.delete(id) }
    }

    fun deleteAnniversary(id: UUID) {
        viewModelScope.launch { anniv.delete(id) }
    }
}
