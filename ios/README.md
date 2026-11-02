# KK iOS

Plan A rebrand of the Us client. Bundle id stays `michel.kit.us`. The Xcode target and `PRODUCT_NAME` stay `LoverApp` / `Us` so the test host path does not move. The home-screen name is **KK** (`CFBundleDisplayName`), marketing version **2.0.0**.

## Tabs

對話 · 記憶空間 · 想你知道 · 我哋

時間簿、玩樂、約會活動同紀念日列表唔再入導航。日子只係「我哋 → 你哋嘅日子」，可選。

## This slice

Implemented in the app, stored on device:

- Four-tab shell and kaomoji tab icons
- Sign in with Apple + email OTP (no guest)
- Daily mood gate after 06:00 HKT. Third mood is `有啲` + U+6530
- Chat list, composer, kaomoji picker (categories, symbol search, recent, quick reactions max 6), 48h + E2EE banners, multi-select into Memory Space or AI
- Memory Space and 想你知道 list / detail / create
- AI sheet that only accepts typed text and memory items, local 10 / month counter

Not wired, on purpose:

- X25519 chat crypto changes (existing Us E2EE path still seals chat)
- Supabase RPCs named in `KK_IOS_BACKEND_CONTRACT.md`
- Push at 09:00 HKT, 48h purge job, TestFlight archive

Do not point this branch at production data, and do not submit a build.
