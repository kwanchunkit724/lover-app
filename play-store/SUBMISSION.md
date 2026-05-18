# Google Play Console — Submission Guide

End-to-end checklist for getting **Us 我哋** onto Google Play. Everything
machine-buildable lives in this repo; this doc covers the human steps that
require a Google account, payment card, and ID.

## 1. Create a Play developer account

1. Go to <https://play.google.com/console/signup>
2. Sign in with the Google account that will own the app (recommend a
   dedicated account — the publisher name shows on every listing).
3. Choose **Personal** account type (faster verification than Organisation
   for a solo developer). You can convert later.
4. Pay the **USD $25 one-time** registration fee. No recurring cost.
5. Upload a valid **government-issued photo ID** (passport / HKID).
6. Verification takes **1–2 business days**, sometimes up to 7.

While waiting, you can already do steps 2–4.

## 2. Generate the upload keystore (DONE, mechanical)

Done by `android-keystore/upload.keystore`. The two passwords live in
`android-keystore/PASSWORDS.txt` — both files are gitignored.

**Critical:** back up `android-keystore/` to encrypted offline storage
(USB stick in a safe, password manager attachment, etc.). If you lose the
upload key, you can reset it via Play App Signing as long as you opted in —
but only with a 24h delay, and only if Play App Signing was enabled before
the loss. **Lose both = lose the listing forever.**

### Upload key vs app signing key

Play introduced **Play App Signing** in 2017. Two keys exist:

| Key | Held by | Used for |
|---|---|---|
| Upload key | You (this repo's keystore) | Authenticating uploads to Play Console |
| App signing key | Google (Play servers) | Re-signing the AAB before serving to devices |

When you opt into Play App Signing on first upload, Play extracts the key
from your first AAB and keeps a copy on their servers. From then on, you
only need the **upload key**; you can ask Google to reset it if lost. This
is why we are NOT generating a 25-year app-signing key — Google manages it.

## 3. Add 3 GitHub Actions secrets

Repo → Settings → Secrets and variables → Actions → New repository secret.

| Secret name | Value source |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_B64` | Contents of `android-keystore/upload.keystore.b64` (paste the base64 text **including** the `-----BEGIN CERTIFICATE-----` / `-----END CERTIFICATE-----` markers stripped — see below) |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | Line 1 of `android-keystore/PASSWORDS.txt` |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Line 2 of `android-keystore/PASSWORDS.txt` |

> ⚠️ `certutil -encode` writes BEGIN/END marker lines. The workflow
> `base64 --decode` expects pure base64, so when pasting the secret value,
> remove the first and last line. Or generate via:
> `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload.keystore"))`
> in PowerShell to get a clean blob.

## 4. Build a signed AAB

```bash
git tag android-release-v1.5.1
git push origin android-release-v1.5.1
```

GHA `android-release.yml` will produce a signed `.aab` and attach it to a
GitHub Release. Download `app-release.aab` from there.

## 5. Create the Play listing

In Play Console → **Create app**:

| Field | Value |
|---|---|
| App name | `Us 我哋` (from `play-store/listing/app_name.txt`) |
| Default language | Chinese (Hong Kong) — zh-HK |
| App or game | App |
| Free or paid | Free |
| Declarations | Tick both Play policies + US export laws |

Set the **package name** by uploading the AAB (Play auto-detects
`michel.kit.us` from the bundle's `applicationId`).

## 6. Set up Play App Signing

On first AAB upload Play prompts:

> "Let Google generate and manage your app signing key" — **choose this**.

This is the recommended path. Our upload keystore is now permanently the
upload-only key; Google holds the app signing key in their HSM.

## 7. Complete listing copy

Fill each section using files from `play-store/listing/`:

| Console section | Source file |
|---|---|
| App name | `app_name.txt` |
| Short description | `short_description.txt` |
| Full description | `full_description.txt` |
| App icon | `android/app/src/main/res/mipmap-*/ic_launcher.png` (already shipped) |
| Feature graphic | Build per `feature_graphic_spec.md`, drop at `feature_graphic.png` |
| Phone screenshots | 4–6 PNGs captured per `screenshots/README.md` |
| Privacy policy URL | `privacy_policy_url.txt` |
| Support email | `support_email.txt` |
| App category | Communication |
| Content rating | Run the questionnaire using `content_rating_questionnaire.md` |
| Data safety | Fill the form using `data_safety_form.md` |
| Target audience | Adults (18+) |
| Government-grade encryption | Yes — declare exempt under US BIS exception ENC (5D002.c.1) for AES + X25519. See top comment in `android/app/build.gradle.kts`. |

## 8. Internal testing track first

**Do not** go straight to production.

1. Release → Testing → **Internal testing** → Create new release.
2. Upload `app-release.aab`.
3. Add yourself + partner (and any beta testers) as internal testers via
   the testers tab (email list, max 100).
4. Submit for review. Internal-track review is usually **a few hours**.
5. After approval, the Play test link appears — install via that link on
   any signed-in device.

## 9. Promote upward

Internal testing → **Closed testing** (review usually 1–3 days) →
**Open testing** (public opt-in link) → **Production** (full Play listing,
review 3–7 days first time, faster on subsequent updates).

## 10. Subsequent releases

For every new version:
1. Bump `versionCode` + `versionName` in `android/app/build.gradle.kts`
2. Tag `android-release-vX.Y.Z`
3. Download AAB from GHA Release
4. Play Console → Production → Create new release → Upload AAB → roll out
