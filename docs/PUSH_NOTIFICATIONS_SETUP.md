# Push Notifications Setup (v0.7.1)

iOS app already registers + uploads device tokens (Phase 4b). What's left is server-side delivery: Apple key + Supabase Edge Function + Database webhook.

## 1. Generate APNs Auth Key (Apple Developer)

1. Open https://developer.apple.com/account/resources/authkeys/list
2. Click **+** to register a new key
3. Name: `Us APNs Key`
4. Tick **Apple Push Notifications service (APNs)** → Continue → Register
5. **Download the .p8 file** (one-time download — save it)
6. Note the **Key ID** (10 chars, shown on the key detail page)

You should now have:
- File: `AuthKey_XXXXXXXXXX.p8`
- Key ID: 10-char string (e.g. `Q24GB7JXJ6`)
- Team ID: `C22JSRYW54` (already known)
- Bundle ID: `michel.kit.us`

## 2. Set Edge Function secrets

Open https://supabase.com/dashboard/project/stzfhdjuiupejonyckdu/settings/functions

Add these secrets (under "Edge Functions secrets"):

| Name | Value |
|---|---|
| `APNS_AUTH_KEY` | Paste the **entire** .p8 file contents including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `APNS_KEY_ID` | The 10-char Key ID |
| `APNS_TEAM_ID` | `C22JSRYW54` |
| `APNS_BUNDLE_ID` | `michel.kit.us` |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected — don't set them manually.

## 3. Deploy the Edge Function

Two options:

### Option A — Supabase Dashboard (no CLI)

1. Open https://supabase.com/dashboard/project/stzfhdjuiupejonyckdu/functions
2. Click **Create a new function**
3. Name: `send-push`
4. Paste the contents of `supabase/functions/send-push/index.ts` from the repo
5. Click **Deploy**

### Option B — Supabase CLI (if installed)

```sh
supabase login
supabase link --project-ref stzfhdjuiupejonyckdu
supabase functions deploy send-push
```

## 4. Create the Database Webhook

1. Open https://supabase.com/dashboard/project/stzfhdjuiupejonyckdu/database/hooks
2. Click **Create a new hook**
3. Settings:
   - Name: `messages-push`
   - Table: `messages`
   - Events: ✓ **Insert**
   - Type: **Supabase Edge Function**
   - Edge Function: `send-push` (the one from step 3)
   - HTTP Headers: leave defaults
4. **Create webhook**

## 5. Test

1. Pair two phones (Phone A + Phone B)
2. Lock Phone B (so chat isn't in the foreground)
3. Phone A sends a message
4. Phone B should get a notification banner: **`[Sender's name] · 傳咗訊息畀你 ♡`**

If nothing happens:
- Check function logs: https://supabase.com/dashboard/project/stzfhdjuiupejonyckdu/functions/send-push/logs
- Common issues:
  - `apns_status: 403` → bad key / key_id / team_id mismatch
  - `apns_status: 410` → device token is stale (user reinstalled — they need to open the app once to re-register)
  - `apns_status: 200` but no notification → topic mismatch (verify `apns-topic` matches bundle id `michel.kit.us`) OR the user has notifications disabled in iOS Settings → Us

## What this does NOT do

- **Doesn't decrypt the message body.** The server can't — it doesn't have the chat key. The notification body is generic ("傳咗訊息畀你 ♡") so messages stay E2EE.
- **Doesn't show message preview.** Phase 8 could decrypt client-side via a Notification Service Extension if you want previews — significant work, low priority.
- **Doesn't retry.** APNs failures are silent. Foreground chat still works via Realtime regardless.
- **Doesn't notify on anniversary / entry / play_history inserts.** Easy to add — just create more webhooks pointing at the same function (or duplicate the function and customize the alert text).

## What still needs to happen

- [ ] Generate APNs Auth Key (you, in Apple Developer)
- [ ] Add 4 secrets to Supabase
- [ ] Deploy the function
- [ ] Create the webhook
- [ ] Test on two paired phones
