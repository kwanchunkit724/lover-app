# lover-app

iOS-first kawaii couples app. Two paired users get a private end-to-end encrypted space for chat, a shared memory book, and (later) date activities.

## Documentation

Read in this order:
- [docs/PROJECT.md](docs/PROJECT.md) — what this is, audience, the 4 tabs, MVP cut
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — stack, E2EE design, Postgres schema, push flow
- [docs/PAIRING.md](docs/PAIRING.md) — couple onboarding + key exchange protocol
- [docs/ROADMAP.md](docs/ROADMAP.md) — phased milestones to v1.0

## Building (Windows-only dev)

We build on Codemagic CI, not locally. Setup:
- [docs/WINDOWS_DEV.md](docs/WINDOWS_DEV.md) — VS Code + git + dev loop
- [docs/CODEMAGIC_SETUP.md](docs/CODEMAGIC_SETUP.md) — first build + TestFlight pipeline

## Layout

```
lover-app/
├── docs/                 # design docs (read these first)
├── design-import/        # canonical Claude Design React prototype (visual source of truth)
├── ios/LoverApp/         # SwiftUI sources — translation of design-import/
├── ios/LoverAppTests/    # unit tests
├── ios/LoverAppUITests/  # screenshot capture tests (replace SwiftUI Preview)
├── project.yml           # XcodeGen spec — generates .xcodeproj on the CI runner
├── codemagic.yaml        # CI workflows (dev build + TestFlight)
└── README.md
```
