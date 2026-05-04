# Tonight's test plan — v0.4.3 → v0.5.1

## What shipped

| Tag | What it does |
|---|---|
| **v0.4.3** | Photo display in chat bubbles (real download + decrypt + render with NSCache) |
| **v0.5.0** | Anniversaries E2EE — shared list, add/delete on either phone, realtime sync |
| **v0.5.1** | Timetable entries E2EE — shared calendar, AddEntryView actually saves, realtime sync |

Install **v0.5.1** (highest build number when it lands) — supersedes everything before it.

## Migrations applied to Supabase

- 0007 — `anniversaries` table + RLS + realtime publication
- 0008 — `entries` table + RLS + realtime publication

---

## Solo tests (no partner needed)

### A. v0.5.0 — Add an anniversary
1. Make sure paired (or pair if fresh install)
2. 我哋 → 紀念日 → expect kawaii empty state `(´｡• ω •｡`) 仲未有紀念日`
3. Tap **＋ 加新紀念日**
4. Title: `第一次見面`
5. Date wheel: pick a past date (e.g. 2024-11-08)
6. Recur: tap `每年` (default) — try `每月` to see toggle work
7. Emoji: tap `☕`
8. Tap **加入** — sheet closes, list shows the new anniversary
9. Hero card at top should show **下一個 · 倒數中** with "X 日後 ♡" + ☕ background watermark
10. Add 3 more (生日, 月誌 with 每月, 紀念日) — list sorts by countdown
11. Long-press a row → **刪除** — disappears immediately

### B. v0.5.1 — Add a timetable entry
1. 時間 tab → tap **＋** in top right (if exists) or open the AddEntryView some other way (currently only via "+" button)
2. Title: `行山：龍脊`
3. Date: pick a future date
4. Toggle **有時間** ON → time fields appear
5. Tag: `出遊`
6. 邊個: `我哋兩個`
7. 提議: `Kit` (or whoever)
8. 地點: `石澳`
9. Tap **加** — sheet closes
10. Calendar should now show a dot on that date
11. Tap the date in MonthGrid → entry appears in the day detail below

### C. v0.4.3 — Send + see your own photo
1. Go to chat (對話 tab)
2. Tap camera icon in composer
3. Pick a photo from library
4. Wait a moment — bubble should appear with **正在解密…** spinner briefly, then your photo
5. Scroll up + back down — image should be cached (no spinner second time)

### D. v0.5.0 — Profile shows real next anniversary
1. After step A, 我哋 tab
2. Identity card still shows real names + 已配對 ♡
3. **下一個** row should now show YOUR newly-added anniversary's title + days countdown (was MockData "我哋一齊嘅日子" before)

---

## Two-device tests (need partner)

### E. Anniversary realtime
1. Both phones paired, both on 我哋 → 紀念日
2. Phone A: add `搬入嚟一齊住` with 2025-09-14, 🏠
3. Phone B should see it appear within ~1 second (realtime, no refresh needed)
4. Phone B long-press it → 刪除 → Phone A sees it disappear

### F. Entry realtime
1. Both on 時間 tab
2. Phone A: add `今晚煮意粉` with tomorrow's date, tag 屋企, location `我哋屋企`
3. Phone B should see the dot appear on the calendar within ~1 second

### G. Photo round-trip
1. Phone A sends a photo
2. Phone B: bubble appears, 正在解密…, photo renders
3. Force-quit Phone B + reopen → photo renders again from cache

---

## Known limitations (deferred to Phase 6)

- **Voice messages** — VoiceRecorder UI exists but doesn't actually record yet (needs AVAudioRecorder plumbing)
- **Photo bubble caption** — captions get encoded but the UI doesn't expose a caption input yet
- **Push notifications** — iOS requests permission and uploads APNs token; server-side delivery (edge function) needs Apple Push Key in App Store Connect
- **Edit entries / anniversaries** — only add + delete supported; tap-to-edit comes later
- **AddEntryView nav from TimeView** — needs to verify the "+" trigger button is wired (was MockData before)
- **PartnerName in AddEntryView** — buttons still labeled "Kit"/"Michel" hardcoded; cosmetic, doesn't affect functionality

## Feedback I want

- Anniversary add flow — date wheel, recur chips, emoji grid feel right?
- Timetable add — date picker compact style OK or want a wheel?
- Photo loading state — `正在解密…` text + spinner enough, or want a skeleton?
- Hero anniversary card watermark emoji at 12% opacity — visible enough?

## Next stretch

- **v0.4.4** — voice messages (record + encrypt + upload + AVAudioPlayer playback)
- **v0.6.x** — real Claude Design icon, push delivery edge function, App Store screenshots, submission

Tell me which of A–G works, what feels off, and I'll iterate.
