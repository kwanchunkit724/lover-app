package michel.kit.us.features.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import michel.kit.us.data.ChatRepository
import michel.kit.us.domain.DecryptedMessage
import java.util.UUID

class ChatViewModel(
    val chat: ChatRepository,
    private val meIdProvider: () -> UUID?
) : ViewModel() {

    private val _input = MutableStateFlow("")
    val input: StateFlow<String> = _input.asStateFlow()

    private val _replyTo = MutableStateFlow<DecryptedMessage?>(null)
    val replyTo: StateFlow<DecryptedMessage?> = _replyTo.asStateFlow()

    private val _reactionTarget = MutableStateFlow<DecryptedMessage?>(null)
    val reactionTarget: StateFlow<DecryptedMessage?> = _reactionTarget.asStateFlow()

    fun setInput(v: String) { _input.value = v }
    fun setReplyTo(m: DecryptedMessage?) { _replyTo.value = m }
    fun openReactionPicker(m: DecryptedMessage) { _reactionTarget.value = m }
    fun closeReactionPicker() { _reactionTarget.value = null }

    fun send() {
        val txt = _input.value.trim()
        val me = meIdProvider() ?: return
        if (txt.isEmpty()) return
        val replyId = _replyTo.value?.id
        _input.value = ""
        _replyTo.value = null
        viewModelScope.launch { chat.sendText(txt, me, replyId) }
    }

    fun unsend(m: DecryptedMessage) {
        viewModelScope.launch { chat.unsend(m.id) }
    }

    fun react(m: DecryptedMessage, emoji: String) {
        val me = meIdProvider() ?: return
        viewModelScope.launch { chat.addReaction(m.id, emoji, me) }
    }

    fun toggleVanish() {
        viewModelScope.launch { chat.setVanishMode(!chat.vanishMode.value) }
    }

    fun markRead(m: DecryptedMessage) {
        val me = meIdProvider() ?: return
        if (m.senderId == me || m.readAt != null) return
        viewModelScope.launch { chat.markRead(m.id) }
    }

    fun sendPhoto(bytes: ByteArray, caption: String? = null) {
        val me = meIdProvider() ?: return
        val replyId = _replyTo.value?.id
        _replyTo.value = null
        viewModelScope.launch { chat.sendPhoto(bytes, caption, me, replyId) }
    }

    fun sendVoice(bytes: ByteArray, durationSec: Int) {
        val me = meIdProvider() ?: return
        val replyId = _replyTo.value?.id
        _replyTo.value = null
        viewModelScope.launch { chat.sendVoice(bytes, durationSec, me, replyId) }
    }

    fun sendVideo(bytes: ByteArray, durationSec: Int) {
        val me = meIdProvider() ?: return
        val replyId = _replyTo.value?.id
        _replyTo.value = null
        viewModelScope.launch { chat.sendVideo(bytes, durationSec, me, replyId) }
    }

    /** v1.6.0 — append a kaomoji into the input field (does NOT auto-send). */
    fun appendKaomoji(kao: String) {
        _input.value = _input.value + kao
    }
}
