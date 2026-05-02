# Pairing Flow & Key Exchange Protocol

Pairing is the single biggest churn point for any couples app. This doc spells out the full flow end-to-end so we can design and test against it.

## User-facing flow

### Path A: User A invites first
1. A signs in with Apple → user record created, no `couple_id` yet
2. App shows "Invite your partner" screen
3. A taps **Generate code** → backend creates a `couples` row with status `pending`, returns 6-digit `invite_code` (valid 10 minutes) and shareable URL
4. A picks share method:
   - **Share via iMessage** (recommended): `https://lover.app/pair/HJ48K2` — opens Messages with prefilled invite
   - **Show QR code**: encodes the same URL
   - **Copy code manually**: shows `HJ48K2` large + tap-to-copy
5. App enters "waiting for partner" state with cute illustration + live status

### Path B: User B receives invite
1. B taps the link → Universal Link opens app (or App Store if not installed)
2. App captures the code from the URL path
3. B signs in with Apple → user record created
4. App shows "You've been invited by Hana 💕 — accept?"
5. B taps Accept → key exchange runs (see protocol below)
6. Both users land on the empty chat screen with a "Say hi 👋" prompt

### Edge cases the UI must handle
- Code expired → A regenerates a new one
- Code already used → "This invite was already accepted"
- B tries to redeem with a wrong code → 3 attempts then 5-minute cooldown
- A regenerates while B is mid-flow → invalidate old code gracefully
- Either user already has a couple → show "Unpair from current partner first?" with hard confirmation

## Key exchange protocol

```
Time   User A (initiator)                          Backend                         User B (joiner)
────────────────────────────────────────────────────────────────────────────────────────────────────
t0     generate (a_priv, a_pub) X25519
       store a_priv in Keychain
       upload a_pub
                                          ──────────►  users.public_key = a_pub
       request invite                     ──────────►  couples.insert(invite_code, status='pending')
                                          ◄──────────  invite_code, expires_at

       [out-of-band: A shares link with B]

t1                                                                                  receives link, signs in
                                                                                    generate (b_priv, b_pub) X25519
                                                                                    store b_priv in Keychain
                                                                                    upload b_pub
                                                                                                                   users.public_key = b_pub
                                                                                    redeem(invite_code)  ─────────►
                                          ◄──────────  validate code, expiry
                                          ──────────►  couples.update(user_b=B, status='active', paired_at=now)
                                          ──────────►  link both users.couple_id

t2                                                                                  fetch a_pub from backend
                                                                                    shared_secret = X25519(b_priv, a_pub)
                                                                                    couple_key = HKDF-SHA256(shared_secret, salt=couple_id, info="lover-app/v1/couple-key", L=32)
                                                                                    store couple_key in Keychain
                                                                                                                   realtime: couples row updated
t3     receives realtime "paired"
       fetch b_pub from backend
       shared_secret = X25519(a_priv, b_pub)
       couple_key = HKDF-SHA256(shared_secret, salt=couple_id, info="lover-app/v1/couple-key", L=32)
       store couple_key in Keychain
       upload encrypted display_name
                                                                                    upload encrypted display_name

t4     both clients enter chat screen
```

### Why HKDF with `salt = couple_id`
The raw ECDH shared secret should never be used as a symmetric key directly (NIST SP 800-56C). HKDF stretches it, and binding the salt to the couple ID means we can't accidentally reuse the same key across couples even if somehow the same keypair were involved.

### Why `info = "lover-app/v1/couple-key"`
Domain separation. If we later derive sub-keys for different purposes (e.g. a separate key for media wrapping), we use the same shared secret with different `info` strings.

## Verification (manual safety number)

Optional but recommended for v1.x: each couple can view a 6-word safety phrase derived from `SHA-256(a_pub || b_pub)`. They can compare in person to confirm no MITM attack. This is the same pattern as Signal's "safety numbers" but couple-scoped.

If the public keys ever change (e.g. partner reinstalls the app), both clients display a "verify again" warning.

## Reinstall / new device flow

Hardest scenario. Three sub-cases:

### Case 1: Same device, app reinstalled
- Keychain `WhenUnlockedThisDeviceOnly` items are deleted with the app
- `couple_key` is gone → must re-derive
- But A's keypair is also gone → A's new public key won't match what B already has
- → Trigger "re-pair" flow: backend invalidates the old key linkage, both users must reconfirm

### Case 2: New device, iCloud Keychain backup ON
- Synced items restore automatically — `couple_key` available
- Encrypted history downloadable from backend, decryptable
- ✅ Seamless

### Case 3: New device, no backup
- All history lost (it's all encrypted with a key we don't have)
- Must re-pair with partner; old messages stay encrypted on backend forever (eventually purged by a TTL job)
- Onboarding must warn about this loudly

## Unpair flow

- Initiated unilaterally by either user
- Sets `couples.status = 'archived'`
- Both clients delete `couple_key` from Keychain
- Backend purges all `messages`, `events`, `memories`, `media` for that couple after a 7-day cooling-off window
- Users return to "find a partner" state

## Backend endpoints

| Endpoint | Method | Auth | Body |
|---|---|---|---|
| `/pair/invite` | POST | Required | `{}` → returns `{ invite_code, expires_at, share_url }` |
| `/pair/redeem` | POST | Required | `{ invite_code }` → returns `{ couple_id, partner_user_id, partner_public_key }` |
| `/pair/cancel` | POST | Required | `{}` → invalidates pending invite |
| `/couple/unpair` | POST | Required | `{ confirm: true }` |

Implement these as Supabase Edge Functions. Direct Postgres writes from clients are RLS-blocked for these mutations because we need atomic state transitions and rate limiting.
