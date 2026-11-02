# KK iOS backend contract

The iOS client in this branch does **not** call these RPCs and does **not** migrate or wipe data. Names here are the contract the backend branch should implement. Until then, screens persist on device and set a `pending*` flag.

Chat plaintext never goes to the server. Memory Space, 想你知道, and AI submissions are server-readable once the RPCs exist.

## Tables

- `moods_daily` — user + `hkt_date` unique. `mood` is one of the six labels below.
- `memory_items` — title, original_text, category (`日常` / `約會` / `計劃` / `其他`), note_summary, source_message_refs, photo_thumbs, attachment_markers, reminder_at. No status, owner, or proposer.
- `want_you_know` + `want_you_know_reads`. A row disappears only after both people delete it.
- `ai_usage` — couple + period, cap 10, atomic.
- `kaomoji_prefs` — `quick_react` length ≤ 6, style pack. Recent kaomoji stay on device.
- chat rows — `sent_at` / expiry, 48h purge. Memory source refs clear in the same job.
- `couples.anniversary_iso` — nullable. The live pair RPC still requires a date; stop requiring it when this column is nullable.

## Mood whitelist

Built in `DailyMoodLock` from scalars:

1. U+958B U+5FC3
2. U+5E73 U+975C
3. U+6709 U+5572 U+6530
4. U+4F4E U+843D
5. U+639B U+4F4F U+4F60
6. U+6709 U+5572 U+7169

U+6536 and U+652F are not valid. The mood day rolls at 06:00 `Asia/Hong_Kong`.

## RPCs

| Name | iOS status |
| --- | --- |
| `kk_set_daily_mood(mood, hkt_date)` | local write + `pendingRPC` |
| `kk_memory_*` / `kk_memory_from_chat` | local memory items + `pendingSync` |
| `kk_want_*` / mark read | local notes + `pendingSync` |
| `kk_ai_consume_and_run` | local counter only. Input is user text + memory payloads. No chat ciphertext parameter. |
| `kk_ai_usage_get` | not called |
| `kk_kaomoji_prefs_get` / `kk_kaomoji_prefs_set` | local quick list + `pendingCloudSync` |
| existing Apple + email OTP + pair | unchanged. Pair still sends `p_anniversary_iso`. |

## Jobs (server)

- 48h delete of chat and media, then clear memory source refs. Photo thumbs saved on a memory item are copies, not the chat blob.
- 想你知道: one push at 09:00 HKT on the due date.
- AI usage period resets on a locked timezone (client assumes HKT year-month).

## Kaomoji

Bundle `ios/LoverApp/Resources/Kaomoji.json`. Sleep category `label_zh` is U+7761. Search compares the kaomoji string only.
