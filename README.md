# KeyPilot

KeyPilot is a macOS menu bar app that lets you instantly switch to any application by pressing **Right ⌘ + a letter key**.

## Usage

| Shortcut | Action |
|---|---|
| Right ⌘ + letter | Switch to (or launch) the assigned app |
| Right ⌘ + ⌥ + letter | Assign the current frontmost app to that key |

Open **Settings** from the menu bar icon to view, edit, or remove assignments.

## Build

Requires Xcode Command Line Tools.

```sh
make run      # build, bundle, and launch
make bundle   # build KeyPilot.app only
make clean    # remove build artifacts
```

## Icon

Regenerate the app icon with:

```sh
python3 Scripts/generate_icon.py   # outputs Resources/KeyPilot.icns
```
