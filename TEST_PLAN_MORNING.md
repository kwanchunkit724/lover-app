# Morning test plan — Phase 4 (v0.4.0 → v0.4.2)

## What shipped overnight

| Tag | Phase | What it does |
|---|---|---|
| **v0.3.3** | bug fix | Generator picks anniversary on Generate screen + nickname-friendly onboarding copy |
| **v0.4.0** | Phase 4a — keys + text | X25519 keypairs in Keychain, AES-GCM E2EE on text messages, 3-second polling |
| **v0.4.1** | Phase 4b — realtime + push scaffold | Supabase Realtime channel for instant message delivery; iOS APNs token registration (server-side delivery is Phase 6) |
| **v0.4.2** | Phase 4c — photos | PHPicker → encrypt → upload to Supabase Storage chat-media bucket |

Build chain hit two compile-error bumps (file-name collisions with old skeletons, missing `ObservableObject` conformance) — v0.4.0 + v0.4.1 are red on Codemagic, v0.4.2 should be green and supersedes everything before it. Install **0.4.2** when you wake.

## Migrations applied to Supabase

- 0004 — `users.public_key` + `messages` table + RLS
- 0005 — Realtime publication on messages + `users.device_token` + `set_device_token` RPC
- 0006 — `chat-media` private storage bucket + RLS

---

## Solo-testable on your iPhone (no partner needed)

### A. Sign-in still works after the rewrite
1. Delete Us, install v0.4.2 from TestFlight
2. Walk onboarding (you've done this 5 times now — fast)
3. Sign in with Apple → expect `(´｡• ᵕ •｡`)` 配對 screen, NOT `(◕‿◕) 已登入` placeholder

### B. New pairing flow with anniversary picker
4. Tap **我嚟生成配對碼** → expect a wheel date picker (NEW step)
5. Pick May 22 → tap **生成配對碼** → see 6 digits + sage card showing **對方要輸入嘅紀念日: 2026.05.22**
6. Tap **換日期 / 換 code** → back to date picker → pick a different date → 生成 → new code, new locked-in anniversary

### C. Wrong-code rejection (proves cross-check works)
7. Back → **對方畀咗我配對碼** → enter `000000` + any date → tap 配對 → expect red error **「配對碼錯咗 — 再對下」**
8. Back → generate a fresh code on your own phone → switch to enter mode → enter your OWN code → expect **「唔可以同自己 pair 喎 ｡°(°.◜ᯅ◝°)°｡」**

### D. Onboarding copy
9. 我哋 → 帳戶 → 重設個人資料 → re-walk onboarding
10. Step 2 should say **"你叫咩？"** with hint "暱稱、英文名、外號…乜都得"
11. Step 3 should say **"你點稱呼對方？"** with hint "你哋之間嗌嘅嗰個就得，唔使真名"

### E. Theme picker still live
12. On the Pick-Theme step, tap each card — entire flow recolors instantly

### F. Notification permission prompt
13. Once paired (use the simulator hack below if no partner) → expect iOS prompt: **"Us would like to send you Notifications"** → Allow
14. Settings app → Notifications → Us should be listed

---

## Two-device paired test (need Joan's iPhone or another sign-in)

### G. Real chat message
1. Both phones: install v0.4.2, sign in, walk onboarding
2. Phone A generates code + picks May 22, Phone B enters same code + same date → both jump to chat tab
3. Phone A sends `早安 (´｡• ω •｡`)` → Phone B sees it within 3 seconds (Realtime should be near-instant; 3s is fallback poll)
4. Phone B replies → Phone A sees it
5. Force-quit + reopen on either phone → chat history should restore from server

### H. Decryption integrity
6. Tap a message bubble — should look exactly like the kawaii design
7. The message header on Phone A should show **partner's actual name** (not "Michel")
8. Days-together counter in the chat header should match your real anniversary

### I. Photo send (display deferred to v0.4.3)
9. Phone A → tap the camera icon in composer → pick a photo from library
10. The photo upload happens silently — there's no progress indicator yet
11. **Verify the upload worked** by visiting Supabase Storage:
    https://supabase.com/dashboard/project/stzfhdjuiupejonyckdu/storage/buckets/chat-media
    You should see a folder `couple-{uuid}/` with a `.bin` file
12. The photo bubble in chat will currently show a gray placeholder (display in v0.4.3) — but the message arrives on Phone B's chat with the placeholder too, proving the message round-tripped

### J. Identity sync still works
13. 我哋 tab on either phone → identity card shows real names + sage **已配對 ♡** badge
14. Tap 解除配對 → confirm → both phones drop back to PairingView

---

## What I'd love feedback on

- **Naming UX**: do "你叫咩？" + "你點稱呼對方？" feel right? Want it more 日系 / more casual?
- **Generate flow**: is the date picker on the Generate screen the right spot, or would you rather pre-fill with onboarding date and confirm?
- **Chat empty state**: currently `(´｡• ω •｡`) 仲未有訊息 — 講句嘢試下` — want richer kawaii?
- **Header status**: shows `● 在線 · 一齊 N 日` but "在線" is fake — partner might not actually be online. Should it show last-seen or just remove?

---

## What's queued for next stretch

- **v0.4.3** — display photos in chat bubbles (download + decrypt + render via async-image), voice messages via AVAudioRecorder
- **v0.5.x** — shared timetable + anniversaries with E2EE (Phase 5)
- **v0.6.x** — polish: real Claude Design app icon, Apple Push edge function, App Store screenshots/description, submission

Wake up + tell me which of A–J broke and what feels off. I'll keep iterating from there.
