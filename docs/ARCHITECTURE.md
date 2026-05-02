# Lover App — Architecture

## TL;DR
- **Client**: SwiftUI + Swift Concurrency, iOS 17+, MVVM
- **Backend**: Supabase (Postgres + Realtime + Storage + Auth)
- **Auth**: Sign in with Apple, brokered through Supabase Auth
- **E2EE**: X25519 ECDH key exchange + ChaCha20-Poly1305 symmetric encryption
- **Push**: APNs via Supabase Edge Function, with Notification Service Extension for E2EE decryption on device
- **Subscription**: RevenueCat (handles StoreKit 2, ready for Android)
- **Crash & analytics**: Sentry + privacy-respecting events only (no message content)

## Why this stack

### Supabase over Firebase
| Concern | Supabase | Firebase |
|---|---|---|
| E2EE-friendly schema | Postgres — we control everything | Firestore — workable but messier |
| Cost predictability | Flat tiers | Per-read pricing scales unpredictably |
| Vendor lock-in | Lower (Postgres is portable) | High |
| Realtime | Postgres replication, simple | Firestore listeners, fine |
| Storage | S3-compatible | Cloud Storage, fine |

For a 2-user-per-couple app where most reads are realtime subscriptions on a tiny dataset, Supabase wins on cost predictability and on E2EE schema control.

### CloudKit ruled out
Originally a contender for personal use, but a public product needs centralised auth, support tooling, and the ability to push schema migrations. CloudKit Sharing's "no backend" advantage becomes a disadvantage when you need to operate the product.

### Why Sign in with Apple (not phone / email)
- Zero friction for iOS users
- App Store requires it if we offer any other social login (we don't, but future-proof)
- No password reset support burden
- Apple's relay email protects user privacy

## E2EE Design

### Threat model
- **Protected against**: Supabase the company, Supabase staff, network attackers, anyone who exfiltrates the backend database
- **NOT protected against**: a compromised user device, a malicious partner (the other person in the couple has the key by definition), Apple if iCloud Keychain backup is on
- **Out of scope**: forward secrecy, post-compromise security (couples share devices and screens — Signal-grade ratcheting is overkill and adds bug surface)

### Crypto primitives
- **Key exchange**: X25519 ECDH (CryptoKit `Curve25519.KeyAgreement`)
- **Symmetric encryption**: ChaCha20-Poly1305 (CryptoKit `ChaChaPoly`)
- **Key derivation**: HKDF-SHA256 from the ECDH shared secret
- **Random**: `SecRandomCopyBytes` for nonces

### Key lifecycle
1. On first launch, device generates an X25519 keypair. Private key stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + biometric gating. Public key uploaded to Supabase as part of user profile.
2. When pairing completes, both clients fetch each other's public key, perform ECDH, and derive a shared `couple_key` via HKDF.
3. The `couple_key` is cached in Keychain (same protection class). It's NEVER uploaded.
4. Every message ciphertext uses a fresh 12-byte random nonce.

### Key backup (the hard problem)
Default: **iCloud Keychain sync** with `kSecAttrSynchronizable = true` for the `couple_key`. Apple syncs it across the user's devices. Tradeoff: Apple technically holds the encrypted key, but it's behind iCloud Keychain's HSM-backed escrow.

Optional: user-set passphrase backup. The `couple_key` is encrypted with a key derived from the passphrase (Argon2id) and stored on backend. Recovery requires the passphrase.

If user has neither and loses their device, their message history is gone. We must communicate this clearly during onboarding.

### What's encrypted vs. plaintext on backend

| Field | State | Reason |
|---|---|---|
| Message text | Encrypted | Core privacy |
| Message media (photo, audio) | Encrypted blob in Storage | Core privacy |
| Reactions (`message_reactions.kao`) | Plaintext | Just a kaomoji string, low sensitivity, kept plaintext for fast aggregation |
| Display name | Encrypted | Personal |
| Avatar `initial` and `tint` | Plaintext | Single character, no real info leaked |
| Entry title, description, location, notes | Encrypted | Personal |
| Entry `starts_at`, `tag`, `who`, `is_special`, `memorable` | **Plaintext** | Backend needs them to schedule notifications, render calendar grid, and apply colour without decrypting |
| Anniversary `base_date`, `recur` | **Plaintext** | Backend needs them for countdown notifications |
| Reflection text | Encrypted | Personal |
| Couple-wide prefs (theme, together_since, reminder_default_minutes) | Plaintext | Synced settings, low sensitivity |
| User UX prefs (read receipts, kaomoji style) | Plaintext | Per-user, not personally identifying |
| Couple ID, user IDs, message IDs, timestamps | Plaintext | Required for routing and ordering |
| Public keys | Plaintext | By definition |

The plaintext-`starts_at` choice (and similarly `base_date`, `tag`) is a deliberate privacy tradeoff — we accept that the server knows *when* couples have plans and *what colour* the tag is, but not *what* they are doing. Document clearly in the privacy policy.

## Data model (Postgres)

Schema reflects the design in `design-import/data.js`. Each design concept maps to a table:

| Design concept | Postgres table |
|---|---|
| `D.entries` (entry with `status: 'upcoming' \| 'past'`) | `entries` (status is computed, not stored) |
| `D.entries[i].reflection` (per author, per entry) | `reflections` |
| `D.entries[i].cover`, `photos`, `voiceClips` | `media` |
| `D.anniversaries` | `anniversaries` |
| `D.messages` | `messages` |
| `D.ME`, `D.PARTNER` | `users` |
| Couple-wide settings (theme, day-counter base) | `couples` |

```sql
-- Couples are the primary tenant. One row per couple.
create table couples (
  id uuid primary key default gen_random_uuid(),
  invite_code text unique,         -- 6-digit code, nulled after pairing completes
  invite_expires_at timestamptz,
  created_at timestamptz default now(),
  paired_at timestamptz,
  status text check (status in ('pending', 'active', 'archived')),
  -- Couple-wide preferences (synced across both phones)
  theme_id text default 'jbeam',   -- 'jbeam' | 'notion' | 'cozy'
  together_since date,             -- the "一齊 N 日" base date, set during pairing
  reminder_default_minutes int default 60   -- default reminder offset for new entries
);

-- Users are bound to one couple (or zero, before pairing).
create table users (
  id uuid primary key,             -- mirrors auth.users.id
  couple_id uuid references couples(id),
  display_name_ciphertext bytea,   -- encrypted with couple_key
  display_name_nonce bytea,
  initial text,                    -- single-char avatar initial, plaintext (low sensitivity)
  tint text check (tint in ('rose', 'sage', 'amber')),  -- avatar colour
  public_key bytea not null,       -- X25519 public key, raw bytes
  apns_device_token text,
  -- Per-user UX prefs (do not sync to partner)
  read_receipts_enabled boolean default false,
  typing_indicator_enabled boolean default false,
  kaomoji_style text default 'jp', -- 'jp' | 'classic' | 'expressive' | 'mixed'
  kaomoji_smart_suggest boolean default true,
  notification_settings jsonb default '{}',
  created_at timestamptz default now()
);

-- Messages.
create table messages (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references couples(id),
  sender_id uuid not null references users(id),
  kind text check (kind in ('text', 'kaomoji', 'image', 'audio')),
  ciphertext bytea not null,       -- encrypted payload (text, or media metadata + URL)
  nonce bytea not null,
  reply_to_id uuid references messages(id),
  created_at timestamptz default now(),
  delivered_at timestamptz,
  read_at timestamptz              -- only set if both users have read receipts on
);

create index on messages (couple_id, created_at desc);

-- Reactions on messages — quick kaomoji reacts (not full reply).
create table message_reactions (
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references users(id),
  kao text not null,               -- the kaomoji string itself, plaintext (low sensitivity)
  created_at timestamptz default now(),
  primary key (message_id, user_id, kao)
);

-- Entries — the unified time/memory model. One row covers both states.
-- Status is computed: starts_at < now() => 'past', else 'upcoming'
create table entries (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references couples(id),
  proposed_by uuid references users(id),     -- 'kit'/'michel' in design → user_id here
  who text check (who in ('both', 'mine', 'theirs')),  -- viewed from proposer's perspective
  starts_at timestamptz not null,            -- PLAINTEXT for scheduling notifications
  ends_at timestamptz,
  tag text,                                  -- '特別日子' | '出遊' | '食' | '屋企' | '散步' | 'solo'
  is_special boolean default false,          -- shows ♡ marker
  memorable boolean default true,            -- if false, won't auto-graduate to memory
  ciphertext bytea not null,                 -- encrypted: title, description, location, notes
  nonce bytea not null,
  cover_media_id uuid references media(id),  -- the photo that fills the calendar cell
  reminder_offsets int[] default '{60}',     -- minutes before starts_at
  recurrence_rule text,                      -- iCal RRULE if recurring
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index on entries (couple_id, starts_at);

-- Reflections — post-event journal entries attached to an entry, per author.
-- Each user can write their own reflection. Design supports prompting
-- the partner who hasn't written yet.
create table reflections (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references entries(id) on delete cascade,
  author_id uuid not null references users(id),
  ciphertext bytea not null,                 -- encrypted: reflection text + optional kao
  nonce bytea not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (entry_id, author_id)               -- one reflection per author per entry
);

-- Anniversaries — recurring countdowns surfaced in the time + 我哋 tabs.
create table anniversaries (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references couples(id),
  base_date date not null,                   -- PLAINTEXT (similar tradeoff to entries.starts_at)
  recur text check (recur in ('yearly', 'monthly')) not null,
  ciphertext bytea not null,                 -- encrypted: title, subtitle, kao, emoji
  nonce bytea not null,
  created_at timestamptz default now()
);

-- Media blobs reference Supabase Storage objects. The bytes in Storage are ciphertext.
create table media (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references couples(id),
  uploader_id uuid not null references users(id),
  entry_id uuid references entries(id),      -- if attached to an entry; null = chat media
  storage_path text not null,                -- path in Storage bucket
  kind text check (kind in ('image', 'audio')),
  duration_sec int,                          -- for audio
  size_bytes int,
  encrypted_key bytea,                       -- per-media key, wrapped with couple_key
  nonce bytea,
  created_at timestamptz default now()
);

create index on media (couple_id, created_at desc);
create index on media (entry_id) where entry_id is not null;
```

### Row-Level Security
Every table has RLS policies that reject any read/write where `couple_id` does not match the calling user's couple. We rely on Supabase Auth's `auth.uid()` to scope the user.

```sql
alter table messages enable row level security;

create policy "couple members read messages"
  on messages for select
  using (couple_id = (select couple_id from users where id = auth.uid()));

create policy "couple members insert messages"
  on messages for insert
  with check (
    couple_id = (select couple_id from users where id = auth.uid())
    and sender_id = auth.uid()
  );
```

(Same shape for `events`, `media`, `memories`.)

## Push notifications with E2EE

Standard push delivery sees the message body in plaintext (because APNs delivers the JSON payload). That defeats E2EE. The fix:

1. Backend sends a **silent push** (`content-available: 1`) containing only the message ID and a generic title.
2. iOS wakes the app's **Notification Service Extension**.
3. Extension fetches the ciphertext from Supabase using the message ID.
4. Extension decrypts using the `couple_key` from the shared App Group Keychain.
5. Extension mutates the notification with the decrypted preview ("💬 Hana sent you a message: あいしてる").

Fallback if decryption fails: show "New message from your partner" — never crash the extension.

Notification Service Extensions have a 30 second budget and a tight memory limit; keep the decryption path lean.

## Realtime delivery
- Use Supabase Realtime (Postgres logical replication) to subscribe to `messages` filtered by `couple_id`.
- On insert, client receives the row, decrypts, and renders.
- Push notification is the fallback when the app is backgrounded — both paths fire; client deduplicates by message ID.

## Media upload flow
1. Client encrypts the media bytes with a per-media random key + nonce.
2. Per-media key is wrapped (encrypted) with the `couple_key`.
3. Ciphertext bytes uploaded to Supabase Storage.
4. `media` row inserted with `storage_path`, wrapped key, nonce.
5. Recipient downloads ciphertext, unwraps the per-media key with `couple_key`, decrypts.

Per-media key (instead of using `couple_key` directly for media) means we can later support sharing a single media item with a third party (e.g. export) without leaking the `couple_key`.

## Folder structure (iOS)

```
ios/LoverApp/
├── App/                     # @main, RootView, SessionStore (state machine)
├── Core/
│   ├── Crypto/              # KeyManager, MessageCipher, MediaCipher
│   ├── Networking/          # Supabase client wrapper, request/response types
│   ├── Storage/             # SwiftData models (local cache), Keychain helpers
│   ├── PushNotifications/   # APNs registration, NSE entry point
│   └── Realtime/            # Subscription manager
├── DesignSystem/            # Theme.swift, Color+Hex, Fonts, Icons, shared primitives
│                            #   — translates design-import/theme.js + ui.jsx into SwiftUI
├── Features/
│   ├── Onboarding/          # Sign in with Apple, intro slides
│   ├── Pairing/             # Invite code generation + entry, key exchange
│   ├── Chat/                # ChatView, MessageBubble, Composer, KaomojiPicker, VoiceRecorder, Camera
│   ├── Time/                # MonthGrid, EntryDetail, AddEntry, lookback section
│   ├── Activities/          # CardDeck, Quiz
│   ├── Profile/             # Couple card, Anniversaries, settings rows
│   └── Settings/            # KaoSettings, ThemeSettings
├── Services/                # NotificationService, AnalyticsService
├── Models/                  # Plain data: Person, Message, Entry, Anniversary, Theme
├── Mock/                    # Mock data matching design-import/data.js for previews + dev
└── Resources/
    ├── Kaomoji.json         # Curated kaomoji catalogue with categories
    └── Localizable.xcstrings
```

The folder layout deliberately mirrors `design-import/` so a new contributor can read a `.jsx` file and find its SwiftUI counterpart by name.

## Open questions
- Voice message format: M4A/AAC for compactness, but iOS native is best — confirm bitrate target (32 kbps mono is plenty for voice)
- Photo compression: HEIC vs JPEG, target longest edge 2048px before encryption
- Whether to support GIF in chat (kaomoji-first product — maybe not initially)
- Moderation: how to handle abuse reports when we can't read messages? Likely "report partner → unpair + block" with no content review
- Subscription model: free with limits (e.g., 100 photos/month) vs. one-time purchase vs. paid up front
