# Roadmap to v1.0

Six milestones organised tab-by-tab. Each one ships something usable; the gates between them are real (TestFlight cuts).

## v0.1 — "Hello, partner" (MVP)
Goal: paired users can send text messages with kaomoji and get push when offline.

- Sign in with Apple
- Pairing: generate code, redeem code, X25519 + HKDF key exchange
- Single chat view (matches `design-import/chat.jsx` ChatDetail)
- Text messages, end-to-end encrypted
- Realtime delivery (Supabase Realtime subscription)
- Push via Notification Service Extension (decrypts ciphertext on device)
- Kaomoji picker — 10 categories from `design-import/data.js` KAOMOJI
- Quick-react row (long-press a message → 5 quick kaomoji)
- Settings stub: display name, unpair
- Crash reporting (Sentry, no message content)

**Gate**: TestFlight with you + 1 partner for 1 week. Zero crashes, reliable push delivery.

## v0.2 — "Show me" (rich media + chat polish)
Goal: photos and voice work as well as text does. Chat reaches design parity.

- Photo messages: take from camera, pick from library, encrypted upload to Supabase Storage
- Voice messages: record, waveform, playback at 1x/1.5x/2x
- Camera screen (matches `design-import/chat.jsx` Camera)
- Photo viewer overlay (matches `extra.jsx` PhotoViewer) with pinch-zoom
- Reply-to-message threading
- Read receipts + typing indicators (opt-in toggles)
- Action sheet for `+` button (camera / 相簿 / 位置 / 加入時間表 / 存到記憶 / 抽卡)

**Gate**: 5 paired couples on TestFlight, 1 week, retention check.

## v0.3 — "Together" (時間 tab)
Goal: the unified time tab — calendar grid that IS the memory book.

- Month grid with photo-fill for past days, label-fill for upcoming
- Selected-day detail panel
- Add Entry sheet with title / time / location / tag / who / proposer / memorable toggle
- Entry detail screen (single screen, behaviour differs by upcoming vs past)
- 5 tag colours: rose (特別/食) / sage (出遊/散步) / amber (屋企)
- Anniversary ribbon on current month
- "一年前嘅今日" lookback under today's detail
- Auto-graduation: events past their `starts_at` flip to memory state
- Auto-bundling: photos/voice/messages from that day attach to the entry
- Local notifications + push for upcoming entry reminders
- Reflections (per author) — both partners can write after the event

**Gate**: Internal use 2 weeks, dogfood with v0.2 cohort.

## v0.4 — "我哋" tab + system integration
Goal: profile/anniversaries tab + the app lives outside its icon.

- 我哋 tab: couple identity card, anniversaries list, settings entry rows (matches `screens.jsx` Profile)
- Anniversaries detail screen with hero countdown (matches `extra.jsx` Anniversaries)
- Anniversary recurrence: yearly + monthly (e.g., 每月 22 號)
- Kaomoji preference setting (4 styles + smart-suggest toggle)
- Home screen widgets — small (countdown), medium (next entry + last message), large (memory feed)
- Lock screen widget: anniversary countdown
- Live Activity for upcoming entry day-of
- App Intents: "Send love to [partner]" via Siri
- Focus filter: hide notifications when in Work focus

**Gate**: Open beta on TestFlight, 50 couples target, 4 weeks.

## v0.5 — "玩樂" tab (activities)
Goal: re-engagement loop. All design assets already in `extra.jsx` — implementation, not design, is the work.

- 抽卡: 24-card date idea deck with flip animation (matches `extra.jsx` CardDeck)
- 21 條問題: turn-based quiz with "心有靈犀" match badge (matches `extra.jsx` Quiz)
- "加入時間表" hook from a card → creates an upcoming entry pre-filled
- 香港探險地圖 / 今晚煮乜 / 感激清單 — additional kinds defined in `data.js` activities
- Mood check-in (kaomoji-based daily prompt) — net new, not in design yet
- Streak tracking (gentle, no guilt-trip if missed)

**Gate**: A/B test which activities drive return visits; cull losers before launch.

## v1.0 — "Ready for the world" (App Store launch)
Goal: paid product on the App Store, single jbeam theme.

- Subscription via RevenueCat (free tier with limits, premium $X/month)
- Onboarding (matches `screens.jsx` Onboarding) — 3 steps: intro, pair code, theme picker (only jbeam available)
- App Store assets in zh-Hant + en + ja
- Privacy policy + terms (E2EE explained clearly, the `starts_at` plaintext caveat surfaced)
- Account deletion flow (App Store requirement)
- Multi-language: zh-Hant, zh-Hans, en, ja
- Customer support email + in-app feedback form

**Gate**: App Review approval. Soft launch in HK + TW first.

## Post-v1.0 (parking lot)
- **Multi-theme launch**: enable Notion 暖紙 + 深夜暖色 (designs already in `theme.js`)
- Theme syncing across the couple
- Android client (rebuild UI, reuse backend)
- Shared playlist integration (Spotify / Apple Music)
- Couple's gallery / shared album with smart categories
- Long-distance features: shared sunset photo, time zone widget, "thinking of you" tap
- Premium kaomoji packs (revenue + creative outlet)

## What we explicitly defer / never build
- Group chat — never. Couples app means two.
- AI relationship coach — privacy violates E2EE promise.
- Public profiles / discovery — not what this is.
- Stories / status — out of scope.
