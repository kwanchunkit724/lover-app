# App Store listing — Us (我哋)

Use these strings when filling in App Store Connect's metadata for the first submission.

## Basic

| Field | Value |
|---|---|
| App name | Us |
| Subtitle | 我哋兩個人嘅小天地 |
| Bundle ID | `michel.kit.us` |
| SKU | us-app-michel-kit |
| Primary language | Traditional Chinese (Hong Kong) |
| Category (primary) | Lifestyle |
| Category (secondary) | Social Networking |
| Age rating | 12+ (User-generated content + infrequent/mild romantic themes) |

## Pricing

- Free
- Available in: All territories (default)
- No in-app purchases for v1

## Privacy

| Setting | Answer |
|---|---|
| Data Collection: Identifiers | Apple ID (linked to user, app functionality) |
| Data Collection: Contact Info | Email (linked to user, app functionality) |
| Data Collection: User Content | Messages, photos, audio (linked to user, app functionality, **encrypted in transit and at rest**) |
| Data Collection: Usage Data | None |
| Data Collection: Diagnostics | None |
| Data sold to third parties? | No |
| Data used for tracking? | No |
| Privacy Policy URL | `https://kwanchunkit724.github.io/lover-app/privacy.html` |

## Description (zh-Hant)

```
Us — 兩個人嘅小天地

Us 係專為情侶設計嘅私密 App。所有對話、相片、語音訊息、共同行事曆、紀念日、感激清單同小遊戲全部端到端加密 — 連我哋 (developer) 都讀唔到。

主要功能
• 對話：文字、相片、語音訊息，全程 E2EE，partner 上線即時收到
• 時間：共同日曆，加新計劃，兩個人嘅手機即時同步
• 紀念日：共同倒數每年/每月嘅特別日子
• 玩樂：盲盒約會卡、每日感激清單、情侶問題小測驗 (心有靈犀！)
• Sign in with Apple，唔需要記另一個密碼
• 每個 couple 有自己嘅加密 key — 換 device 嘅話舊嘅訊息會自動失效

私隱保證
我哋唔賣你嘅資料、唔追蹤你、亦冇任何第三方廣告 SDK。Server 上見到嘅都係 ciphertext blob — 連 developer 都解密唔到。

由情侶設計，畀情侶用 ♡
```

## Description (en)

```
Us — a small private space for two

Us is a kawaii couples-only app where every chat message, photo, voice note, shared calendar entry, anniversary, gratitude journal, and quiz answer is end-to-end encrypted on your device. Even the developer cannot read your data.

Features
• Chat: text + photo + voice, fully E2EE, instant delivery via Realtime
• Timetable: shared calendar that syncs to both phones live
• Anniversaries: countdowns to the dates that matter to the two of you
• Play: blind-box date cards, daily gratitude journal, relationship quiz with "心有靈犀" matching
• Sign in with Apple, no extra password to remember
• Per-couple encryption keys — old messages auto-invalidate when you change device

Privacy
No tracking. No third-party ads. No analytics SDKs. The server only sees opaque encrypted blobs.

Made for two ♡
```

## Keywords (max 100 chars, comma-separated, en)

```
couples,relationship,chat,messaging,journal,anniversary,e2ee,private,kawaii,date,memory
```

## Promotional text (zh-Hant, max 170 chars)

```
情侶限定 ♡ 端到端加密嘅對話、共同行事曆、紀念日倒數、約會盲盒、感激清單。Server 都讀唔到 — 真正只有你哋兩個睇到。
```

## What's New in this version (v1.4.4)

```
✦ 第一版上架！
• 端到端加密對話：文字、相片、語音、push 通知
• 共同行事曆 + 真相片做記憶 — 過咗嗰日就自動變紀念
• 紀念日 同步倒數
• 18 區日記：一齊行勻香港，一區一篇
• MTR 站日記：90 個站，9 條線，一齊搭遍
• 盲盒約會卡：24 張，做過嘅唔再出
• 4 個主題：Cream × Ink、日系奶油、Notion 暖紙、深夜暖色
```

## Screenshots required

Apple requires at minimum:
- **iPhone 6.5" or 6.7" display** (e.g. iPhone 14 Pro / iPhone 15 Pro Max) — one set of 3-10 screenshots
- iPad screenshots are optional unless you support iPad (we don't — TARGETED_DEVICE_FAMILY is iPhone only)

Suggested screenshot story (10 screens):
1. Onboarding welcome `(♡˙︶˙♡) Us` — kawaii hook
2. Chat tab with sample E2EE conversation (use a paired test couple)
3. Voice + photo messages in the chat stream
4. 時間 tab with month grid + selected day entries
5. Anniversaries hero card showing countdown
6. 玩樂 → Date card flipped
7. 玩樉 → 感激清單 timeline
8. 玩樂 → Quiz reveal with 心有靈犀 ♡ badge
9. 我哋 tab with identity card + 已配對 ♡ badge
10. Theme picker showing 3 themes side-by-side

Marketing tip: capture screenshots on a clean iPhone simulator at 6.7" with HKT date set so 紀念日 countdowns make sense (e.g. 紀念日 2 days away).

## Reviewer notes

```
Us is a paired couples app. To test the full feature set the reviewer needs TWO devices (or simulator + device) signed in with two different Apple IDs.

Quick test path with one device (limited but viable):
1. Launch the app, walk through onboarding (4 steps + theme).
2. Tap "Sign in with Apple" and confirm with Face ID / Touch ID.
3. Tap "我嚟生成配對碼" → pick any anniversary date → "生成配對碼".
4. Note the 6-digit code shown.
5. Sign out (Profile → 帳戶 → 登出), then re-onboard with a different Apple ID.
6. Tap "對方畀咗我配對碼", enter the 6-digit code from step 4 + the same anniversary date.
7. Both signed-in instances should now route to MainTabView (chat, time, play, profile).
8. From the second device/account, send a text message in chat — paired devices receive it via Realtime within 1s.

Demo account NOT provided — Sign in with Apple is the only auth method, so creating the demo account would expose the reviewer's own Apple ID. The flow above is fully testable with reviewer-side accounts.

E2EE technical notes:
- X25519 ECDH on Apple's CryptoKit, AES-GCM 256, HKDF-SHA256 keyed by couple_id.
- The server (Supabase) stores ciphertext blobs only — see PRIVACY_POLICY.md for full breakdown.
- Encryption uses standard algorithms in the same way as the iOS OS (CryptoKit), so the app is exempt from Export Compliance documentation (ITSAppUsesNonExemptEncryption=false).

If the reviewer needs anything else, contact kck980724@gmail.com — we typically reply within 24 hours.
```

## Support / Marketing URLs

- Support URL: `https://kwanchunkit724.github.io/lover-app/support.html`
- Marketing URL: `https://kwanchunkit724.github.io/lover-app/`

## Pre-submission checklist

- [ ] Bundle id `michel.kit.us` registered in App Store Connect (already done — app exists)
- [ ] App Store version 1.0 created in App Store Connect (do this before uploading the final IPA)
- [ ] Privacy policy hosted on a public HTTPS URL
- [ ] Support URL hosted
- [ ] App icon final (1024×1024) in `Assets.xcassets/AppIcon.appiconset/` — replace placeholder before final upload
- [ ] All 10 screenshots captured + uploaded
- [ ] Description + keywords + promotional text pasted in
- [ ] Reviewer notes pasted in
- [ ] Privacy questionnaire answered (use the table above as template)
- [ ] Build attached (the latest TestFlight build will appear as selectable)
- [ ] Submit for review
