# App Store screenshots

Apple requires **iPhone 6.7" Display** screenshots at exactly **1290 × 2796** pixels for new App Store submissions.

## Workflow

1. Take the 10 screenshots on your iPhone in this order:

   | # | Screen |
   |---|---|
   | 01 | Onboarding 「(´｡• ω •｡`) 差啲就好」welcome page |
   | 02 | Sign in 頁 (Apple + Email 兩個掣) |
   | 03 | Chat tab — paired, with text + photo |
   | 04 | Time tab — month grid with real-photo memory cells |
   | 05 | Time tab — entry detail with hero photo |
   | 06 | 玩樂 tab — 4 tiles |
   | 07 | 玩樂 → 18 區日記 — visited tiles with photos |
   | 08 | 玩樂 → MTR 站日記 — 港島綫 expanded |
   | 09 | 玩樂 → 盲盒約會 — flipped card |
   | 10 | 我哋 tab — paired identity card |

2. Transfer to PC (iCloud Photos / OneDrive / email / USB).

3. Drop each screenshot into `raw/` named **01.png** through **10.png** (the order is what App Store Connect uses for the gallery).

4. From repo root run:

   ```bash
   python scripts/prep_app_store_screenshots.py
   ```

5. Properly-sized files land in `iphone-6.7/`. Drag all 10 into the App Store Connect "iPhone 6.7" Display" upload slot.

## Folders

- `raw/` — drop your unprocessed screenshots here (any size, will be padded with cream)
- `iphone-6.7/` — output, ready for upload (1290 × 2796 each)

If your phone is **iPhone 15 Pro Max / 16 Pro Max** the screenshots are already 1290 × 2796 — the script just renames them. For smaller phones it scales up + pads with the app's Cream background (#F2EBE0) so the look stays consistent.
