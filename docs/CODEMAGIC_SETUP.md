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

### 2. Create the App Store Connect record
- After approval, go to https://appstoreconnect.apple.com → **Apps** → **+** → **New App**
- Platform: iOS
- Name: `Lover` (or whatever you want — can change later)
- Primary language: Traditional Chinese
- Bundle ID: `app.lover.LoverApp` (must match `project.yml`)
- SKU: any unique string (e.g. `lover-app-001`)
- User Access: Full Access

### 3. Create an App Store Connect API key
This lets Codemagic upload to TestFlight without your password.

- https://appstoreconnect.apple.com/access/api
- Click **+** → name it `Codemagic`
- Access: **App Manager**
- Click **Generate**
- ⚠️ **Download the .p8 file immediately** — you only get one chance
- Note the **Key ID** (10 chars) and **Issuer ID** (UUID at the top of the page)

### 4. Add credentials to Codemagic
- In Codemagic, go to **Teams** → your team → **Integrations** → **Developer Portal** → **App Store Connect** → **Add key**
- Name: `lover-app-asc-key`
- Issuer ID: paste from step 3
- Key ID: paste from step 3
- API key: upload the .p8 file
- Save

Then: **Apps** → `lover-app` → **Settings** → **Environment variables** → **Add group** → name it `app_store_credentials`. Codemagic will auto-link the key when the workflow references this group (it's already wired in `codemagic.yaml`).

### 5. Set up signing
- Codemagic dashboard → your app → **iOS code signing** → **Automatic** → pick the App Store Connect key from step 4.
- It will auto-create distribution certs and provisioning profiles.

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
