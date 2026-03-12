# CLAUDE.md

## Project

KeyPilot is a macOS menu bar app for keyboard-driven app switching (Right ⌘ + letter). Native Swift, no Xcode project — built with `swiftc` via Makefile.

## Build

```sh
make bundle   # compile + assemble .app (no signing)
make sign     # compile + assemble + ad-hoc codesign (for distribution)
make run      # bundle + open
make clean    # remove build artifacts
```

- Target: `$(uname -m)-apple-macosx13.0` (arm64 on Apple Silicon)
- SDK resolved dynamically via `xcrun --show-sdk-path`
- No Xcode project, no Package.swift — just `swiftc` with framework flags

## CI/CD

- `.github/workflows/release.yml`: builds and releases `KeyPilot.app.zip` on push to main
- **Skipped scopes:** commits starting with `docs:`, `chore:`, `style:`, or `ci:` do not trigger a release
- Uses `softprops/action-gh-release@v2` with auto-generated build tags (`build-YYYYMMDD-HHMMSS-<sha>`)

## Conventions

- Commit messages use [Conventional Commits](https://www.conventionalcommits.org/) scopes: `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `style:`, `refactor:`
- Only `feat:`, `fix:`, and `refactor:` scopes trigger a new release build
- No tests (yet) — app requires Accessibility permission and global event taps, making automated testing non-trivial

## Code structure

All source in `Sources/KeyPilot/`:

| File | Responsibility |
|------|---------------|
| `KeyPilotApp.swift` | SwiftUI entry point, menu bar UI |
| `AppDelegate.swift` | Lifecycle, event interceptor init/teardown |
| `KeyInterceptor.swift` | CGEventTap for global keyboard capture |
| `AppSwitcher.swift` | App switching/launching logic |
| `AppMapping.swift` | Persistent key→app mappings (UserDefaults) |
| `SettingsView.swift` | SwiftUI settings UI |
| `PermissionHelper.swift` | Accessibility permission helpers |
