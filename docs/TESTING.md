# Testing

How to run and extend tests for **Us** (`lover-app`). Unit tests are the PR gate; UI / Playwright e2e are local / optional.

## What is covered

| Layer | Runner | Scope |
|---|---|---|
| iOS unit (`LoverAppTests`) | XCTest via `xcodebuild test` | Crypto (AES-GCM round-trip / tamper / X25519+HKDF), pairing code format, anniversary date math, `LocalDate` / `TimeFormatting`, `Message` / `Entry` models, smoke (theme / mock / kaomoji bundle) |
| Web unit (`web/lib/**/*.test.ts`) | `tsx --test` (Node test runner) | Crypto (X25519 / HKDF / AES-GCM), `errMsg`, anniversary countdown math |
| Web lint + typecheck | ESLint + `tsc --noEmit` | Next.js app + lib |
| iOS UI (`LoverAppUITests`) | XCUITest | Screenshot capture — **not** in PR CI (flaky / device-dependent) |
| Web e2e (`web/e2e/*.spec.ts`) | Playwright | Pair / chat / photo flows — **do not** point at production; run locally against a dev stack |

## How to run — Web

```bash
cd web
npm ci
npm run lint
npm run typecheck
npm test          # unit only — no Playwright
# optional local e2e (requires app + Supabase env; never hit production):
# npx playwright install
# npm run e2e
```

## How to run — iOS (macOS + Xcode)

```bash
# from repo root
brew install xcodegen   # once
xcodegen generate
xcodebuild test \
  -project LoverApp.xcodeproj \
  -scheme LoverApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:LoverAppTests \
  CODE_SIGNING_ALLOWED=NO
```

Or open `LoverApp.xcodeproj` in Xcode → scheme **LoverApp** → Test (⌘U). Prefer the `LoverAppTests` target only when iterating on unit tests.

`project.yml` already wires `ios/LoverAppTests/**` into the `LoverAppTests` target — new `*Tests.swift` files under that folder are picked up on the next `xcodegen generate`. No `project.yml` change needed for new unit test files.

## CI (PR gate)

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

- **Triggers:** `pull_request`, `workflow_dispatch` — **not** push to `main`, **not** tags
- **Job A (`web`, ubuntu):** `npm ci` → lint → typecheck → unit tests
- **Job B (`ios`, macos-15):** install XcodeGen → `xcodegen generate` → `xcodebuild test -only-testing:LoverAppTests` on an available iPhone Simulator

Release / signing workflows are untouched:

- `ios-testflight.yml` — tag `v*.*.*` → archive + upload TestFlight
- `android-build.yml` / `android-release.yml`

## Crypto note

Docs historically mention ChaCha20-Poly1305; the **shipped** wire format (iOS `CryptoService`, web `lib/crypto/seal.ts`, Android) is **AES-GCM-256** with combined `[12-byte nonce | ciphertext | 16-byte tag]`, HKDF-SHA256 salt = uppercase `couple_id`, info = `us.chat.v1`. Tests assert that layout.

## What is intentionally not unit-tested here

- Supabase RPCs / Realtime / Storage (need network + secrets) — mock or skip
- Keychain-backed `KeyManager.myPrivateKey()` persistence on device
- Sign in with Apple / APNs / RevenueCat
- UI layout / screenshot diffs
- Playwright against production

## Adding tests

1. **iOS pure logic** → new file under `ios/LoverAppTests/`, `@testable import Us`. Prefer testing static / value-type APIs (no `@MainActor` services that hit `SB.client`).
2. **Web pure logic** → `web/lib/**/*.test.ts` next to the module; keep network out.
3. Extract helpers (see `PairingCode`, `anniversary-math.ts`) when UI / service code embeds logic that should be tested.
