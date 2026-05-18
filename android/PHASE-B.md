# Phase B Round 2 — Android infra parity (FCM + Google Sign-In + fonts + theme)

This round wires the platform-specific bits that the iOS app already has:
push notifications, third-party auth, custom typography, and the
per-couple theme. Code is in place; three real credentials are still
needed from the user before runtime works end-to-end.

## What's in the repo

| Area | Files |
|---|---|
| FCM push | `data/PushRepository.kt`, `service/LoverFcmService.kt`, manifest entries, FCM dep in `app/build.gradle.kts`, gms plugin classpath in root `build.gradle.kts`, placeholder `app/google-services.json` |
| Google Sign-In | `data/AuthRepository.kt::signInWithGoogle`, `features/auth/AuthScreen.kt` button, `data/SupabaseConfig.kt::GOOGLE_WEB_CLIENT_ID` constant (TODO), CredentialManager + googleid deps |
| Fonts | `res/font/{kleeone,zenmarugothic,dmmono}_{regular,semibold,medium}.ttf` (Klee One / Zen Maru Gothic / DM Mono), `res/font/OFL.txt`, `ui/theme/Typography.kt` rewritten to load them |
| Per-couple theme | `ui/theme/Color.kt::LoverPalette.{Notion,Cozy}` added, `LoverPalette.forId(themeId)`, `LoverApp.kt::RootRouter` re-wraps `LoverAppTheme` with palette derived from `users.theme_id` |
| Edge function | `supabase/functions/send-push/index.ts` branches on `device_token` / `fcm_token`, `supabase/functions/send-push/README.md` |
| Migration | `supabase/migrations/0015_fcm_token.sql` adds `fcm_token` column + `set_fcm_token` RPC |

## What the user must supply

### 1. Real `google-services.json`

The committed file at `android/app/google-services.json` is a syntactically
valid placeholder. The build succeeds with it; runtime Firebase calls
(FCM token fetch, Google Sign-In) will fail until replaced.

Steps:
1. Firebase Console → Add project → name it `lover-app` (or any).
2. Add Android app → package name `michel.kit.us`, app nickname `Us 我哋`.
3. Download `google-services.json` → drop it at `android/app/google-services.json`.
4. Add SHA-1 of the debug keystore (Firebase Console → Project Settings →
   Your Android app → Add fingerprint). On Codemagic-style CI the debug
   keystore is generated fresh per build, so for testing use a local
   `~/.android/debug.keystore` SHA-1, or commit one debug keystore.

### 2. FCM service account JSON + project id (Edge Function secrets)

The send-push Edge Function needs these env vars set in the Supabase
Dashboard → Edge Functions → Secrets (or `supabase secrets set …`):

| Secret | How to get it |
|---|---|
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the entire downloaded JSON (private key included). |
| `FCM_PROJECT_ID` | Firebase Console → Project Settings → General → Project ID. Same as `project_id` field of the JSON above. |

### 3. Google Web Client ID (for Google Sign-In)

After enabling Google as a sign-in method in Firebase Console
(Authentication → Sign-in method → Google), Google auto-creates a Web
OAuth client. Find it in Google Cloud Console → APIs & Services →
Credentials → OAuth 2.0 Client IDs → "Web client (auto created by
Google Service)". Copy the Client ID.

1. Paste into `android/app/src/main/kotlin/michel/kit/us/data/SupabaseConfig.kt`
   replacing the `TODO_FILL_IN_FROM_FIREBASE_CONSOLE` constant.
2. Supabase Dashboard → Authentication → Providers → Google → enable +
   paste the same Client ID in "Client ID (for OAuth)". Client Secret
   field is required by Supabase but unused for ID-token flow; paste
   the web client's secret from the same Cloud Console page or any
   non-empty string.

### 4. Migration apply

Run `supabase/migrations/0015_fcm_token.sql` in the Supabase SQL editor
(Dashboard SPA → SQL Editor → New query → paste → run). Adds the
`fcm_token` column + `set_fcm_token` RPC. Idempotent.

## CI expectations

The GHA Android workflow (`.github/workflows/android-build.yml`) should
succeed with the placeholder `google-services.json` — the google-services
Gradle plugin only validates JSON shape + package name match. Runtime
push + Google Sign-In are no-ops until the real file lands.
