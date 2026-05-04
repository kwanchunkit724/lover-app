# Tonight's test plan — v0.4.3 → v0.6.2

## What shipped

| Tag | What it does |
|---|---|
| **v0.4.3** | Photo display in chat bubbles (E2EE download + decrypt + render) |
| **v0.5.0** | Anniversaries E2EE — add/delete/realtime, hero countdown |
| **v0.5.1** | Timetable entries E2EE — AddEntryView wired to save, calendar sync |
| **v0.6.0** | Date-card history — record cards we've actually done |
| **v0.6.1** | Gratitude journal — 1 entry/day, both partners' timeline |
| **v0.6.2** | Async quiz — both answer privately, reveal when both done |

Install **v0.6.2** (highest build number when it lands) — supersedes everything before it.

## Migrations applied to Supabase

- 0007 — `anniversaries` table
- 0008 — `entries` table
- 0009 — `play_history` table (backs date-cards + journal + quiz)

---

## Solo tests (no partner needed)

### A. Date-card history
1. 玩樂 → 抽張卡 (or tap 盲盒約會 tile)
2. Tap 抽卡 → reveal a card (e.g. 夜遊維港)
3. Tap **我哋做過 ♡** → button flips sage with ✓ "已記錄 ♡"
4. Header shows **做過 1 種**
5. Tap 再抽 → next card → record it too → header shows 做過 2 種

### B. Gratitude journal
1. 玩樂 → tap 感激清單 tile
2. Should see kawaii empty state (`(´｡• ᵕ •｡`) 仲未有感激清單`)
3. Type "多謝你今朝沖嘅咖啡 (♡˙︶˙♡)" + 記低 (◕‿◕)
4. Composer collapses to sage **今日已記低 ♡** + "聽日再嚟"
5. Below the composer, your entry appears with your avatar tint (rose) and today's date header

### C. Async quiz (single-side test)
1. 玩樂 → tap 21 條問題 OR 情侶小測驗 tile
2. Question shows + 2 status rows ("你 答緊…" + "對方 答緊…")
3. Composer below — type "你笑嗰陣眼仔彎彎"
4. Tap 記低答案 → composer disappears, your status row flips to "你 已答 ✓"
5. Partner row still says "答緊…" → reveal won't fire until partner answers
6. Hit → to advance to next question

### D. Anniversaries (from v0.5.0)
- 我哋 → 紀念日 → ＋ → kawaii add flow

### E. Timetable (from v0.5.1)
- 時間 → ＋ → date picker, time toggle, 地點 field, 加

---

## Two-device tests (need partner)

### F. Date-card sync
1. Phone A records `夜遊維港` as done
2. Phone B's CardDeckView header should bump to **做過 1 種** within ~1s

### G. Journal timeline
1. Phone A writes today's entry "多謝你陪我食宵夜"
2. Phone B opens 感激清單 → sees Phone A's entry with sage avatar tint
3. Phone B writes their own entry → both appear under today's header

### H. Quiz reveal
1. Both phones on same question
2. Phone A submits "你笑嗰陣眼仔彎彎"
3. Phone B sees "對方已答 ✓" + their composer still active
4. Phone B submits same answer
5. **BOTH phones flip** to reveal both answers + 心有靈犀 ♡ badge if matched

### I. Photo round-trip (from v0.4.3)
- Send photo from A → see render on B with 正在解密… → photo

---

## Known limitations (Phase 7 polish)

- **Voice messages** — UI exists but recording isn't wired (AVAudioRecorder)
- **Edit anniversaries / entries** — only add + delete; tap-to-edit is later
- **Push delivery** — token uploaded to backend, but server-side edge function not yet deployed
- **App icon** — placeholder still in build. Claude Design auto-generated 4 concepts in the open Chrome tab — pick one and I'll wire it
- **香港探險地圖** — activity tile placeholder, no destination yet
- **MockData fallback** — when not paired or service is empty, MockData fills in for previews

## Feedback I want

- Date card "我哋做過" CTA placement — under the card OK or want it elsewhere?
- Journal "1/day" gate — feels right or too restrictive?
- Quiz async UX — wait time feels OK, or want a "ping partner" nudge?
- 心有靈犀 match — case-insensitive trim is the only normalization. Want fuzzier (e.g. ignore punctuation)?
- Icon — pick one from Claude Design tab, I'll integrate

## Next stretch

- **v0.6.3** — wire user-picked icon into Assets.xcassets
- **v0.7.x (Phase 7)** — voice via AVAudioRecorder, push edge function, App Store screenshots/description, submission

Tell me what works + breaks. Sleep tight 🩷
