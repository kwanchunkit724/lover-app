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
| `kk_ai_consume_and_run` | `AIUsageStore.consumeOnServer` — payload keys are only `user_text`, `memory_ids`, `memory_items`. Counted only when the response is a real plan (below). |
| `users.my_name` update | `AuthService.publishMyName` — `UPDATE` on the signed-in row only, after `kk_ensure_profile()`. Placeholders `我` / `對方` are not written. |
| `kk_kaomoji_prefs_get` / `kk_kaomoji_prefs_set` | `KaomojiPrefsStore` (recent list stays on device) |
| `kk_purge_expired_messages` | once per sign-in from `KKAppModel` |

## Names

`kk_ensure_profile()` inserts `my_name = 我` and `partner_name = 對方` when the row is missing, then returns the existing row without changing those columns. The iOS client therefore `UPDATE`s its own `users.my_name` when a real on-device or Apple given name exists, and again when the user saves 「我嘅名」 in Settings. It does not update the partner's row. The other phone reads that column as `pairing.partner.myName` on refresh.

Do not display or store `我` / `對方` once a real name exists. An empty couple-day is sent as JSON `null` for `anniversary_iso` (a `date`), never `""`.

## AI consume

Gemini Edge is not wired. The live `kk_ai_consume_and_run` returns `ok: false`, `result.status = unavailable`, and does **not** increment `ai_usage`. The iOS client still calls it, so a later Gemini response on this same RPC works without an app release.

The client treats a call as success only when `ok` is true and `result.plan` or `result.text` (or a non-developer `result.note`) is present. It then stores `used` and shows that plan. These are failures: the button stays 「展開（扣 1 次）」, the local used-count is left unchanged, and the sheet shows a short Cantonese sentence. Raw `note` text is never shown.

- `ok: false`
- `result.status` of `stub`, `unavailable`, `error`, `failed`, or `quota_consumed`
- a note/plan containing `quota_consumed`, `wire Gemini Edge for real plan output`, `kk_ai_consume_and_run`, or other snake_case RPC tokens

Success shape the client will count and display:

```json
{
  "ok": true,
  "period_ym": "2026-11",
  "used": 1,
  "remaining": 9,
  "result": { "status": "ok", "plan": "user-facing plan text" }
}
```

`used` must be the count **after** a real plan was produced. Do not increment `ai_usage` on `stub` / `unavailable`. If a deploy deducts before a plan exists, the next `kk_ai_usage_get` will surface that number; refund or move the increment to after the plan. The client will not present that response as 「已扣 1 次」.

`ai_quota_exhausted` locks the month. Every other thrown code is mapped to Cantonese. The raw string stays off the screen.

## Still stubbed

- 48h purge Edge/cron is not scheduled. The client call above is only opportunistic.
- 想你知道 09:00 HKT push is not wired. The `remind` flag is saved; no push is sent.
- `send-push` stays the existing device-token path. No new KK push job.
- Pairing RPCs are unchanged and still send `p_anniversary_iso`.
