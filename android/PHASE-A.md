# Phase A — Android scaffold (auth + pairing + chat)

Status: scaffolded, **not yet built**. The user must open the project in
Android Studio to run the first Gradle sync, which downloads the Gradle
distribution + AGP + Kotlin compiler + Compose BOM + Supabase SDK.

Target parity: feature-equivalent to the iOS app's chat (v1.5 — IG-style
features). Activities / Memory / Time / Settings tabs are placeholder
"即將推出" screens — Phase B.

---

## 1. Files created

### Project root (`android/`)

| File | Purpose |
|---|---|
| `settings.gradle.kts` | Plugin + dep resolution config, single `:app` module |
| `build.gradle.kts` | Top-level plugin versions (AGP 8.7.2, Kotlin 2.0.21, Compose plugin, Serialization plugin) |
| `gradle.properties` | JVM heap 3 GB, AndroidX on, Kotlin code-style official, parallel + caching + config-cache |
| `local.properties.example` | Comment-only template; Android Studio creates the real `local.properties` on first open |
| `.gitignore` | Standard Android ignores + IDE noise |
| `gradle/wrapper/gradle-wrapper.properties` | Gradle 8.10.2 distribution URL (wrapper jar comes from `gradle wrapper` task on first sync, or copy from any other AS project) |

### App module (`android/app/`)

| File | Purpose |
|---|---|
| `app/build.gradle.kts` | namespace+applicationId `michel.kit.us`, versionName `1.5.0`, all deps (Compose BOM 2024.11, Supabase BOM 3.1.4, BouncyCastle, Coil, DataStore, security-crypto) |
| `app/proguard-rules.pro` | Keep rules for Supabase + Ktor + kotlinx-serialization + BouncyCastle reflection |
| `app/src/main/AndroidManifest.xml` | Permissions (INTERNET, RECORD_AUDIO, CAMERA, READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE ≤32, POST_NOTIFICATIONS), MainActivity, Application class |
| `app/src/main/res/values/strings.xml` | Default zh-Hant strings (Cantonese tone matched to iOS) |
| `app/src/main/res/values-en/strings.xml` | English overrides |
| `app/src/main/res/values-ja/strings.xml` | Japanese overrides |
| `app/src/main/res/values/themes.xml` | Theme.Material3.DayNight.NoActionBar parent, transparent system bars |
| `app/src/main/res/xml/data_extraction_rules.xml` | Exclude `lover_secure_prefs.xml` (X25519 key) + datastore from cloud backup / device transfer |
| `app/src/main/res/xml/backup_rules.xml` | Legacy (API ≤31) auto-backup exclusions |
| `app/src/main/res/mipmap-anydpi-v26/ic_launcher{,_round}.xml` + `drawable/ic_launcher_{background,foreground}.xml` | Placeholder cream + ink "Us" wordmark launcher icon |

### Kotlin source (`app/src/main/kotlin/michel/kit/us/`)

#### Top level
- `LoverApplication.kt` — Application class; warms the Supabase singleton.
- `MainActivity.kt` — single ComponentActivity; `setContent { LoverAppTheme { LoverApp() } }`, edge-to-edge.
- `LoverApp.kt` — root navigation; routes `OnboardingScreen` → `AuthScreen` → `PairingScreen` → `MainTabs` (bottom-nav with placeholder tabs for everything except Chat).
- `AppContainer.kt` — manual DI container (avoids pulling in Hilt). Exposes singleton repos via `LocalAppContainer`.

#### `data/`
- `SupabaseConfig.kt` — same URL + anon key as iOS.
- `SupabaseClient.kt` — singleton with Auth + Postgrest + Realtime + Storage installed.
- `AuthRepository.kt` — email + password sign-in / sign-up / sign-out, plus the `users` upsert that uploads the X25519 public key (mirror of iOS `AuthService.upsertProfile`).
- `KeyManager.kt` — X25519 private key in `EncryptedSharedPreferences` (Android Keystore-backed AES-256-GCM wrapping). Generates on first use; resets on sign-out.
- `CryptoService.kt` — **the wire-critical file.** X25519 ECDH via BouncyCastle, HKDF-SHA256 via BouncyCastle, AES-256-GCM via `javax.crypto`. Salt is `coupleId.toString().uppercase()` (matches iOS `UUID.uuidString`); info is `"us.chat.v1"`; sealed-box layout `[12-byte nonce | ciphertext | 16-byte tag]`. Decrypts iOS-produced ciphertext provided couple_id is set correctly.
- `PairingRepository.kt` — `create_pairing_code` + `redeem_pairing_code` + `unpair` RPC wrappers. Mirrors iOS error-message mapping for Cantonese friendly errors.
- `ChatRepository.kt` — port of iOS `ChatService`: send / edit / unsend / mark-read / reactions / vanish. Realtime listens on channel `"messages-<lowercase couple uuid>"` with filter `couple_id=eq.<lowercase uuid>`. 5s poll fallback. Soft-deleted rendering + client-side TTL filter. Reaction merge cache to avoid race with `fetchOnce()`.

#### `domain/`
- `Message.kt` — `DecryptedMessage` data class + `ReactionAtom`. `@Immutable` for Compose stability.
- `Person.kt` — identity card with tint enum.
- `Couple.kt` — pair model.

#### `ui/theme/`
- `Color.kt` — `LoverColors` palette + `LoverPalette.Cream` (default) + `LoverPalette.Jbeam` (matches iOS exactly).
- `Theme.kt` — `LoverAppTheme` composable + `LocalLoverColors` CompositionLocal for per-couple theme variant.
- `Typography.kt` — `DSText.head` (serif) / `DSText.ui` (sans) / `DSText.mono` (monospace) using system families as Phase A fallback.

#### `ui/components/`
- `BubbleShape.kt` — 18/6 dp asymmetric `RoundedCornerShape` for speech bubble.
- `DSAvatar.kt` — circular avatar with initial.
- `DSChip.kt` — bordered capsule label.
- `DSIcon.kt` — Material Icons wrapper.
- `DSPhotoPlaceholder.kt` — placeholder when photo asset not loaded.
- `ErrorToast.kt` — auto-fade error banner.

#### `features/auth/`
- `AuthViewModel.kt` — email/password state + sign-in/sign-up dispatch.
- `AuthScreen.kt` — email + password form, mode toggle, error toast.

#### `features/pairing/`
- `PairingViewModel.kt` — generate / redeem orchestration with anniversary picker state.
- `PairingScreen.kt` — Generate vs Redeem flows, code display, anniversary text input.

#### `features/chat/`
- `ChatViewModel.kt` — input, replyTo, reactionTarget state; send / unsend / react / toggle-vanish / mark-read actions.
- `ChatScreen.kt` — Header (avatar + vanish toggle), CryptoPreparingBanner, VanishBanner, LazyColumn of bubbles with auto-scroll, ReplyComposingRow, Composer with rose Send button, ReactionPickerSheet overlay.
- `MessageBubble.kt` — text / photo / voice / deleted variants, reply preview header, reactions row capsule, edit + read marker, long-press DropdownMenu (React / Reply / Unsend).
- `ReactionPickerSheet.kt` — 6-emoji capsule overlay (❤️ 😂 😮 😢 🥰 👍).

#### `features/onboarding/`
- `OnboardingScreen.kt` — single welcome screen ("Us" + tagline + Continue CTA).

---

## 2. iOS behaviours not yet replicated

| iOS feature | Android status | Reason |
|---|---|---|
| Sign-in-with-Apple | Skipped | No Android equivalent. **Email/password is the Phase A replacement.** Google Sign-In via Credential Manager is the Android-parity option for Phase B (needs Web Client ID + Play upload key SHA-1). |
| Email magic link / OTP | Skipped | Not needed for Phase A bring-up; Supabase project supports it server-side, just no UI wired. |
| Multi-step onboarding (name / partner name / anniversary / theme) | Single welcome screen + defaults | Phase B; Android `AuthRepository.upsertProfile` currently writes placeholder name + today's date + `cream` theme so the user row exists for pairing. |
| In-app photo picker + camera + voice recorder | Bubbles render but composer doesn't expose pickers | Needs ActivityResultContracts wiring + MediaRecorder for voice — Phase B (parity with `CameraSheet.swift` + `VoiceRecorder.swift`). |
| Encrypted photo download + display (`EncryptedAsyncImage`) | Uses `DSPhotoPlaceholder` for now | Needs Coil custom Fetcher + decrypt-in-memory pipeline — Phase B. |
| Encrypted audio playback (`EncryptedAudioPlayback`) | Voice bubble shows duration text only | Needs ExoPlayer + decrypt-stream — Phase B. |
| Push notifications (`PushService.swift`) | Manifest permission declared, no FCM wiring | Phase B; Supabase has the user row + iOS device token column; Android needs `firebase-messaging` + a server-side `apns_token` ↔ `fcm_token` discriminator column. |
| Custom Japanese fonts (Klee One, Zen Maru Gothic, DM Mono) | System fallbacks (serif / sans / monospace) | Will copy TTFs to `res/font/` + reference via `FontFamily` in Phase B. |
| Per-couple theme variant from `users.theme_id` | Defaults to `cream` for everyone | Phase B settings will read partner's theme_id and pass it to `LoverAppTheme(variant = ...)`. |
| `MainTabView` Activities / Memory / Time / Settings | "即將推出" placeholder cards | Phase B. |
| Diagnostic crypto banner (partner pubkey length, my-key status, last error) | Simple "preparing..." spinner | Useful debug aid; can port in Phase B if pairing is flaky in the field. |
| Account deletion RPC | Not wired in UI | Apple-store requirement only; Play Store has its own mechanism (Data deletion URL in console). Trivial port when Settings ships. |

---

## 3. Manual steps for the user

1. **Open `android/` in Android Studio Ladybug or newer (AGP 8.7 requires AS Ladybug).** Studio writes `local.properties` automatically.
2. On first sync, Studio downloads Gradle 8.10.2 + AGP 8.7.2 + Kotlin 2.0.21 + Compose plugin + the Supabase BOM. Allow ~5 minutes on first run.
3. **Gradle wrapper jar:** I wrote `gradle-wrapper.properties` but did *not* commit a `gradle-wrapper.jar`. Studio offers "Generate Gradle wrapper" on first sync; alternatively run `gradle wrapper --gradle-version 8.10.2` once you have Gradle on the path. (Most users let Studio do it.)
4. Connect an emulator or device on API 26+. Run target `:app`.
5. **Sign up with a new email/password account** to test against the existing Supabase project (Tokyo). RLS will scope you to your own rows.
6. **Pairing test:** generate a code on one device, redeem it on the other (or on an iPhone running the iOS build) — same six-digit code + matching anniversary.
7. **For Google Sign-In (Phase B prep):** generate the Play upload keystore (`keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), get its SHA-1, register an Android client in the Supabase project's Google Cloud OAuth consent screen, paste the Web Client ID into a new `BuildConfig` field — then we wire `signInWithIdToken`.

---

## 4. Known gaps / Phase B TODOs

- **Build verification.** I authored the code on Windows without running Gradle. There may be import nits the first sync surfaces — most likely:
  - `Postgrest.Columns` API path may differ slightly across Supabase Kotlin BOM minors. If `Columns.list(...)` doesn't compile, replace with the string-overload variant (`select { columns = "vanish_mode" }`).
  - `Postgrest.filter { isIn(...) }` is the current SDK spelling; older betas used `Postgrest.filter { in(...) }`. Adjust if the compiler complains.
  - Realtime DSL `channel.postgresChangeFlow<PostgresAction.Insert>` is the 3.x spelling; if pinned to an older BOM use `channel.postgresChangeFlow(PostgresAction.Insert::class) { ... }`.
- **Activities / Memory / Time / Settings tabs.** All stub.
- **Onboarding profile collection.** Stub.
- **Photo / camera / voice composer.** Stub (bubbles render, composer can't send).
- **Encrypted media download.** Stub.
- **FCM push notifications.** Stub.
- **Custom fonts.** System fallback.
- **Date picker for anniversary.** Plain text field (`LocalDate.parse`) — replace with M3 `DatePickerDialog`.
- **Account deletion in Settings.**
- **Theme variant from partner row.** Hardcoded `cream`.
- **Realtime reconnect-on-network-change.** The 5s poll keeps the chat fresh, but Phase B should add NetworkCallback to reset the websocket cleanly.
- **Tests.** Phase B: at minimum a CryptoService round-trip + a fake-Postgrest ChatRepository test.

---

## 5. How to verify chat wire compatibility with iOS

This is the single most important property to validate before shipping
Android, because a crypto mismatch silently breaks both apps with "無法解密"
placeholders.

### 5.1 Manual end-to-end test (recommended first)

1. Build + install both iOS (TestFlight v1.5+) and Android (Phase A) on two
   physical phones — or one phone + one emulator.
2. Sign in as **two distinct test accounts** (e.g. `kit-test@…` and
   `michel-test@…`). Sign Android in with email/password; iOS can use either
   Apple ID or email magic link.
3. Verify both `public.users` rows have a non-null `public_key` (32-byte
   base64 → 44 chars).
4. Pair them with a matching anniversary.
5. Send a message **from iOS → received on Android.** Decrypted plaintext
   should match exactly (Cantonese / emoji / multi-line OK).
6. Send a message **from Android → received on iOS.** Same.
7. Test the IG features each direction:
   - Reply (the original bubble's preview shows above)
   - Emoji react (long-press → picker → emoji shows on bubble)
   - Edit (sender side — iOS only for now since Android composer doesn't
     surface an Edit UI; backend update path is identical)
   - Unsend (long-press → 撤回 → dashed-stroke "已撤回" placeholder on both)
   - Vanish mode toggle (the rose-soft 24h banner appears on both)
   - Read receipt (✓ → ✓✓ when partner sees the bubble)

If step 5 or 6 surfaces "(無法解密 — 可能對方換咗 device)", the bug is in
HKDF/AES — see 5.3.

### 5.2 Round-trip unit test (Phase B — write before shipping)

```kotlin
@Test fun decrypts_iOS_produced_blob() {
    val crypto = CryptoService()
    val coupleId = UUID.fromString("550E8400-E29B-41D4-A716-446655440000")
    crypto.prepare(
        coupleId,
        partnerPublicKeyBase64 = IOS_FIXTURE_PARTNER_PUB_B64,
        myPrivateKey = IOS_FIXTURE_MY_PRIV_RAW
    )
    val payload = crypto.open(IOS_FIXTURE_CIPHERTEXT_B64)
    assertEquals("hello from iOS", payload.text)
}
```

Capture fixtures with a one-off iOS debug build that prints the four values
to console for a known plaintext.

### 5.3 If decrypt fails — checklist

The HKDF salt is the most common foot-gun. Verify on both sides:

| Parameter | Value | Notes |
|---|---|---|
| Curve | X25519 (Curve25519) | 32 raw bytes priv, 32 raw bytes pub |
| ECDH output | Raw 32 bytes | No HKDF inside `sharedSecretFromKeyAgreement` |
| HKDF hash | SHA-256 | |
| HKDF salt | `UTF-8(coupleId.uuidString)` — **UPPERCASE UUID string** | iOS `UUID.uuidString` is uppercase; Android `UUID.toString()` is lowercase. **We force `.uppercase()` in `CryptoService.prepare`.** |
| HKDF info | `UTF-8("us.chat.v1")` | exact literal, lowercase, no trailing dot |
| HKDF output length | 32 bytes | |
| AES mode | AES-GCM | |
| Key size | 256 bits | |
| Nonce size | 12 bytes | iOS `SealedBox.combined` puts nonce first |
| Tag size | 16 bytes (128 bits) | iOS appends tag after ciphertext |
| Wire layout | `nonce ‖ ciphertext ‖ tag` then base64 | `Base64.NO_WRAP` on Android, standard base64 on iOS |
| Plaintext encoding | UTF-8 JSON of `ChatPayload` | iso8601 dates, `explicitNulls = false` on Android matches Swift `.iso` encoder which omits nil |

A single bit wrong here surfaces as GCM tag mismatch → "open failed" →
placeholder. If you're stuck, log the first 8 bytes of `chatKey` on both
clients — they must match for a given couple_id + key pair.

### 5.4 Realtime parity

iOS subscribes to channel `messages-<uuid>` and filter
`couple_id=eq.<lowercase uuid>`. Android does the same with
`coupleId.toString().lowercase()`. If realtime doesn't fire on one side but
polling does, check the Supabase dashboard → Realtime → channels view — both
clients should appear in the same room.
