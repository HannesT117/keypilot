# GitHub Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically build and release KeyPilot.app as a GitHub Release on every push to main.

**Architecture:** A single GitHub Actions workflow triggered on push to main. It runs on a macOS runner, compiles the Swift sources via `make bundle`, zips the `.app` bundle, and creates a GitHub Release with the zip as an asset. Tags are auto-generated from the date and short commit SHA.

**Tech Stack:** GitHub Actions, macOS runner, Make, `zip` CLI

---

## File Structure

| Action | File | Purpose |
|--------|------|---------|
| Create | `.github/workflows/release.yml` | GitHub Actions workflow for build + release |

One file. That's it.

---

## Chunk 1: Release Workflow

### Task 1: Create the release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create workflow directory and file**

Create `.github/workflows/release.yml` with the following content:

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: macos-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build KeyPilot.app
        run: make bundle

      - name: Zip app bundle
        run: zip -r KeyPilot.app.zip KeyPilot.app

      - name: Generate release tag
        id: tag
        run: |
          TAG="build-$(date -u +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"
          echo "Generated tag: $TAG"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.tag.outputs.tag }}
          name: KeyPilot ${{ steps.tag.outputs.tag }}
          body: |
            Automated build from commit ${{ github.sha }}.

            **Commit:** [`${{ github.sha }}`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})
          files: KeyPilot.app.zip
```

**Key detail:** The `SDK="$(xcrun --show-sdk-path)"` override is required because GitHub Actions macOS runners use the Xcode toolchain, where the SDK lives under `/Applications/Xcode.app/...` rather than the standalone CLT path hardcoded in the Makefile.

- [ ] **Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`

If `yaml` module is not available, use: `ruby -ryaml -e "YAML.load_file('.github/workflows/release.yml')"`

Expected: No errors (silent success).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add GitHub Actions workflow for automatic releases

Creates a release with KeyPilot.app.zip on every push to main.
Uses softprops/action-gh-release with auto-generated build tags."
```

---

### Task 2: Push and verify

- [ ] **Step 1: Push to main**

```bash
git push origin main
```

- [ ] **Step 2: Verify on GitHub**

Check the Actions tab on GitHub to confirm:
1. The workflow triggers on the push
2. Build step succeeds (`make bundle` with correct SDK path)
3. A new release appears with tag format `build-YYYYMMDD-HHMMSS-<sha>`
4. `KeyPilot.app.zip` is attached as a release asset

---

## Notes

- **SDK path:** The Makefile uses `$(shell xcrun --show-sdk-path)` which resolves correctly on both local machines and GitHub Actions runners.
- **Architecture:** The Makefile uses `$(shell uname -m)-apple-macosx13.0`. On `macos-latest` (Apple Silicon), this produces `arm64-apple-macosx13.0`.
- **Code signing:** The Makefile performs ad-hoc signing (`codesign --sign -`), which works without a certificate. Users will need to right-click > Open on first launch since the app is not notarized.
- **Release tags:** Format `build-YYYYMMDD-HHMMSS-<short-sha>` ensures uniqueness per commit.
