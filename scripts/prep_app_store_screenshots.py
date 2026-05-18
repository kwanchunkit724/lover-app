"""
Resize / pad raw iPhone screenshots to Apple's 1290 x 2796 (iPhone 6.7"
display) requirement and rename them in the canonical 1..10 order
expected by App Store Connect's "iPhone 6.7" Display" upload slot.

Run from repo root:
    python scripts/prep_app_store_screenshots.py

Workflow:
  1. AirDrop / iCloud Photos / OneDrive your raw iPhone screenshots into
     app-store/screenshots/raw/ — name them 01.png .. 10.png in the
     order listed in CANONICAL_TITLES below (iPhone screenshots are
     already PNG by default).
  2. Run this script.
  3. Output lands in app-store/screenshots/iphone-6.7/ as
     01_onboarding.png .. 10_profile.png, all exactly 1290x2796.
  4. Drag those 10 files into the App Store Connect "iPhone 6.7" Display"
     screenshot well.

Resizing rule:
  • Native 1290x2796 (iPhone 15/16 Pro Max) → copy as-is, just renamed.
  • Smaller phones (e.g. 1170x2532 iPhone 14/15) → scale up preserving
    aspect ratio so the long edge hits 2796, then pad to 1290 wide
    with the app's Cream theme background (#F2EBE0). Apple accepts
    padded images as long as the final pixel dimensions match exactly.
  • Larger / oddball → scale down to fit 1290x2796.

If you only have some of the 10 raw shots, the script just processes
what it finds and skips missing ones.
"""

from PIL import Image
import os
from pathlib import Path

TARGET_SIZE = (1284, 2778)   # iPhone 6.7" Display — ASC v2026 accepted size
CREAM = (242, 235, 224)   # #F2EBE0 — matches the app's default Cream theme

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR  = ROOT / "app-store" / "screenshots" / "raw"
OUT_DIR  = ROOT / "app-store" / "screenshots" / "iphone-6.7"

# Filename order matters — App Store Connect uses upload order as the
# display order on the App Store product page.
CANONICAL_TITLES = [
    "01_onboarding",       # 「(´｡• ω •｡`) 差啲就好」welcome page
    "02_signin",           # Apple + Email sign-in
    "03_chat",             # paired chat with text + photo
    "04_calendar",         # month grid with real-photo memory cells
    "05_memory_detail",    # entry detail with hero photo
    "06_play_tab",         # 玩樂 tab — 4 tiles
    "07_districts",        # 18 區日記 grid with visited tiles
    "08_mtr",              # MTR 站日記 list
    "09_card_deck",        # 盲盒約會 flipped card
    "10_profile",          # 我哋 tab with paired identity card
]


def load_raw(slot: int) -> Image.Image | None:
    """Look for either 01.png/.jpg/.jpeg/.heic in raw/ for the given slot."""
    for ext in ("png", "jpg", "jpeg", "PNG", "JPG"):
        candidate = RAW_DIR / f"{slot:02d}.{ext}"
        if candidate.exists():
            img = Image.open(candidate).convert("RGB")
            return img
    return None


def fit_to_target(img: Image.Image) -> Image.Image:
    """Scale img so it fits inside TARGET_SIZE preserving aspect ratio,
    then pad with CREAM to hit exact TARGET_SIZE."""
    if img.size == TARGET_SIZE:
        return img

    src_w, src_h = img.size
    tgt_w, tgt_h = TARGET_SIZE
    scale = min(tgt_w / src_w, tgt_h / src_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    scaled = img.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGB", TARGET_SIZE, CREAM)
    offset_x = (tgt_w - new_w) // 2
    offset_y = (tgt_h - new_h) // 2
    canvas.paste(scaled, (offset_x, offset_y))
    return canvas


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    found = 0
    for i, title in enumerate(CANONICAL_TITLES, start=1):
        raw = load_raw(i)
        if raw is None:
            print(f"  [skip]  {i:02d} → no raw file in {RAW_DIR}")
            continue
        out = fit_to_target(raw)
        out_path = OUT_DIR / f"{title}.png"
        out.save(out_path, "PNG", optimize=True)
        found += 1
        print(f"  [ok ]   {i:02d} → {out_path.relative_to(ROOT)}  "
              f"({raw.size[0]}x{raw.size[1]} → {out.size[0]}x{out.size[1]})")

    print(f"\nProcessed {found}/{len(CANONICAL_TITLES)} screenshots.")
    if found > 0:
        print(f"Drag everything in {OUT_DIR.relative_to(ROOT)} into App Store Connect.")


if __name__ == "__main__":
    main()
