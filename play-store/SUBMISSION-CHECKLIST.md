# Play Store Submission Checklist — Us 我哋 (michel.kit.us)

Status as of session end:
- ✅ App created on Play Console
- ✅ Internal track active with v1.5.0 (build 1)
- ✅ Privacy policy URL saved
- ⏳ All other listing forms pending
- 🚧 Production BLOCKED — new dev account 14-day closed-test rule

## Production blocker (Google rule since Nov 2023)

Before Production unlocks, you must:
1. Run **Closed Testing** with **≥12 testers opted in** for **≥14 days**
2. Apply for Production access — answer questions about closed test
3. Then upload to Production track

So today: set up Closed Testing + fill all listing forms. Production submit in 14 days.

## Forms to complete

All under: https://play.google.com/console/u/0/developers/8040396499621325548/app/4976119215295181965/app-content

Open the URL above, then click each task. (Play Console blocks deep linking — navigate via the dashboard.)

| Task | Answer |
|---|---|
| 私隱政策 | ✅ Done — `https://kwanchunkit724.github.io/lover-app/privacy.html` |
| **應用程式存取權** | Select "All functionality is available without special access" (app is private to paired couples but doesn't gate test review). Actually — pick "All or some functionality in my app is restricted" → add test account: email `kck980724+playreview@gmail.com`, password your test password, instructions: "Sign up two test accounts. Use pairing screen → enter 6-digit code from one device into the other to pair. Anniversary: any past date." |
| **廣告 (Ads)** | "No, my app does not contain ads" |
| **內容分級 (Content Rating)** | Start questionnaire. Category: **Communication / Social**. Answers: violence=No, sexual=No, profanity=No, controlled substances=No, gambling=No, user-generated content=Yes (private chat between 2 paired users, E2E encrypted), location sharing=No, personal info sharing=Yes (between paired partner only). Expected rating: **Everyone / IARC 12+** depending on UGC weighting. |
| **目標對象 (Target Audience)** | Age range: 18+ (couples app). Children's policy: No. |
| **資料安全 (Data Safety)** | See "Data Safety answers" below. |
| **政府應用程式** | No |
| **財務功能** | No |
| **健康** | No |
| **商家應用程式** | No |
| **新聞應用程式** | No |
| **新型冠狀病毒** | No |
| **付款** | No paid content, no IAP, no subscriptions |

## Data Safety answers

Q: Does app collect or share user data?
- **Yes — Collects.**

Data types collected:
- **Personal info — Email**: collected for authentication. Required. Encrypted in transit. User can request deletion (in Settings → Delete account, Apple App Review 5.1.1(v) compliant).
- **Personal info — Name**: optional (display name in profile). Encrypted in transit + at rest (E2E encrypted in chat).
- **Photos**: optional. Encrypted with X25519 ECDH + AES-GCM-256. Never readable by us.
- **Voice audio**: optional. Same E2E encryption.
- **Messages**: required for chat. **End-to-end encrypted — we cannot read messages.**
- **App activity — App interactions**: collected internally for sync (last seen). NOT shared with third parties.
- **Device identifiers — FCM token**: collected for push notifications. Required.

Data shared with third parties: **None.**

Security:
- ✅ Encrypted in transit (HTTPS + TLS 1.2+)
- ✅ Users can request data deletion (in-app + via support email)
- ✅ Independent security review: No (small project)

End-to-end encryption claim: **Yes** — messages + media use X25519 + HKDF-SHA256 + AES-GCM-256. Key never leaves device.

## 主商店資訊 (Main Store Listing)

Files at `play-store/listing/`:
- App name: `Us 我哋`
- Short description (80 char): `兩個人嘅小天地 · 私密對話、紀念日、回憶簿`
- Full description: see `full_description.txt`
- App icon: 512×512 PNG — need to export from `ios/LoverApp/Assets.xcassets/AppIcon.appiconset/`. Use ImageMagick: `magick ios/LoverApp/Assets.xcassets/AppIcon.appiconset/Icon-1024.png -resize 512x512 play-store/icon-512.png`
- Feature graphic: 1024×500 — need to design. Suggested: cream `#F3EEDF` background, "Us 我哋" in serif, rose `#D88B9A` heart accent. Could use Canva / Figma. Spec in `play-store/listing/feature_graphic_spec.md`.
- Screenshots (min 2, recommend 4-8):
  - Use BlueStacks: install v1.5.1 APK, take screenshots at chat / time / activities / profile screens
  - Or take from iPhone (Play accepts iOS-style screenshots for parity)
  - Dimensions: 16:9 portrait (1080×1920) preferred

## Promote AAB Internal → Closed Testing

1. Play Console → Us 我哋 → 測試及發佈 → 封閉測試
2. Click "建立新發佈版本"
3. Pick App Bundle: existing `app-release.aab` (already in Internal track, library will show it)
4. Release notes: copy from Internal track
5. Add testers (need 12+):
   - Recruit 12 friends/family with Gmail accounts
   - Add to a "Closed testers" email list
   - Send them the opt-in URL (Play console shows it under each list)
   - **All 12 must click opt-in for the 14-day timer to start counting**

## Recruit 12 testers — sample message

> Hey, can you help me test my new couples app "Us 我哋" on Google Play?
>
> 1. Open this link on your Android phone: [PLAY OPT-IN URL]
> 2. Sign in with your Gmail
> 3. Click "Become a tester"
> 4. Wait 5 min, open Play Store, search "Us 我哋"
> 5. Install + open + just sign up an account (don't need to pair)
> 6. Keep the app installed for 14 days (Google's rule)
>
> That's it — you don't need to actually use it. Thanks!

## After 14 days

1. Play Console → 資訊主頁 → "正式版" section
2. "申請正式版本存取權" button will be enabled (greyed out today)
3. Click → answer 14-day-test questions
4. Promote AAB from Closed Testing → Production track
5. Submit for Google review (1-7 days first time)

## App icon export — quick script

```bash
# Run in repo root. Requires ImageMagick installed.
magick ios/LoverApp/Assets.xcassets/AppIcon.appiconset/Icon-1024.png \
  -resize 512x512 \
  play-store/icon-512.png
```

## Suggested timeline

| Day | Action |
|---|---|
| Today | App created + Internal track + Privacy URL ✅ |
| Today + 1h | Fill all 8+ content forms above |
| Today + 1h | Promote AAB to Closed Testing |
| Today + 1d | Recruit + invite 12 testers |
| Day 14 | Closed test gate clears → apply for Production access |
| Day 15-21 | Google production review |
| Day 21-22 | Live on Play Store 🎉 |

## Why not just ship v1.4.5-equivalent to Production right away?

Google's 14-day-closed-test rule applies to ALL new personal developer accounts created after Nov 2023, regardless of app maturity. No bypass.

Workaround for future: register as an **organization** developer account ($25 + business verification) — no 14-day gate. Personal accounts are gated.
