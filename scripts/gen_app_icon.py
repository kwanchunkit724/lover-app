"""
Generate the Us app icon (Cream x Ink palette, per Claude Design sketch).

Run from repo root:
    python scripts/gen_app_icon.py

Writes ios/LoverApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

Design (matches Claude Design "Cream x Ink"):
  - 1024 x 1024 square (Apple auto-applies the squircle mask)
  - Top ~66% : cream  #F2EBE0  (matches Theme.dark.ink which is the
    light-on-dark cream tone we want as paper for the new theme)
  - Bottom ~34%: ink  #3D2E27 (jbeam ink)
  - Wavy/curved seam between the two halves; a small heart-shaped notch
    sits on the seam (heart bottom point hangs down across the line)
  - "US" wordmark in cream, large, on the ink banner
  - A few small sparkle dots scattered on the cream half
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

SIZE = 1024
CREAM = (242, 235, 224, 255)   # #F2EBE0
INK   = (61, 46, 39, 255)      # #3D2E27
ROSE  = (208, 130, 130, 255)   # subtle rose for heart outline

OUT_DIR  = os.path.join("ios", "LoverApp", "Assets.xcassets", "AppIcon.appiconset")
OUT_PATH = os.path.join(OUT_DIR, "AppIcon-1024.png")


def main():
    img = Image.new("RGBA", (SIZE, SIZE), CREAM)
    d = ImageDraw.Draw(img)

    # 1. Ink banner with a wavy top edge.
    seam_y = int(SIZE * 0.62)        # seam baseline at 62% (cream is bigger)
    wave_amp = int(SIZE * 0.04)      # ±41 px wave amplitude
    wave_periods = 1.3               # gentle wave, almost a single dip in the middle

    # Build the polygon: along the wavy top, then down the right edge,
    # across the bottom, up the left edge.
    polygon = []
    steps = 256
    for i in range(steps + 1):
        x = int(SIZE * i / steps)
        # cosine so the dip is in the middle (where the heart sits)
        y = seam_y + int(wave_amp * math.cos(math.pi * 2 * wave_periods * (i / steps - 0.5)))
        polygon.append((x, y))
    polygon.append((SIZE, SIZE))
    polygon.append((0, SIZE))
    d.polygon(polygon, fill=INK)

    # 2. Heart sitting on the seam at center. Bottom point of the heart
    #    crosses into the ink banner so it visually "locks" the two halves.
    heart_cx = SIZE // 2
    heart_cy = seam_y - int(SIZE * 0.005)   # tiny lift so the lobes are in cream
    heart_size = int(SIZE * 0.14)           # ~143 px
    draw_heart(d, heart_cx, heart_cy, heart_size, fill=CREAM, outline=INK, width=8)

    # 3. "US" wordmark on the ink banner. Big serif, cream colored.
    text = "US"
    # Try a few likely-installed serif fonts; fall back to default.
    font = None
    for candidate in [
        "C:/Windows/Fonts/georgiab.ttf",     # Georgia Bold
        "C:/Windows/Fonts/timesbd.ttf",      # Times New Roman Bold
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    ]:
        if os.path.exists(candidate):
            font = ImageFont.truetype(candidate, int(SIZE * 0.30))
            break
    if font is None:
        font = ImageFont.load_default()

    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = seam_y + (SIZE - seam_y - th) // 2 - bbox[1] + int(SIZE * 0.01)
    d.text((tx, ty), text, fill=CREAM, font=font)

    # 4. Sparkles on the cream half (subtle).
    sparkles = [
        (0.18, 0.18, 6),
        (0.82, 0.16, 4),
        (0.30, 0.32, 3),
        (0.74, 0.28, 5),
        (0.20, 0.45, 4),
        (0.88, 0.42, 3),
    ]
    for sx, sy, sr in sparkles:
        cx, cy = int(SIZE * sx), int(SIZE * sy)
        draw_sparkle(d, cx, cy, sr, fill=ROSE)

    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(OUT_PATH, "PNG")
    print(f"Wrote {OUT_PATH}  ({SIZE}x{SIZE})")


def draw_heart(d, cx, cy, size, fill, outline, width):
    """Polygon-based heart (no anti-aliasing artifacts from compound shapes)."""
    # Parametric heart curve, scaled to `size` units wide.
    # x = 16 sin^3 t,  y = -(13 cos t - 5 cos 2t - 2 cos 3t - cos 4t)
    pts = []
    steps = 200
    scale = size / 32.0
    for i in range(steps + 1):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t)
              - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * scale, cy + y * scale))
    d.polygon(pts, fill=fill, outline=outline)
    # Stroke again with the requested width by drawing the outline as a line.
    d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def draw_sparkle(d, cx, cy, r, fill):
    """4-pointed sparkle / "twinkle" shape."""
    long_arm = r * 2.4
    short_arm = r * 0.8
    pts = [
        (cx, cy - long_arm),
        (cx + short_arm, cy - short_arm),
        (cx + long_arm, cy),
        (cx + short_arm, cy + short_arm),
        (cx, cy + long_arm),
        (cx - short_arm, cy + short_arm),
        (cx - long_arm, cy),
        (cx - short_arm, cy - short_arm),
    ]
    d.polygon(pts, fill=fill)


if __name__ == "__main__":
    main()
