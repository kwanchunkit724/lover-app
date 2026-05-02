# Windows Dev Setup for an iOS App

You're writing Swift on Windows. Codemagic builds on macOS in the cloud. This file covers what to install locally so the experience is as smooth as it can be.

## Required

### Git
- Download: https://git-scm.com/download/win
- Configure: `git config --global user.email "kck980724@gmail.com"`

That's it. Everything else below is optional but recommended.

## Recommended

### VS Code + Swift extension
- VS Code: https://code.visualstudio.com/
- Extension: search for **Swift** by Swift Server Work Group
- Optional: install the [Swift toolchain for Windows](https://www.swift.org/install/windows/) — gives you syntax checking and autocomplete for *standard* Swift code. iOS-specific APIs (`SwiftUI`, `UIKit`, `Foundation` extensions) won't autocomplete because those frameworks don't ship for Windows. Still useful for catching typos in your own logic.

### Cursor (VS Code fork with built-in AI)
If you don't already use it: https://cursor.sh/ — same extensions, easier to ask "what does this Swift error mean."

### Optional: Swift Playgrounds on iPad
If you have an iPad, install **Swift Playgrounds** from the App Store. It can run individual SwiftUI views (not full app projects) directly on the iPad with live preview. Useful to sanity-check a `View` you're working on, but not a substitute for the CI build for the full app.

## File watching

VS Code default settings work fine. Some helpful tweaks for this project — paste into `.vscode/settings.json`:

```json
{
  "files.exclude": {
    "**/build": true,
    "**/DerivedData": true,
    "**/*.xcodeproj": true,
    "**/.swiftpm": true
  },
  "files.associations": {
    "*.entitlements": "xml",
    "project.yml": "yaml",
    "codemagic.yaml": "yaml"
  },
  "[swift]": {
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": false
  }
}
```

## The dev loop, in detail

```
1.  Open VS Code in C:\Users\user\lover-app\
2.  Edit a .swift file
3.  Save (Ctrl+S)
4.  Open the integrated terminal (Ctrl+`) — bash is your default
5.  git add -A && git commit -m "what changed" && git push
6.  Tab away to Chrome → check Codemagic dashboard
7.  ~10 min later, email arrives with screenshots
8.  Look at screenshots → verify UI matches Claude Design
9.  If broken, fix and repeat from step 2
```

## What you cannot do on Windows

| Feature | Why | Workaround |
|---|---|---|
| SwiftUI Preview canvas | Needs Xcode | CI screenshots after every push |
| Run iOS Simulator | Needs Xcode | Codemagic runs the simulator on the cloud Mac to take screenshots |
| Debug with breakpoints | Needs lldb + simulator | Use `print()` statements; output appears in Codemagic test logs |
| Edit Storyboards / xib files | We don't use them — pure SwiftUI |  |
| Edit `.xcassets` interactively | The folder is just JSON + images; you can edit by hand or use VS Code |  |
| Test push notifications locally | Needs APNs token from Apple | Test via TestFlight on real iPhone |

## What changes versus a Mac dev

- **Iteration speed**: ~10 min per build vs ~5 sec for SwiftUI Preview. Plan UI changes in larger batches before pushing.
- **Type errors**: caught by the cloud build, not your editor. Read errors carefully on first push to avoid back-and-forth.
- **Refactors**: no rename-symbol across files. Use VS Code's "Find and Replace in Files" (Ctrl+Shift+H) carefully.

## Tip: use a "scratch" branch for UI iteration

Push UI tweaks to a branch like `ui-iter` instead of `main`. Codemagic still builds and screenshots; main stays clean. When you're happy, squash-merge to main.

```bash
git checkout -b ui-iter
# ... edits ...
git push -u origin ui-iter
# screenshots arrive, iterate
# happy now? merge:
git checkout main
git merge --squash ui-iter
git commit -m "UI: chat polish"
git push
```
