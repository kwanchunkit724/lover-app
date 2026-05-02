# Codemagic CI Setup — Windows-only iOS Development

This is your one-time setup guide. After it's done, every `git push` triggers a cloud Mac build and emails you screenshots of the running app.

## Cost expectations

| Stage | Cost |
|---|---|
| Stage 1 (dev builds, simulator only) | **Free** — Codemagic gives 500 macOS build minutes / month free; each dev build takes ~8–12 min, so ~40–60 free builds / month |
| Stage 2 (TestFlight on real iPhone) | Apple Developer Program **US$99/year** (~HK$770) |

Stage 1 needs no Apple account. Do it first to verify the build is green; do Stage 2 when you want to test on your phone.

---

## Stage 1 — Get a green build (free, ~30 min total)

### 1. Push the project to GitHub

If you don't have a repo yet, create a private one on https://github.com/new called `lover-app`.

```bash
cd C:\Users\user\lover-app
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/lover-app.git
git push -u origin main
```

### 2. Sign up for Codemagic
- Go to https://codemagic.io and sign in with GitHub.
- Authorise Codemagic to read your repos.
- From the dashboard, click **Add application** → pick `lover-app` → **iOS App** → **codemagic.yaml**.
- Codemagic will detect the `codemagic.yaml` we already committed.

### 3. Trigger your first build
- In the app dashboard, click **Start new build** → workflow `dev` → branch `main` → **Start**.
- Build runs in 8–12 minutes. You'll see live logs.
- When done, you get an email with `screenshots/*.png` attached — these are PNGs of every tab in your app, captured by the simulator.

### 4. What "green" looks like
- ✅ `Build for Simulator` step: `BUILD SUCCEEDED`
- ✅ `Run unit + UI tests` step: all tests pass
- ✅ Email arrives with 5 PNG attachments: `01-chat`, `02-time`, `03-play`, `04-us`, `05-chat-kaomoji`

If it fails: copy the error log from Codemagic and paste it back to me — I'll fix the source.

---

## Stage 2 — Push to TestFlight on your iPhone (when you want real-device testing)

### 1. Enrol in Apple Developer Program
- Go to https://developer.apple.com/programs/enroll
- Sign in with your Apple ID (the same one on your iPhone)
- Pay US$99/year
- Approval is usually within 24–48 hours

### 2. Register Bundle ID + App Group on Apple Developer Portal
- https://developer.apple.com/account/resources/identifiers/list
- **+** → **App IDs** → **App** → Continue
- Description: `Us`, Bundle ID: **Explicit** → `michel.kit.us`
- Capabilities: ✅ **App Groups**, ✅ **Push Notifications**, ✅ **Sign In with Apple**
- Continue → Register
- Then in left sidebar dropdown switch to **App Groups** → **+** → Description `Us shared group`, Identifier `group.michel.kit.us.shared` → Continue → Register
- Back to **App IDs** → `michel.kit.us` → enable App Groups → Edit → tick `group.michel.kit.us.shared` → Save → Continue → Save

### 3. Create the App Store Connect record
- https://appstoreconnect.apple.com → **Apps** → **+** → **New App**
- Platform: iOS
- Name: `Us` (or alternative if taken — see note below)
- Primary language: Traditional Chinese
- Bundle ID: pick `michel.kit.us` from dropdown
- SKU: `us-app-001`
- User Access: Full Access

> Note: if `Us` is taken on the App Store, use an alternate App Store name like `Us 我哋`. The on-device name (CFBundleDisplayName in `Info.plist`) stays `Us` regardless.

### 4. App Store Connect API key
This lets Codemagic upload to TestFlight without your password.

**If you already have a unified Codemagic integration on your account** (most users): skip this — your existing key works for both Apple Developer Portal AND App Store Connect since the API is unified.

Otherwise:
- https://appstoreconnect.apple.com/access/integrations/api
- **Generate API Key** → Name `Codemagic` → Access **App Manager** → Generate
- ⚠️ Download the `.p8` file immediately (one-time only)
- Note the **Key ID** + **Issuer ID**

### 5. Wire the integration into Codemagic
The `codemagic.yaml` references the integration name `CodeMagic` (the default name when you connected your Apple key in Codemagic Settings → Integrations → Developer Portal).

If your integration has a different name, either:
- **Option A**: rename the integration in Codemagic UI to `CodeMagic`, OR
- **Option B**: edit `codemagic.yaml` and replace `app_store_connect: CodeMagic` with your integration's actual name

Then enable code signing on this specific app:
- Codemagic dashboard → `lover-app` → **Settings** → **iOS code signing**
- Select **Automatic**, pick the Apple Developer Portal integration → Save

### 6. Trigger TestFlight build
TestFlight builds run on git tag, not push. So:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This triggers the `testflight` workflow. After ~15–20 minutes:
- TestFlight gets the new build
- You get an email
- Open the **TestFlight** app on your iPhone (download free from App Store) → install Lover

If the App Store Connect record is in "Internal Testing" mode, only people on your team see it. Add yourself as an Internal Tester in App Store Connect → your app → TestFlight → Internal Testing.

---

## Day-to-day dev loop

```
Edit code in VS Code on Windows
    ↓
git add . && git commit -m "..." && git push
    ↓
Codemagic dev build runs (~10 min)
    ↓
Email arrives with screenshots
    ↓
If looks good → git tag v0.x.y && git push --tags → TestFlight
    ↓
Install on iPhone via TestFlight
```

For incremental UI fixes you do NOT need to tag — push to a branch, get screenshots, iterate. Tag only when you want a phone build.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodegen: command not found` | The CI install step usually fixes this. If it persists, try `instance_type: mac_mini_m2` (already set). |
| Build fails on a Swift compile error | Read the log, fix in source, push again. There is no shortcut without a Mac. |
| Screenshots are blank / wrong screen | Edit `ios/LoverAppUITests/ScreenshotTests.swift` to navigate before snapshot. |
| TestFlight build "Invalid Signature" | Re-create provisioning profile in Codemagic UI; bundle ID mismatch is usually the cause. |
| `app.buttons["時間"]` doesn't find the tab | The text identifier doesn't match the SwiftUI button label exactly. Add `.accessibilityIdentifier("time-tab")` in the view, then use that in the test. |

## Saving build minutes

Each dev build burns ~10 minutes. To stay under the 500 min/month free tier:

- Cancel previous builds when you push (`cancel_previous_builds: true` is already set)
- Disable the dev workflow temporarily by editing `codemagic.yaml` → set `events: []` for dev when you're not actively iterating
- For trivial changes (docs, comments), use `[skip ci]` in your commit message to skip CI entirely

## Useful links
- Codemagic docs: https://docs.codemagic.io/
- XcodeGen reference: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
- App Store Connect API key guide: https://docs.codemagic.io/yaml-code-signing/app-store-connect/
