# BabyKeys

Your baby loves video calls. They also love keyboards. BabyKeys keeps the call alive by locking your keyboard and trackpad while little hands explore.

## How it works

Hold **Right ⌘ for 5 seconds** to lock. Hold it again for 5 seconds to unlock. The menu bar icon switches between 🔓 and 🔒 so you always know the state.

The lock clears automatically when you close the lid or restart — no surprises when you open the laptop back up.

## Install

```sh
make run
```

Then grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility). This is required for the keyboard/trackpad interception to work.

## Build

```sh
make bundle   # compile + assemble BabyKeys.app
make sign     # ad-hoc codesign (for distribution)
make run      # build + launch
make clean    # remove build artifacts
```

Requires macOS 13+. No Xcode needed — built with `swiftc` via Makefile.

## Notes

- Power button long-press still works for shutdown
- The lock never survives a restart or lid close
- Quit from the menu bar icon to exit (unlocks first)
