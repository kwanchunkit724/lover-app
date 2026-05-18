package michel.kit.us.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import michel.kit.us.LocalAppContainer
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * 設定 sheet — sign out / unpair / theme picker / delete account.
 * Mirror of ios/.../ProfileView.swift's settings + account sections, with the
 * standalone ThemeSettingsView merged in inline.
 */
@Composable
fun SettingsScreen(onClose: () -> Unit) {
    val container = LocalAppContainer.current
    val palette = LocalLoverColors.current
    val scope = rememberCoroutineScope()
    val profile by container.userProfile.profile.collectAsStateWithLifecycle()
    val isPaired by container.pairing.couple.collectAsStateWithLifecycle()

    var confirmUnpair by remember { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Scaffold(
            containerColor = palette.paper,
            topBar = {
                TopAppBar(
                    title = { Text("設定",
                        style = DSText.ui(17, FontWeight.SemiBold).copy(color = palette.ink)) },
                    navigationIcon = {
                        IconButton(onClick = onClose) {
                            Icon(Icons.Outlined.ArrowBack, contentDescription = "返回",
                                tint = palette.rose)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = palette.nav)
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp)
            ) {
                // Theme picker
                Label("主題")
                Spacer(Modifier.height(8.dp))
                val themes = listOf(
                    "cream" to "Cream × Ink",
                    "jbeam" to "日系奶油"
                )
                themes.forEach { (id, name) ->
                    val active = profile?.themeId == id
                    Box(
                        Modifier.fillMaxWidth()
                            .padding(bottom = 8.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(palette.surface)
                            .border(
                                if (active) 1.5.dp else 0.5.dp,
                                if (active) palette.rose else palette.line,
                                RoundedCornerShape(14.dp)
                            )
                            .clickable { scope.launch { container.userProfile.setTheme(id) } }
                            .padding(16.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(name,
                                style = DSText.ui(15, FontWeight.SemiBold).copy(color = palette.ink))
                            Spacer(Modifier.weight(1f))
                            if (active) {
                                Text("✓", style = DSText.head(16).copy(color = palette.rose))
                            }
                        }
                    }
                }

                Spacer(Modifier.height(24.dp))
                Label("帳戶")
                Spacer(Modifier.height(8.dp))
                Column(
                    Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(palette.surface)
                        .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
                ) {
                    if (isPaired != null) {
                        SettingsRow(label = "解除配對", onClick = { confirmUnpair = true })
                    }
                    SettingsRow(label = "登出", onClick = { confirmSignOut = true })
                    SettingsRow(label = "永久刪除帳戶", danger = true,
                        onClick = { confirmDelete = true }, isLast = true)
                }
                Spacer(Modifier.height(40.dp))
            }
        }
    }

    if (confirmUnpair) {
        ConfirmDialog(
            title = "解除配對？",
            message = "會刪除你哋嘅配對。對方下次開 App 會見到要重新配對。",
            confirmLabel = "解除",
            danger = true,
            onConfirm = {
                confirmUnpair = false
                scope.launch { container.pairing.unpair() }
            },
            onDismiss = { confirmUnpair = false }
        )
    }
    if (confirmSignOut) {
        ConfirmDialog(
            title = "登出？",
            message = "配對唔會解除，下次登入返就見返一切。",
            confirmLabel = "登出",
            danger = true,
            onConfirm = {
                confirmSignOut = false
                scope.launch { container.auth.signOut() }
            },
            onDismiss = { confirmSignOut = false }
        )
    }
    if (confirmDelete) {
        DeleteAccountDialog(
            onConfirm = {
                scope.launch {
                    val ok = container.userProfile.deleteAccount()
                    if (ok) {
                        container.auth.signOut()
                        confirmDelete = false
                        onClose()
                    }
                }
            },
            onDismiss = { confirmDelete = false }
        )
    }
}

@Composable
private fun Label(text: String) {
    val palette = LocalLoverColors.current
    Text(text.uppercase(), style = DSText.mono(10).copy(color = palette.inkMuted))
}

@Composable
private fun SettingsRow(
    label: String,
    danger: Boolean = false,
    isLast: Boolean = false,
    onClick: () -> Unit
) {
    val palette = LocalLoverColors.current
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, style = DSText.ui(14)
                .copy(color = if (danger) palette.rose else palette.ink))
            Spacer(Modifier.weight(1f))
            Text("→", style = DSText.mono(13).copy(color = palette.inkMuted))
        }
        if (!isLast) {
            Box(Modifier.fillMaxWidth().height(0.5.dp).background(palette.line))
        }
    }
}

@Composable
private fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    danger: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    val palette = LocalLoverColors.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title, style = DSText.head(18).copy(color = palette.ink)) },
        text = { Text(message, style = DSText.ui(13).copy(color = palette.inkSoft)) },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(confirmLabel, style = DSText.ui(14, FontWeight.SemiBold)
                    .copy(color = if (danger) palette.rose else palette.ink))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消", style = DSText.ui(14).copy(color = palette.inkSoft))
            }
        },
        containerColor = palette.surface
    )
}

@Composable
private fun DeleteAccountDialog(onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val palette = LocalLoverColors.current
    var typed by remember { mutableStateOf("") }
    val required = "刪除我嘅帳戶"
    val canDelete = typed.trim() == required

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = RoundedCornerShape(18.dp),
            color = palette.surface
        ) {
            Column(Modifier.padding(20.dp)) {
                Text("(´｡• ω •｡`)",
                    style = DSText.mono(28).copy(color = palette.rose))
                Spacer(Modifier.height(8.dp))
                Text("永久刪除帳戶？",
                    style = DSText.head(20).copy(color = palette.ink))
                Spacer(Modifier.height(10.dp))
                Text("會刪除你嘅 profile、訊息、紀念日、entry。對方會回到「未配對」狀態。" +
                        "呢個動作即時生效，冇辦法復原。",
                    style = DSText.ui(13).copy(color = palette.inkSoft))
                Spacer(Modifier.height(14.dp))
                Text("輸入「$required」確認：",
                    style = DSText.ui(12).copy(color = palette.inkMuted))
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(
                    value = typed,
                    onValueChange = { typed = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) {
                        Text("取消")
                    }
                    Button(
                        onClick = onConfirm,
                        enabled = canDelete,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = palette.rose,
                            disabledContainerColor = palette.inkMuted
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("永久刪除")
                    }
                }
            }
        }
    }
}
