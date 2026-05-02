# Lover App — Project Definition

## What this is
A private, Japanese-kawaii iOS app for couples. Two users pair their accounts and get a shared end-to-end encrypted space organised around 4 tabs: a single conversation, a unified time-tab that doubles as a memory book, lightweight activities, and a profile/settings tab.

## Audience
Public release for other couples. Not personal-use only. This shapes every architectural choice — we need centralised auth, billing, support tooling, the ability to migrate data with app updates, and content moderation hooks (even if minimal).

## Platform
- iOS-only at launch (iOS 17+)
- Android possibly later — backend choices kept portable (no CloudKit lock-in)

## Design source of truth
`design-import/` contains the canonical React prototype produced via Claude Design. SwiftUI implementation must achieve 1:1 visual fidelity. When a doc and the design disagree, **the design wins** — update the doc.

- `design-import/theme.js` → design tokens (jbeam is the launch theme)
- `design-import/data.js` → mock data shape; this is also the source for the Postgres schema
- `design-import/{chat,screens,extra}.jsx` → screen-by-screen layout reference

## Tabs (4, not 5)

### 1. 對話 (Chat) — ship first
- Single conversation only — opens directly into the partner thread, no chat list
- Text messages
- Photo: take with camera, pick from library
- Voice messages with waveform + variable playback speed (1x / 1.5x / 2x)
- **Kaomoji** picker instead of emoji — 10 categories, smart suggestions, 4 style modes
- Long-press to react with quick kaomoji
- Reply-to-message threading (single level)
- Push notifications
- Read receipts and typing indicators are **opt-in** per user

### 2. 時間 (Time) — ship second
A unified month-grid calendar that IS the memory book. One entry has two states:

- **Upcoming**: text label in the cell; reminder fires at user-set offset
- **Past**: photo fills the cell; auto-collected media/voice/messages from that day; reflections by either partner

Surfaces inside the time tab:
- Anniversary ribbon (next anniversary + days countdown) on current month
- Selected-day detail panel below the grid
- "一年前嘅今日" (one year ago today) panel under today's detail
- Add-entry sheet (`+` button on month switcher)

### 3. 玩樂 (Activities)
- 抽卡 (date idea card deck) — flippable cards with cost/mood/kaomoji
- 21 條問題 (couples quiz) — both answer, reveal side-by-side, "心有靈犀" badge on match
- Future: 香港探險地圖, 今晚煮乜, 感激清單

### 4. 我哋 (Us / Profile)
- Couple identity card: avatars + name + days together + next anniversary
- Anniversaries list (yearly + monthly recurrence, countdown)
- Settings: kaomoji preference, theme, reminder time, account
- Unpair, About

## Aesthetic
**日系奶油 (jbeam)** at launch — soft cream paper (`#FBF4EE`), warm rose accent (`#D88B82`), sage and amber for tag colours. Klee One serif for headings, Zen Maru Gothic for UI, DM Mono for timestamps and meta.

Two more themes designed and ready (`notion` 暖紙 / `cozy` 深夜暖色) — ship in a post-v1.0 update as a paid customisation lever.

## Names in design = placeholders
"Kit & Michel" and "2024-05-22" appear throughout `design-import/` as demo data. In production, names and start-date are collected during onboarding/pairing and stored encrypted.

## Non-goals
- Group chat (couples only — strictly two users per pair)
- Public social feed
- Story / status features
- AI-generated relationship advice (privacy violates E2EE promise)
- Cross-couple discovery / matchmaking

## MVP cut (v0.1)
Smallest shippable thing that proves the concept:
- Sign in with Apple
- Pair with partner via 6-digit code
- Send & receive text messages with kaomoji picker
- Push notifications via Notification Service Extension (decrypted on device)
- E2EE end-to-end (X25519 + ChaCha20-Poly1305)
- Settings: change display name, unpair

Everything else (photos, voice, time tab, activities, widgets) is post-MVP.

## Success criteria for v1.0 (App Store launch)
- Pair completion rate ≥ 60% (one of the two users finishes onboarding)
- D7 retention of paired couples ≥ 40%
- Crash-free sessions ≥ 99.5%
- Average chat-send-to-deliver latency < 2s p95
- 1:1 visual match with `design-import/` jbeam theme — no design drift
