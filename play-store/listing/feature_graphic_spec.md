# Feature Graphic — 1024 × 500

Google Play shows this banner at the top of the listing on desktop + as a
fallback hero on mobile. **Required** for production track release.

## Spec

| Field | Value |
|---|---|
| Dimensions | **1024 × 500 px** (exact, no padding) |
| Format | PNG or JPG, RGB, ≤ 1 MB |
| Safe zone | Centre 924 × 400 — Play overlays the install button on the right ~25% on some devices, so keep the focal art left-of-centre |
| Text | Keep to ≤ 6 words; Play already shows the app name elsewhere |
| Localisation | One graphic per locale (zh-HK, en, ja). Start with zh-HK only; clone later |

## Brand palette

| Token | Hex | Use |
|---|---|---|
| Cream | `#F3EEDF` | Background fill |
| Rose | `#D88B9A` | Primary accent (heart, underline, button) |
| Ink | `#3E2E2C` | Headline + body text |
| Cream-2 (optional) | `#FBF6EE` | Soft inner card |

## Suggested layout (zh-HK)

```
┌─────────────────────────────────────────────────────────────────┐
│  [cream background, faint hand-drawn pattern]                   │
│                                                                 │
│   Us 我哋          ┌──── safe zone ────┐                        │
│   ─────             │                  │      [phone mockup     │
│   兩個人嘅小天地    │                  │       showing chat     │
│                     │   ♥ (rose)       │       bubble in        │
│                     │                  │       rose, on cream]  │
│                     └──────────────────┘                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

- Left ~55% — wordmark "Us 我哋" in **Klee One Bold**, tagline below in
  Zen Maru Gothic Regular, small rose heart between.
- Right ~45% — a single phone mockup (Pixel-style frame, ink colour) angled
  ~12° showing the chat screen with one rose reply bubble + one cream
  incoming bubble. Keep right edge tight; Play will crop ~80px on tablets.
- Avoid drop shadows in the safe zone (Play applies its own).

## Quick-build options

1. **Figma** — fastest. Frame 1024×500, brand palette as styles, export 1×.
2. **Claude Design** — UI design is handled separately per user preference.
   Hand off this spec there.

Drop the exported file at `play-store/listing/feature_graphic.png` when ready.
