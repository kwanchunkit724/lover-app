# KK web

KK is the lover-app web client rebranded for couples in Hong Kong:
**zh-Hant (Cantonese) primary**, English secondary. Cream / warm-paper UI with
terracotta accent and **kaomoji-led** decoration (not ordinary emoji).

## What it is

Four tabs:

| Tab | Route | Notes |
|-----|-------|-------|
| 對話 | `/chat` | E2EE chat (X25519 + AES-GCM). 48h auto-delete banner. Multi-select → merge to 記憶空間 or AI. |
| 記憶空間 | `/memory` | Shared memories (categories 日常/約會/計劃/其他). AI entries live here (手打提議 / 跟原話搵計劃), quota 10/couple/month. |
| 想你知道 | `/tell` | Shared notes + read receipts; persists until both delete. |
| 我哋 | `/us` | Settings, language, AI quota, optional「你哋嘅日子」, kaomoji prefs, unpair, delete account. |

Other routes: `/login` (Apple + Email OTP only — **no guest/anon**), `/onboarding`, `/pair` (6-digit code), `/mood` (daily HKT gate after 06:00).

Removed / redirected: 時間簿 (`/time` → `/memory`), `/profile` → `/us`. Do **not** delete retired Supabase tables (`anniversaries`, `entries`, `play_history`, `meetups`, `checklist_items`).

## Auth

- Sign in with **Apple**
- **Email OTP**
- Anonymous / 試玩 login **removed**

## How to run

```bash
cd web
create .env.local with NEXT_PUBLIC_SUPABASE_URL + NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```

Scripts: `npm run build` · `npm run lint` · `npm test` · `npm run e2e`

## Deploy

Vercel project: **`lover-app-web`** (historically deployed via CLI).
**Recommend linking the GitHub repo** so previews/PRs deploy automatically.
**Production deploy only after** backend RPCs/tables are ready and tests pass.
Do not `vercel deploy --prod` from this branch until then.

## Env

Required (publishable; RLS enforces access — never commit secrets):

```bash
NEXT_PUBLIC_SUPABASE_URL=https://stzfhdjuiupejonyckdu.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<us-app anon or sb_publishable_… key>
```

Copy into `.env.local` (gitignored). No additional KK-specific secrets for the
web client. Gemini Edge is optional; AI RPC returns a stub until it is deployed.

## Backend adapter

UI talks to `lib/kk/api.ts`, which calls live Supabase `kk_*` RPCs + RLS selects
on us-app (`stzfhdjuiupejonyckdu`). Contract:

- Tables: `memory_items`, `want_you_know`, `want_you_know_reads`, `ai_usage`,
  `kaomoji_prefs`, `kaomoji_catalog`
- RPCs: `kk_set_daily_mood`, `kk_memory_create/update/delete`, `kk_memory_from_chat`,
  `kk_want_create/update`, `kk_want_mark_read`, `kk_want_soft_delete`,
  `kk_ai_consume_and_run`, `kk_ai_usage_get`, `kk_kaomoji_prefs_get/set`,
  `kk_purge_expired_messages` (optional client; primary purge is Edge/cron)
- Lists: `memory_items` / `want_you_know` via select (RLS); no list RPC
- Reuse: `pairing_codes`, `users.mood` / `mood_updated_at`, `messages.expires_at`
- Mood values: 開心 / 平靜 / **有啲攰** (U+6530) / 低落 / 掛住你 / 有啲煩
- Sleep kaomoji category `label_zh`: **睡** (U+7761)

Chat crypto + pairing still use the existing `lib/services/*` + Supabase layer.
`localStorage` remains a cache for daily mood gate + kaomoji prefs fallback.
