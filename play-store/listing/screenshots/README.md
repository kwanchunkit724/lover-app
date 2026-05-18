# Play Store Screenshots

Play Store requires **2–8 phone screenshots** per listing. Aim for 4–6 strong shots covering the core surfaces.

## Recommended dimensions

| Spec | Value |
|---|---|
| Aspect ratio | 16:9 portrait (i.e. 9:16) is safest for phone |
| Resolution | 1080 × 1920 minimum, 1440 × 2560 preferred |
| Format | PNG or JPEG, ≤ 8 MB each |
| File naming | `01-chat.png`, `02-time.png`, `03-activities.png`, `04-profile.png` |

Google's docs: <https://support.google.com/googleplay/android-developer/answer/9866151>

## Capture via BlueStacks + adb

BlueStacks is already installed and exposes an adb endpoint on `127.0.0.1:5555`.

```powershell
# 1. Connect
adb connect 127.0.0.1:5555

# 2. Pull a single screen
adb -s 127.0.0.1:5555 exec-out screencap -p > 01-chat.png

# 3. Or capture all four tabs in a loop (navigate manually between shots)
foreach ($name in @('01-chat','02-time','03-activities','04-profile')) {
  Read-Host "Navigate to $name and press Enter"
  adb -s 127.0.0.1:5555 exec-out screencap -p > "$name.png"
}
```

If BlueStacks renders at a non-portrait aspect, switch its display profile to
**Phone (Pixel 7)** in BlueStacks settings before capturing.

## Required shots (suggested)

1. **Chat** — show a real conversation with a reaction + reply (E2EE story)
2. **Time** — calendar with a couple of anniversaries highlighted
3. **Activities** — saved date ideas
4. **Memory Book** — a photo entry
5. **Profile** — theme picker + together-since counter
6. *(optional)* Auth — pairing-code screen ("only two people get in")

Drop the captured PNGs in this folder; the Play Console upload accepts them directly.
