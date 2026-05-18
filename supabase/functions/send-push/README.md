# send-push Edge Function

Fans out a push notification to the partner whenever a new message is
inserted into `public.messages`. Branches by platform:

- **iOS** — recipient row has `device_token` (APNs hex) → APNs HTTP/2 with a
  `.p8` ES256 JWT.
- **Android** — recipient row has `fcm_token` → FCM HTTPv1 with a Google
  service-account OAuth token.

Both can fire for the same message if the user signed in on both platforms.

## Trigger

Database webhook on `public.messages` INSERT. See
`supabase/migrations/0010_messages_push_trigger.sql` for the wiring.

## Secrets

Set these via the Supabase Dashboard → Edge Functions → Secrets, or with
`supabase secrets set …`.

| Secret | Source |
|---|---|
| `APNS_AUTH_KEY` | `.p8` file contents (full BEGIN/END block) from Apple Developer → Certs, Identifiers & Profiles → Keys |
| `APNS_KEY_ID` | 10-char Key ID printed next to the `.p8` |
| `APNS_TEAM_ID` | `C22JSRYW54` |
| `APNS_BUNDLE_ID` | `michel.kit.us` |
| `FCM_SERVICE_ACCOUNT_JSON` | Full JSON of a Firebase service account. Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the entire JSON file (private key included). |
| `FCM_PROJECT_ID` | Firebase project id (e.g. `lover-app-xxxxx`). Firebase Console → Project Settings → General → Project ID. Same as the `project_id` field of the service-account JSON. |

`SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## Payload contract

Both branches send a generic notification — the server never sees the
plaintext message (E2EE). Title = sender's `my_name`, body = generic
"sent you a message ♡" Cantonese string. The client decrypts on tap.

The FCM payload includes a `data.thread_id` field carrying the couple
UUID so the Android `LoverFcmService` can group notifications by
conversation. APNs uses `aps.thread-id` for the same purpose.

## Local notes

Chinese string literals are written as `\uXXXX` escapes in
`index.ts` because the Supabase Dashboard paste path mangles multi-byte
UTF-8 and produces "Unterminated string constant" deploy errors. Keep
that convention if editing literals in the Dashboard.
