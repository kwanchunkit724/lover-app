# Lover-app Project Plan

> Living roadmap. Updated each working session. Daily 6 am cron reads this
> file + recent git log + recent GHA runs to produce a status report.

## North-star goal

Ship **"Us 我哋"** — bilingual (zh-Hant default, en/ja) couples app — on both
iOS App Store and Google Play Store, feature-parity, with Instagram-style
chat (reply / reactions / edit / unsend / vanish / read receipts).

## Architecture

| Layer | iOS | Android |
|---|---|---|
| UI | SwiftUI (Xcode 26 / iOS 26 SDK) | Jetpack Compose (Kotlin 2.0, Material3, AGP 8.7) |
| State | `@Observable` Stores | `ViewModel` + `StateFlow` |
| Backend | Supabase Postgres (ap-northeast-1) — schema in `supabase/migrations/` | same |
| Realtime | Supabase Realtime channels per couple | same channel naming + filter |
| Crypto | CryptoKit X25519 + HKDF-SHA256 + AES-GCM-256 | BouncyCastle X25519 + javax.crypto AES-GCM — byte-compatible with iOS |
| Push | APNs via Edge Function + pg_net trigger | FCM (Phase B) |
| CI | GitHub Actions macos-15 → TestFlight via codemagic-cli-tools | GitHub Actions ubuntu-latest → GH Release APK (Play AAB in Phase B) |

## Milestones

### M0 — Foundation (DONE)
- [x] Supabase schema + RLS + storage buckets
- [x] X25519 + HKDF + AES-GCM crypto pipeline
- [x] iOS SwiftUI shell + auth + pairing + chat
- [x] APNs push via Edge Function
- [x] Codemagic CI (later replaced — Phase A.5)

### M1 — Catalog features (DONE on iOS, pending Android Phase B)
- [x] Activities catalog + saved
- [x] Memory book entries
- [x] Time / calendar / anniversaries
- [x] Profile + theme picker
- [x] Settings + account deletion (Apple App Review 5.1.1(v))

### Phase A.5 — Migration off Codemagic (DONE, this session)
- [x] Diagnosed Codemagic build-minutes exhaustion
- [x] Built GHA `ios-testflight.yml` (macos-15 + codemagic-cli-tools via pipx)
- [x] Resolved 4-step credential mismatch (issuer / key-id / .p8 / 2FA)
- [x] Shipped iOS v1.5.0 via GHA (build 1778973217)

### v1.5.0 — IG-style chat upgrade (DONE on iOS, parity on Android)
- [x] supabase/migrations/0013_chat_ig_features.sql (reply / edit / unsend / vanish / reactions / read)
- [x] iOS ChatService rewrite + UI (MessageBubble, ReactionPickerSheet, vanish banner)
- [x] iOS TestFlight live
- [x] iOS v1.5.1 patch shipped (mock-data leaks)
- [x] Android Phase A scaffold (52 files) — auth + pairing + chat
- [x] APK built via GHA, sideloaded onto BlueStacks, UI + signup roundtrip validated
- [ ] iOS↔Android cross-platform chat E2E test (needs paired accounts)

### v1.5.1 — Bug patch (SHIPPED)
Source: `BUG-AUDIT-v1.5.1.md` (audit complete). View-layer fixes only, no schema.
- [x] Remove `● 在線` hardcoded indicator in `ChatView.swift:303,306`
- [x] Strip `MockData.entries` fallback in `TimeView.swift:28-31`
- [x] Strip `MockData.anniversaries` fallback in `TimeView.swift:45` + `ProfileView.swift:42`
- [x] Strip `MockData.me/partner/togetherSinceISO` in `ProfileView.swift:49,57,72` + `ChatView.swift:36,39,45,46`
- [x] Rename legit catalogs out of `MockData` (`MockData.activities` → `ActivityCatalog`, etc.)
- [x] Bump `MARKETING_VERSION` 1.5.0 → 1.5.1 in `project.yml`
- [x] Tag `v1.5.1` → GHA → TestFlight

### Phase B — Android feature parity (SHIPPED in android-v1.5.1 GH Release APK)
- [x] Activities tab (catalog + saved)
- [x] Memory Book tab
- [x] Time tab (calendar + anniversaries + entries)
- [x] Settings tab + account deletion
- [x] Profile tab (theme picker, partner profile, sign-out)
- [x] Photo + camera + voice composer in chat (`ActivityResultContracts` + `MediaRecorder`)
- [x] Encrypted photo display (Coil custom `Fetcher` + decrypt-in-memory)
- [x] Encrypted audio playback (ExoPlayer + decrypt-stream)
- [x] FCM push (mirror APNs Edge Function with `fcm_token` discriminator column) — needs real `google-services.json` + FCM service-account JSON to function at runtime
- [x] Google Sign-In via Credential Manager (Apple Sign In parity) — needs Web Client ID filled in `SupabaseConfig.kt`
- [x] Custom Japanese fonts (Klee One / Zen Maru Gothic / DM Mono) — bundled under `res/font/`
- [x] Per-couple theme variant from `users.theme_id` — cream/jbeam/notion/cozy all wired
- [x] Auth screen header label flips 登入↔註冊 (BlueStacks verified)
- [x] Migration 0015_fcm_token.sql written — needs user to deploy via Supabase dashboard

### Phase C — Real presence (DONE)
- [x] Supabase Realtime presence channel (`presence:<lowercase couple uuid>`)
- [x] `last_seen_at` column + `update_last_seen()` RPC (0014_presence.sql) — heartbeat every 30s, paused while backgrounded
- [x] iOS `PresenceService` + green dot wiring (ChatView header — 在線 / 上次在線 X 分鐘前 / 一齊 N 日 fallback)
- [x] Android `PresenceRepository` + ChatScreen header parity

### Phase D — Play Store release (PARTIAL)
- [x] Generate upload keystore (RSA 2048, 10000-day validity, in `android-keystore/`, gitignored)
- [x] Switch GHA Android workflow to build signed AAB (`.github/workflows/android-release.yml`, additive — debug workflow unchanged)
- [x] Listing template + submission guide (`play-store/listing/` + `play-store/SUBMISSION.md`)
- [ ] Play Console developer account ($25 one-time) — user-dependent (needs ID + payment card)
- [ ] Add 3 GitHub Actions secrets (keystore b64 + 2 passwords) — user-dependent
- [ ] App listing copy + screenshots + feature graphic upload — user-dependent
- [ ] First internal-testing track upload
- [ ] Closed-testing → open-testing → production progression

### Phase E — Polish (BACKLOG)
- [ ] Crash reporting (Crashlytics? Sentry?)
- [ ] Analytics (PostHog? skip on privacy grounds?)
- [ ] Onboarding tutorial overlays
- [ ] Widget extensions (iOS WidgetKit + Android Glance)
- [ ] Apple Watch / Wear OS companion (long-term)

## Daily ritual

The 6 am cron job (`daily-status`) summarizes this file plus recent git log,
GHA run outcomes, and any open work items in the active session's todo list.
