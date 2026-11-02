# KK iOS backend contract

Live on us-app `stzfhdjuiupejonyckdu`. The client calls these RPCs with the signed-in session. It does not migrate data and does not touch `kaifan_*` or `carwash_*`.

Chat plaintext stays in the existing E2EE path. Memory Space, 想你知道, and AI text are server-readable.

## Mood whitelist

`kk_set_daily_mood(p_mood, p_hkt_date)` stores `users.mood`. `p_hkt_date` must be today's Hong Kong calendar date, and the server rejects calls before 06:00 HKT.

Labels, built in `DailyMoodLock`:

1. U+958B U+5FC3
2. U+5E73 U+975C
3. U+6709 U+5572 U+6530
4. U+4F4E U+843D
5. U+639B U+4F4F U+4F60
6. U+6709 U+5572 U+7169

The third mood is only `"\u{6709}\u{5572}" + String(UnicodeScalar(0x6530)!)`. UTF-8 of that third scalar is `e6 94 b0`. U+6536 and U+652F are rejected in the client before send. If the server rejects U+6530, the client shows the error and does not substitute another character.

## Wired

| Call | Client |
| --- | --- |
| `kk_set_daily_mood` | `DailyMoodStore.set` |
| `users.mood` read | `DailyMoodStore.refreshFromServer` |
| `kk_memory_create` / `kk_memory_update` / `kk_memory_delete` / `kk_memory_from_chat` | `MemorySpaceStore` |
| `memory_items` select | same, via RLS |
| `kk_want_create` / `kk_want_mark_read` / `kk_want_soft_delete` | `WantYouKnowStore` |
| `want_you_know` + `want_you_know_reads` select | same, via RLS |
| `kk_ai_usage_get` | `AIUsageStore.refreshFromServer` |
| `kk_ai_consume_and_run` | `AIUsageStore.consumeOnServer` — payload keys are only `user_text`, `memory_ids`, `memory_items` |
| `kk_kaomoji_prefs_get` / `kk_kaomoji_prefs_set` | `KaomojiPrefsStore` (recent list stays on device) |
| `kk_purge_expired_messages` | once per sign-in from `KKAppModel` |

## Still stubbed

- Gemini Edge is not deployed. A successful consume returns `result.status = stub` and the quota is still consumed. The sheet shows that note.
- 48h purge Edge/cron is not scheduled. The client call above is only opportunistic.
- 想你知道 09:00 HKT push is not wired. The `remind` flag is saved; no push is sent.
- `send-push` stays the existing device-token path. No new KK push job.
- Pairing RPCs are unchanged and still send `p_anniversary_iso`.
