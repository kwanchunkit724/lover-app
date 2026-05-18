package michel.kit.us.features.memory

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.StateFlow
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.data.EntryRepository

/**
 * Surfaces the shared [EntryRepository] state to the Memory screen. The
 * actual fetch loop is started in [michel.kit.us.LoverApp]'s root effect so
 * Memory + Time share the same item list without double polling.
 */
class MemoryViewModel(private val repo: EntryRepository) : ViewModel() {
    val items: StateFlow<List<DecryptedEntry>> = repo.items
}
