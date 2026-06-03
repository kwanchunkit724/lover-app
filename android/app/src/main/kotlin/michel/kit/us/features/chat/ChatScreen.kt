package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Checklist
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.EmojiEmotions
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.Send
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.TimerOff
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.core.content.ContextCompat
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import michel.kit.us.LocalAppContainer
import michel.kit.us.R
import michel.kit.us.data.ChatPayload
import michel.kit.us.domain.DecryptedMessage
import michel.kit.us.domain.Person
import michel.kit.us.ui.components.DSAvatar
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.util.UUID

/**
 * Chat tab. Port of ios/.../ChatView.swift. Renders a LazyColumn of bubbles,
 * a composer at the bottom, with reply preview + vanish banner + reaction
 * picker overlay.
 *
 * Photo + voice send/recording are Phase B (the bubble *renders* both kinds
 * but Android composer doesn't expose the camera / voice recorder pickers
 * yet — that needs the system camera intent + audio MediaRecorder wiring).
 */
@Composable
fun ChatScreen() {
    val container = LocalAppContainer.current
    val meId by container.auth.currentUserId.collectAsStateWithLifecycle(initialValue = null)
    val partner by container.pairing.partner.collectAsStateWithLifecycle()
    val cryptoReady by container.crypto.isReady.collectAsStateWithLifecycle()
    val partnerOnline by container.presence.partnerOnline.collectAsStateWithLifecycle()

    val vm: ChatViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                ChatViewModel(container.chat, meIdProvider = { meId }) as T
        }
    )

    val palette = LocalLoverColors.current
    val messages by vm.chat.messages.collectAsStateWithLifecycle()
    val vanish by vm.chat.vanishMode.collectAsStateWithLifecycle()
    val input by vm.input.collectAsStateWithLifecycle()
    val replyTo by vm.replyTo.collectAsStateWithLifecycle()
    val reactionTarget by vm.reactionTarget.collectAsStateWithLifecycle()

    val partnerPerson = remember(partner, meId) {
        val n = partner?.myName ?: "另一半"
        Person(
            id = partner?.id ?: "partner",
            name = n,
            initial = n.firstOrNull()?.toString() ?: "?",
            tint = Person.Tint.sage,
            lastSeenAt = partner?.lastSeenAt?.let {
                runCatching { java.time.Instant.parse(it) }.getOrNull()
            }
        )
    }

    val checklistItems by container.checklist.items.collectAsStateWithLifecycle()
    var showChecklist by remember { mutableStateOf(false) }
    val myMood by container.mood.myMood.collectAsStateWithLifecycle()
    val partnerMood by container.mood.partnerMood.collectAsStateWithLifecycle()
    val incomingCheer by container.mood.incomingCheer.collectAsStateWithLifecycle()
    var showMoodPicker by remember { mutableStateOf(false) }
    var cheerTarget by remember { mutableStateOf<michel.kit.us.data.Mood?>(null) }
    val moodScope = rememberCoroutineScope()
    val meetupUpcoming by container.meetups.upcoming.collectAsStateWithLifecycle()
    var showSetMeetup by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(palette.paper)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ChatHeader(
                partner = partnerPerson,
                online = partnerOnline,
                myMood = myMood,
                partnerMood = partnerMood,
                onOpenMoodPicker = { showMoodPicker = true },
                onCheerPartner = { cheerTarget = it },
                checklistCount = checklistItems.count { !it.done },
                onOpenChecklist = { showChecklist = true }
            )

            MeetupBanner(upcoming = meetupUpcoming, onClick = { showSetMeetup = true })

            if (!cryptoReady) {
                CryptoPreparingBanner()
            }

            MessageList(
                messages = messages,
                meId = meId,
                modifier = Modifier.weight(1f),
                onReact = vm::openReactionPicker,
                onReply = vm::setReplyTo,
                onUnsend = vm::unsend,
                onMarkRead = vm::markRead
            )

            replyTo?.let { ReplyComposingRow(it, meId, onCancel = { vm.setReplyTo(null) }) }

            // ---- Media composer state — local to this screen ----
            var showPhotoSourceSheet by remember { mutableStateOf(false) }
            // v1.6.0 — kaomoji panel replaces keyboard when shown.
            var showKaomoji by remember { mutableStateOf(false) }
            val keyboard = LocalSoftwareKeyboardController.current
            val focusRequester = remember { FocusRequester() }

            val photoCallbacks = remember {
                PhotoPickerCallbacks(
                    onPicked = { bytes -> vm.sendPhoto(bytes) },
                    onCancelled = { }
                )
            }
            val launchGallery = rememberPhotoGalleryLauncher(photoCallbacks)
            val launchCamera = rememberCameraLauncher(photoCallbacks)

            // CAMERA permission gate — request lazily on first camera tap.
            val ctx = LocalContext.current
            val cameraPermissionLauncher = rememberLauncherForActivityResult(
                contract = ActivityResultContracts.RequestPermission()
            ) { granted -> if (granted) launchCamera() }

            // v1.6.0 — video picker
            val launchVideo = rememberVideoPickerLauncher(
                VideoPickerCallbacks(
                    onPicked = { picked -> vm.sendVideo(picked.bytes, picked.durationSec) },
                    onTooLong = { /* TODO snackbar — for now silently drop */ },
                    onError   = { /* swallowed: ChatRepository pushes via _lastError */ }
                )
            )

            Composer(
                value = input,
                onValueChange = { v ->
                    vm.setInput(v)
                    // typing dismisses the kaomoji panel automatically
                    if (showKaomoji && v != input) showKaomoji = false
                },
                enabled = cryptoReady,
                onSend = vm::send,
                onTapPhoto = { showPhotoSourceSheet = true },
                onTapKaomoji = {
                    if (showKaomoji) {
                        showKaomoji = false
                        focusRequester.requestFocus()
                        keyboard?.show()
                    } else {
                        keyboard?.hide()
                        showKaomoji = true
                    }
                },
                onTapVideo = launchVideo,
                onTextFieldFocused = {
                    if (showKaomoji) showKaomoji = false
                },
                focusRequester = focusRequester
            )

            if (showKaomoji) {
                KaomojiPickerPanel(
                    onPick = { kao -> vm.appendKaomoji(kao) }
                )
            }

            if (showPhotoSourceSheet) {
                PhotoSourcePickerSheet(
                    onCamera = {
                        val granted = ContextCompat.checkSelfPermission(
                            ctx, Manifest.permission.CAMERA
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) launchCamera()
                        else cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                    },
                    onAlbum = { launchGallery() },
                    onDismiss = { showPhotoSourceSheet = false }
                )
            }
        }

        reactionTarget?.let { target ->
            ReactionPickerSheet(
                onPick = { vm.react(target, it) },
                onClose = vm::closeReactionPicker
            )
        }

        if (showChecklist) {
            ChecklistPanel(onClose = { showChecklist = false })
        }

        if (showMoodPicker) {
            MoodPickerDialog(
                current = myMood,
                onPick = { m -> moodScope.launch { container.mood.setMood(m) } },
                onClose = { showMoodPicker = false }
            )
        }
        cheerTarget?.let { target ->
            CheerOverlay(
                partnerName = partnerPerson.name,
                mood = target,
                onComplete = {
                    container.mood.markPartnerCheered()
                    val me = meId
                    moodScope.launch {
                        container.mood.sendCheerComplete(target)
                        if (me != null) container.chat.sendText(target.cheerDoneMessage, me)
                    }
                },
                onClose = { cheerTarget = null }
            )
        }
        incomingCheer?.let { m ->
            CheerReceivedOverlay(
                partnerName = partnerPerson.name,
                mood = m,
                onClose = { container.mood.consumeIncomingCheer() }
            )
        }

        if (showSetMeetup) {
            SetMeetupDialog(
                existing = meetupUpcoming,
                onCreate = { iso, title -> moodScope.launch { container.meetups.createMeetup(iso, title) } },
                onCancelMeetup = { id -> moodScope.launch { container.meetups.cancelMeetup(UUID.fromString(id)) } },
                onClose = { showSetMeetup = false }
            )
        }
    }
}

@Composable
private fun ChatHeader(
    partner: Person,
    online: Boolean,
    myMood: michel.kit.us.data.Mood?,
    partnerMood: michel.kit.us.data.Mood?,
    onOpenMoodPicker: () -> Unit,
    onCheerPartner: (michel.kit.us.data.Mood) -> Unit,
    checklistCount: Int,
    onOpenChecklist: () -> Unit
) {
    val palette = LocalLoverColors.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.nav)
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        DSAvatar(partner, size = 36.dp)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(partner.name, style = DSText.ui(16, androidx.compose.ui.text.font.FontWeight.SemiBold).copy(color = palette.ink))
                Spacer(Modifier.width(6.dp))
                Text("♡", style = DSText.mono(11).copy(color = palette.rose))
            }
            // Phase C — real presence: green dot + 在線 when online,
            // "上次在線 X 分鐘前" via partner.lastSeenAt when offline,
            // empty when neither signal available yet.
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (online) {
                    Text(
                        "●",
                        style = DSText.mono(10).copy(color = Color(0xFF34C759))
                    )
                    Spacer(Modifier.width(4.dp))
                }
                Text(
                    text = presenceLabel(online, partner.lastSeenAt),
                    style = DSText.mono(10).copy(color = palette.sage)
                )
            }
        }
        // v1.6.x — partner mood (tap to cheer) + my mood chip.
        partnerMood?.let { pm ->
            MoodChip(kao = pm.kao, tint = palette.rose, faded = false, bg = palette.roseSoft) { onCheerPartner(pm) }
            Spacer(Modifier.width(6.dp))
        }
        MoodChip(
            kao = myMood?.kao ?: "(･_･)",
            tint = palette.inkMuted,
            faded = myMood == null,
            bg = palette.paperAlt,
            onClick = onOpenMoodPicker
        )
        Spacer(Modifier.width(2.dp))

        IconButton(onClick = onOpenChecklist) {
            BadgedBox(badge = {
                if (checklistCount > 0) Badge(containerColor = palette.rose) { Text("$checklistCount") }
            }) {
                Icon(
                    imageVector = Icons.Outlined.Checklist,
                    contentDescription = "清單",
                    tint = palette.inkMuted
                )
            }
        }
    }
    HorizontalDivider(thickness = 0.5.dp, color = palette.line)
}

@Composable
private fun VanishBanner() {
    val palette = LocalLoverColors.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.roseSoft)
            .padding(horizontal = 14.dp, vertical = 6.dp)
    ) {
        Icon(Icons.Outlined.Timer, contentDescription = null, modifier = Modifier.size(14.dp), tint = palette.rose)
        Text(
            stringResource(R.string.chat_vanish_banner),
            style = DSText.mono(11, androidx.compose.ui.text.font.FontWeight.Medium).copy(color = palette.ink)
        )
    }
    HorizontalDivider(thickness = 0.5.dp, color = palette.line)
}

@Composable
private fun CryptoPreparingBanner() {
    val palette = LocalLoverColors.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.amberSoft)
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        CircularProgressIndicator(color = palette.rose, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
        Text(
            stringResource(R.string.chat_crypto_preparing),
            style = DSText.ui(12, androidx.compose.ui.text.font.FontWeight.SemiBold).copy(color = palette.ink)
        )
    }
    HorizontalDivider(thickness = 0.5.dp, color = palette.line)
}

@Composable
private fun MessageList(
    messages: List<DecryptedMessage>,
    meId: UUID?,
    modifier: Modifier,
    onReact: (DecryptedMessage) -> Unit,
    onReply: (DecryptedMessage) -> Unit,
    onUnsend: (DecryptedMessage) -> Unit,
    onMarkRead: (DecryptedMessage) -> Unit,
) {
    val palette = LocalLoverColors.current
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Lookup table so reply previews can resolve.
    val byId = remember(messages) { messages.associateBy { it.id } }

    // Auto-scroll to bottom on new message + on first composition.
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            scope.launch { listState.animateScrollToItem(messages.lastIndex) }
        }
    }

    if (messages.isEmpty()) {
        Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            Text(
                stringResource(R.string.chat_empty),
                style = DSText.mono(12).copy(color = palette.inkMuted),
                modifier = Modifier.padding(top = 80.dp)
            )
        }
        return
    }

    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = 6.dp, start = 14.dp, end = 14.dp)
    ) {
        items(messages, key = { it.id.toString() }) { m ->
            val isFromMe = meId != null && m.senderId == meId
            val prevIndex = messages.indexOf(m) - 1
            val prev = if (prevIndex >= 0) messages[prevIndex] else null
            val isContinuation = prev?.senderId == m.senderId

            val replyPreview = m.replyToId?.let { rid ->
                byId[rid]?.let { orig ->
                    ReplyPreviewData(
                        originalId = orig.id,
                        isFromMe = meId != null && orig.senderId == meId,
                        preview = when {
                            orig.isDeleted -> "已撤回嘅訊息"
                            orig.payload.kind == ChatPayload.Kind.photo -> orig.payload.text ?: "📷 相片"
                            orig.payload.kind == ChatPayload.Kind.voice -> "🎙 語音訊息"
                            orig.payload.kind == ChatPayload.Kind.video -> "📹 影片"
                            else -> orig.payload.text.orEmpty()
                        }
                    )
                }
            }

            MessageBubble(
                message = m,
                isFromMe = isFromMe,
                isContinuation = isContinuation,
                replyPreview = replyPreview,
                onReact = { onReact(m) },
                onReply = { onReply(m) },
                onUnsend = { onUnsend(m) }
            )

            // Auto mark-read when an incoming bubble first appears.
            LaunchedEffect(m.id) { onMarkRead(m) }
        }
    }
}

@Composable
private fun ReplyComposingRow(
    target: DecryptedMessage,
    meId: UUID?,
    onCancel: () -> Unit
) {
    val palette = LocalLoverColors.current
    val displayName = if (meId != null && target.senderId == meId) "你自己" else "對方"
    val preview = when {
        target.isDeleted -> stringResource(R.string.chat_deleted_message)
        target.payload.kind == ChatPayload.Kind.photo -> target.payload.text ?: "📷 相片"
        target.payload.kind == ChatPayload.Kind.voice -> "🎙 語音訊息"
        target.payload.kind == ChatPayload.Kind.video -> "📹 影片"
        else -> target.payload.text.orEmpty()
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.paperAlt)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Box(modifier = Modifier.size(width = 3.dp, height = 28.dp).clip(RoundedCornerShape(50)).background(palette.rose))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                stringResource(R.string.chat_reply_to, displayName),
                style = DSText.mono(11, androidx.compose.ui.text.font.FontWeight.SemiBold).copy(color = palette.rose)
            )
            Text(preview, style = DSText.ui(12).copy(color = palette.inkSoft), maxLines = 1)
        }
        IconButton(onClick = onCancel) {
            Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.common_cancel), tint = palette.inkMuted, modifier = Modifier.size(16.dp))
        }
    }
    HorizontalDivider(thickness = 0.5.dp, color = palette.line)
}

@Composable
private fun Composer(
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean,
    onSend: () -> Unit,
    onTapPhoto: () -> Unit,
    onTapKaomoji: () -> Unit,
    onTapVideo: () -> Unit,
    onTextFieldFocused: () -> Unit,
    focusRequester: FocusRequester
) {
    val palette = LocalLoverColors.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.nav)
            .padding(horizontal = 6.dp, vertical = 6.dp)
    ) {
        // 📷 photo source picker
        IconButton(onClick = onTapPhoto, enabled = enabled) {
            Icon(
                Icons.Outlined.PhotoCamera,
                contentDescription = "相片",
                tint = if (enabled) palette.rose else palette.inkMuted,
                modifier = Modifier.size(22.dp)
            )
        }
        // 📹 video picker (v1.6.0 — replaces 🎤)
        IconButton(onClick = onTapVideo, enabled = enabled) {
            Icon(
                Icons.Outlined.Videocam,
                contentDescription = "影片",
                tint = if (enabled) palette.rose else palette.inkMuted,
                modifier = Modifier.size(22.dp)
            )
        }
        // 顔 kaomoji panel toggle
        IconButton(onClick = onTapKaomoji, enabled = enabled) {
            Icon(
                Icons.Outlined.EmojiEmotions,
                contentDescription = "顏文字",
                tint = if (enabled) palette.rose else palette.inkMuted,
                modifier = Modifier.size(22.dp)
            )
        }

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            placeholder = { Text(stringResource(R.string.chat_input_hint), style = DSText.ui(14).copy(color = palette.inkMuted)) },
            modifier = Modifier
                .weight(1f)
                .focusRequester(focusRequester)
                .onFocusChanged { st -> if (st.isFocused) onTextFieldFocused() },
            shape = RoundedCornerShape(22.dp),
            singleLine = false,
            maxLines = 4,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = palette.lineStrong,
                unfocusedBorderColor = palette.line,
                focusedContainerColor = palette.surface,
                unfocusedContainerColor = palette.surface
            )
        )
        Spacer(Modifier.width(6.dp))
        FilledIconButton(
            onClick = onSend,
            enabled = enabled && value.isNotBlank(),
            colors = IconButtonDefaults.filledIconButtonColors(
                containerColor = palette.rose,
                contentColor = palette.bubbleMeText,
                disabledContainerColor = palette.line
            )
        ) {
            Icon(Icons.Outlined.Send, contentDescription = stringResource(R.string.chat_send), modifier = Modifier.size(18.dp))
        }
    }
}

/**
 * Phase C — string shown next to the green dot in the chat header.
 *   * online → "在線"
 *   * offline + last_seen_at known → "上次在線 X 分鐘前 / X 小時前 / X 日前"
 *   * neither → "" (header still shows the name + ♡)
 */
private fun presenceLabel(online: Boolean, lastSeen: java.time.Instant?): String {
    if (online) return "在線"
    if (lastSeen == null) return ""
    val secs = java.time.Duration.between(lastSeen, java.time.Instant.now()).seconds
        .coerceAtLeast(0)
    return when {
        secs < 60 -> "上次在線 啱啱"
        secs < 3600 -> "上次在線 ${secs / 60} 分鐘前"
        secs < 86400 -> "上次在線 ${secs / 3600} 小時前"
        else -> "上次在線 ${secs / 86400} 日前"
    }
}
