# BUG-AUDIT-v1.5.1 — Mock data leaking into production screens

Audit of v1.5.0 (TestFlight). Source root: `C:\Users\user\lover-app\ios\LoverApp\`.

All four reported bugs reproduce. Three share the same root pattern: view-layer `real.isEmpty ? MockData.* : real` fallback that fires for paired-but-empty couples on production. The fourth (online indicator) is a fully hardcoded string with no presence backing at all.

---

## Bug #1 — "● 在線" indicator is hardcoded

**Where:** `ios/LoverApp/Features/Chat/ChatView.swift` lines **294–307** (`headerStatus`).

**Root cause:** `headerStatus` always returns a string that begins with `"● 在線"`. There is no presence check, no `PresenceService`, no Supabase Realtime presence channel, and no `last_seen` column anywhere in the codebase (grep across `ios/` and repo root for `PresenceService`, `presence`, `last_seen`, `lastSeen` returned no matches). The green dot + 在線 text is purely decoration that pretends to be a status.

```swift
guard let iso else { return "● 在線" }
let days = TimeFormatting.daysBetween(iso, today)
return "● 在線 · 一齊 \(days) 日"
```

The function's actual job is computing `一齊 N 日` from the earlier of the two anniversary ISOs — the 在線 prefix was stapled on with no infrastructure behind it.

**Proposed fix:** Two paths, pick one:

- **Quick (ships v1.5.1, no schema):** Remove the `● 在線` prefix entirely. Just show `一齊 N 日` (or the avatar/name with no sub-line if anniversary unset). Files: `Features/Chat/ChatView.swift` only. Zero risk.
- **Real (needs a follow-up phase, not v1.5.1):** Add a `PresenceService` that uses Supabase Realtime's built-in presence channel (`couple-{id}` channel, `track()` on app foreground, `untrack()` on background). No schema change required — Realtime presence is in-memory only. Subscribe in `ChatView` and `ProfileView`; derive `partner.isOnline` from the channel's presence state. Files: new `Services/PresenceService.swift`, wire into `App/LoverAppApp.swift`, consume in `Features/Chat/ChatView.swift` and optionally `Features/Profile/ProfileView.swift`.

**Severity:** Confusing — users believe partner is always online; will erode trust in every other status the app shows.

**Patchable as v1.5.1?** Yes for the quick fix (just delete the prefix). The real presence wiring should be its own phase.

---

## Bug #2 — Time tab shows mock entries after pairing

**Where:** `ios/LoverApp/Features/Time/TimeView.swift` lines **28–31**.

```swift
private var entries: [Entry] {
    let real = entryService.asEntries
    return real.isEmpty ? MockData.entries : real
}
```

**Root cause:** The "fall back to MockData when service is empty so previews still render" pattern fires for production users too. `EntryService.asEntries` is empty for any couple that hasn't created an entry yet (which is *every* freshly-paired couple). The fallback then renders the entire `MockData.entries` array (19 entries: `e_today1`, `e_today2`, `e_w1`…`m11`, `mly`) into:

- `MonthGrid` (dots and photo cells on every grid day matching mock dates 2026-04-xx / 2026-05-xx)
- `selectedDaySection` (the "今日 / 將至 / 回望" list — `entries.filter { $0.date == selectedISO }`)
- `lookbackSection` (一年前嘅今日 — surfaces `mly` entry)
- The anniversary ribbon's `dayEntries` count

Worse: tapping a mock entry actually opens a fully populated `EntryDetailView` (entries flow through a `.sheet(item:)` by value, line 94–101) — so users get a working detail screen for an event that doesn't exist in their couple's data.

**Proposed fix:** Drop the fallback in production paths. Change `entries` to just `entryService.asEntries`. The right place for empty state is a small "尚未有紀錄 · 撳 + 加你哋第一件事" cell in `selectedDaySection` when `dayEntries.isEmpty`. Keep `MockData` references inside `#if DEBUG` preview blocks only (`EntryDetailView` line 380/385 previews and `MonthGrid` line 296–298 preview are fine — they're `#Preview` macros). Files: `Features/Time/TimeView.swift` (lines 28–31, plus an empty-state cell in `selectedDaySection`).

**Severity:** Data-loss risk adjacent — a user could think a mock event is real, plan around it, miss a date. Also breaks the "回望" panel by surfacing a year-ago memory that never happened.

**Patchable as v1.5.1?** Yes. View-layer only, no schema change.

---

## Bug #3 — 紀念日 hero/list shows fake entries that lead to an empty detail screen

**Where:**
- Source of fake list: `ios/LoverApp/Features/Profile/ProfileView.swift` lines **30–43** (`anniversaries` computed property), consumed at lines **264–281** (`anniversariesSection`) and `nextAnniv` at lines 80–88.
- Source of fake ribbon on Time tab: `ios/LoverApp/Features/Time/TimeView.swift` lines **33–46** (same pattern), consumed at lines 51–56 (`anniversaryRibbon`) and `nextAnniversary` at line 276.
- Detail screen that correctly shows empty: `ios/LoverApp/Features/Profile/AnniversariesView.swift` lines 25–44 — reads ONLY from `anniversaryService.items`, no fallback.

**Root cause:** Same `real.isEmpty ? MockData.anniversaries : real` pattern as #2, but with an asymmetry that produces the "ghost rows" effect. `ProfileView.anniversariesSection` and `TimeView.anniversaryRibbon` both render mock items (`an1` 我哋一齊嘅日子, `an2` 第一次見面, …, `an6` Kit 生日) when the couple has none. Tapping "所有紀念日 (6) →" or the ribbon presents `AnniversariesView`, which has *no* mock fallback — it shows the empty state. From the user's view: "I see 6 anniversaries on the previous screen, but the detail page says I have none."

The `id` mismatch the bug report hypothesised isn't the mechanism — `AnniversariesView` doesn't look up by id at all, it just iterates `anniversaryService.items`. The asymmetry between the two views is what makes the bug visible.

**Proposed fix:** Remove the MockData fallback in both `ProfileView.anniversaries` (line 42) and `TimeView.anniversaries` (line 45). When `anniversaryService.items` is empty:

- `ProfileView.anniversariesSection`: render a single tappable cell "未有紀念日 · 撳一下加 →" that opens `AnniversariesView` in add mode (or just opens it — the existing empty state in `AnniversariesView` already prompts to add).
- `TimeView.anniversaryRibbon`: don't render the ribbon at all when `nextAnniversary == nil`.

Files: `Features/Profile/ProfileView.swift`, `Features/Time/TimeView.swift`. No service or schema changes — `AnniversaryService` already correctly returns `items: []` for paired couples with nothing added (Realtime + initial fetch, see `Services/AnniversaryService.swift` lines 26–60).

**Severity:** Confusing → data-loss risk. Users may believe the app auto-populated their birthdays / anniversary and not bother adding them, then never get reminders for real dates.

**Patchable as v1.5.1?** Yes. View-layer only.

---

## Bug #4 — 我哋 (Us) tab shows dummy data

**Where:** `ios/LoverApp/Features/Profile/ProfileView.swift` — this is the same root cause as #3.

Concretely, the visible dummy data on the 我哋 tab when paired is:

- The `anniversariesSection` (mock anniversaries via line 42 fallback) — covered by #3.
- Lines 49, 57, 72: name and `togetherSinceISO` fallbacks to `MockData.me.name`, `MockData.partner.name`, `MockData.togetherSinceISO`. These only fire if the user's local `UserProfileStore.profile` and `pairing.partner` are both nil — won't normally trigger for a fully-onboarded paired user, but they're still wrong fallbacks (they'd render 米雪 / Kit names and 2024-05-22 anniversary on a broken-profile edge case). Worth tightening at the same time.

**Root cause:** Same `?? MockData.…` pattern as #3, applied to identity strings rather than collections.

**Proposed fix:** For the anniversaries section, see #3. For the identity fallbacks (lines 49, 57, 72):

- `me.name`: fall back to `""` (or `"你"`) — never `MockData.me.name`.
- `partner.name`: fall back to `""` (or `"伴侶"`) — never `MockData.partner.name`.
- `anniversaryISO`: return `nil` upstream and let `daysTogether` and `headerStatus` (Bug #1) handle the missing case gracefully — never `MockData.togetherSinceISO`.

Files: `Features/Profile/ProfileView.swift`, plus the parallel name fallbacks in `Features/Chat/ChatView.swift` lines **36, 39, 45, 46** which have the identical issue (`?? MockData.me.id`, `?? MockData.me.name`, `?? MockData.partner.name`, `?? MockData.partner.id`).

**Severity:** Confusing. Identity strings rarely surface for properly onboarded users but are a real footgun — if anything goes wrong with `pairing.partner` loading (race, offline launch, deleted partner), the user sees "米雪" / "Kit" instead of their actual partner's name.

**Patchable as v1.5.1?** Yes. View-layer only.

---

## Cross-cutting recommendation

There are 6 distinct `MockData.*` fallbacks reaching production rendering across 4 files (TimeView ×2, ProfileView ×4 — counting names/iso/anniversaries, ChatView ×4). Consider a one-line audit rule for v1.5.1: **`MockData` may only be referenced inside `#Preview { … }` macros**. A grep gate in CI (`Grep MockData. ios/LoverApp --glob '*.swift'` filtered to non-`#Preview` regions) would prevent regressions. The legitimate non-preview references that should remain after the fix are limited to truly-static catalog data (`MockData.activities`, `MockData.dateCards`, `MockData.quizQuestions` in `ActivitiesView`, `CardDeckView`, `QuizView`) — these aren't user data, they're feature definitions. Consider renaming those out of `MockData` (e.g., into `ActivityCatalog`, `DateCardCatalog`, `QuizCatalog`) so the rule "no MockData in production" is mechanical and clean.

---

## Summary table

| Bug | File:Line | Mock-fallback firing | Severity | v1.5.1 patchable? |
|---|---|---|---|---|
| #1 在線 indicator | ChatView.swift:303,306 | Hardcoded string `"● 在線"`, no presence at all | Confusing | Yes (remove prefix); real presence is its own phase |
| #2 Time tab dummy entries | TimeView.swift:28–31 | `MockData.entries` | Data-loss risk | Yes |
| #3 紀念日 ghost list → empty detail | ProfileView.swift:42, TimeView.swift:45 | `MockData.anniversaries` (asymmetric — AnniversariesView has no fallback) | Confusing → data-loss risk | Yes |
| #4 我哋 tab dummy data | ProfileView.swift:42, 49, 57, 72; ChatView.swift:36,39,45,46 | `MockData.anniversaries` + `MockData.me/.partner` name/id/iso fallbacks | Confusing | Yes |

All four are view-layer fixes. **No schema migration, no service changes, no new tables.** v1.5.1 can ship as a pure-Swift patch on the same Supabase schema as v1.5.0.
