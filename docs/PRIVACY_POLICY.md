# Privacy Policy — Us (我哋)

_Last updated: 2026-05-04_

## Plain-language summary

Us is a private, end-to-end encrypted app for two people. We are designed so the developer literally cannot read your messages, photos, voice notes, anniversaries, calendar entries, journal entries, or quiz answers. Everything sensitive is encrypted on your device with a key derived from your partner's public key, and the server only ever sees opaque ciphertext.

We do not sell your data. We do not share it with anyone. We do not run third-party ads or analytics SDKs. We do not track you across other apps or websites.

---

## What we collect and why

| Data | Source | Purpose | Stored where | Encrypted? |
|---|---|---|---|---|
| Apple ID (stable user identifier) | Sign in with Apple | Account identity | Supabase auth | At-rest |
| Email address | Sign in with Apple | Recovery / contact | Supabase auth | At-rest |
| Display name + partner's nickname | You enter during onboarding | Show in app | Supabase `users` table | At-rest |
| Anniversary date | You enter during onboarding + pairing | Couple verification + shared display | Supabase `users` + `anniversaries` (E2EE) | At-rest + E2EE |
| Theme preference | You pick during onboarding | Render the app | Supabase `users` | At-rest |
| Public key (X25519 curve, 32 bytes) | Generated on your device | Partner derives shared chat key | Supabase `users.public_key` | Public by design |
| **Chat messages** | You write | Send to partner | Supabase `messages.ciphertext_b64` | **End-to-end encrypted (AES-GCM)** |
| **Photos shared in chat** | You select | Share with partner | Supabase Storage `chat-media/` (encrypted blob) | **End-to-end encrypted (AES-GCM)** |
| **Voice messages** | You record | Send to partner | Supabase Storage `chat-media/` (encrypted blob) | **End-to-end encrypted (AES-GCM)** |
| **Shared calendar entries** | You add | Share with partner | Supabase `entries.ciphertext_b64` | **End-to-end encrypted (AES-GCM)** |
| **Date-card history, journal, quiz answers** | You record | Share with partner | Supabase `play_history.ciphertext_b64` | **End-to-end encrypted (AES-GCM)** |
| Apple Push Notification (APNs) device token | iOS provides after permission | Deliver lock-screen notifications | Supabase `users.device_token` | At-rest |

The private half of your encryption keypair lives only in your iPhone's Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, non-syncing). It never leaves your device. If you reinstall the app or sign in on a new device, you generate a fresh keypair and your previous chat history will display as "(無法解密)" — by design.

---

## What we do NOT collect

- We do not collect location.
- We do not collect contacts.
- We do not collect device identifiers for advertising.
- We do not run third-party analytics, attribution, or ad SDKs.
- We do not have access to your encryption keys.
- We do not back up your decrypted chat content anywhere.
- We do not read, train on, or transcribe your messages, photos, or voice notes.

---

## Push notifications

When your partner sends you something, our server-side function generates a generic notification (`[partner's name] · 傳咗訊息畀你 ♡`) and sends it to Apple's APNs service for delivery to your device. The notification body contains no chat content — the server cannot read it.

---

## Permissions we request and why

| Permission | Used for | When |
|---|---|---|
| Camera (`NSCameraUsageDescription`) | Take a photo to send | When you tap the camera icon in chat |
| Microphone (`NSMicrophoneUsageDescription`) | Record a voice message | When you tap the mic icon in chat |
| Photo library (`NSPhotoLibraryUsageDescription`) | Pick a photo from your library to send | When you tap the camera icon in chat |
| Notifications | Lock-screen alerts when partner sends something | After you sign in (you can decline) |

---

## Data deletion

You can:
- **Unpair** at any time (Profile → 解除配對) — deletes the couple row, both partners drop back to the pairing screen. Old encrypted messages remain on the server but neither side can decrypt them anymore.
- **Reset your local profile** (Profile → 重設個人資料) — clears all on-device state and signs you out.
- **Permanently delete your account + all data** — email us (see contact below) and we'll erase your auth row, your `users` row, and any couple/messages/entries/anniversaries/play_history rows you're a member of, within 30 days.

---

## Children

Us is not directed at children under 13. We do not knowingly collect data from anyone under 13. If you believe a child has provided data, please contact us so we can delete it.

---

## Where data is stored

Supabase project (Postgres + Storage) hosted on AWS in the **Asia-Pacific (Tokyo)** region (`ap-northeast-1`). Apple Push Notification service is provided by Apple Inc.

---

## Changes to this policy

We'll bump the "Last updated" date at the top and post the new version at the same URL. For material changes (e.g. new data categories), we'll show an in-app notice on next launch.

---

## Contact

For privacy questions or deletion requests:

- Email: kck980724@gmail.com
- Subject prefix: `[Us privacy]`

We aim to respond within 7 days.
