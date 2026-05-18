# Play Data Safety Form — Field Mapping

The Data Safety form (App content → Data safety) is the user-facing privacy
card on the Play listing. Required for **every** app. Use the table below to
fill each section.

> Source of truth: `docs/PRIVACY_POLICY.md` + `docs/privacy.html`. If we
> ever change what we collect, update **both** the policy and this form.

## Section 1: Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all user data collected by your app encrypted in transit? | **Yes** (HTTPS to Supabase + Realtime over WSS) |
| Do you provide a way for users to request that their data be deleted? | **Yes** (in-app: Settings → Delete account, mirrors the iOS App Review 5.1.1(v) flow shipped in v1.4.5) |

## Section 2: Data types

For each row: **Collected? · Shared? · Optional/Required · Purpose · E2EE?**

### Personal info
| Type | Collected | Shared | Required | Purpose | Encrypted in transit | E2EE at rest |
|---|---|---|---|---|---|---|
| Email address | Yes | No | Required | Account management, app functionality | Yes | No (server-side, plaintext — needed for password reset / magic link) |
| Name | No | — | — | — | — | — |
| User IDs | Yes | No | Required | Account management | Yes | No (Supabase auth UID) |

### Messages
| Type | Collected | Shared | Required | Purpose | Encrypted in transit | E2EE at rest |
|---|---|---|---|---|---|---|
| Other in-app messages | Yes | No | Required | App functionality (chat with paired partner) | Yes | **Yes** — X25519 + AES-GCM-256, encrypted on device. Server stores ciphertext only. |

### Photos and videos
| Type | Collected | Shared | Required | Purpose | Encrypted in transit | E2EE at rest |
|---|---|---|---|---|---|---|
| Photos | Yes | No | Optional | App functionality (chat attachments, memory book) | Yes | **Yes** — same AES-GCM scheme, stored in Supabase Storage as ciphertext |
| Videos | No | — | — | — | — | — |

### Audio files
| Type | Collected | Shared | Required | Purpose | Encrypted in transit | E2EE at rest |
|---|---|---|---|---|---|---|
| Voice or sound recordings | Yes | No | Optional | App functionality (voice messages in chat) | Yes | **Yes** — AES-GCM stream |

### App activity
| Type | Collected | Shared | Required | Purpose |
|---|---|---|---|---|
| App interactions | No | — | — | — |
| In-app search history | No | — | — | — |
| Installed apps | No | — | — | — |
| Other user-generated content | Yes (anniversaries, memory book titles) | No | Optional | App functionality | Yes (in transit) | No at rest (titles are plaintext for indexing) |

### Device / other IDs
| Type | Collected | Shared | Required | Purpose |
|---|---|---|---|---|
| Device or other IDs | Yes | No | Required | App functionality (FCM device token for push) |

### Categories we explicitly DO NOT collect
- Location (precise or approximate)
- Personal contacts
- Calendar
- Financial info
- Health & fitness
- Web browsing history
- App diagnostics / crash logs (no Crashlytics / Sentry in v1.5.x)
- Advertising or third-party analytics

## Section 3: Security practices

Tick:
- ☑ Data is encrypted in transit
- ☑ You provide a way for users to request that their data be deleted
- ☑ Committed to follow the Play Families Policy (n/a, but harmless)
- ☐ Independent security review (not yet — Phase E candidate)

## Section 4: Data deletion

Provide URL: `https://kwanchunkit724.github.io/lover-app/support.html`
(documents the in-app Settings → Delete account flow).

Also enable **In-app deletion**: Yes (matches the iOS 5.1.1(v) ship).

## After submission

The Data Safety card appears on the listing within ~24h of approval. Any
schema change that adds a new data type requires re-submitting this form.
