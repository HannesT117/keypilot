# Monorepo Conversion Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the single-tool keypilot repo into a monorepo by rewriting 5 commit message scopes and restructuring all files under `keypilot/`.

**Architecture:** Rewrite the 5 KeyPilot-era commit messages using `git filter-branch`, then make one new commit that moves all files into `keypilot/`, splits `.gitignore`, creates root `README.md` and `CLAUDE.md`, and replaces `release.yml` with a path-filtered `keypilot.yml`.

**Tech Stack:** git, bash, GitHub Actions (YAML), Swift/macOS (existing, not modified)

**Spec:** `docs/superpowers/specs/2026-03-13-monorepo-conversion-design.md`

---

## Chunk 1: Rewrite commit message scopes

### Task 1: Rewrite the 5 KeyPilot-era commit messages

**Files:**
- No files created/modified — this rewrites git history only

- [ ] **Step 1: Verify the 5 target commits before rewriting**

Run:
```bash
git log --oneline
```

Expected output (newest first):
```
<sha> docs: add monorepo conversion implementation plan
<sha> docs: update monorepo conversion spec with reviewer fixes
<sha> docs: add monorepo conversion design spec
<sha> ci: fix release skip logic for multi-line commit messages
<sha> docs: add permissions, installation, and disclaimer to README
<sha> ci: check all commits in push before skipping release
<sha> ci: add GitHub Actions release workflow and update README
<sha> feat: KeyPilot v1 — keyboard-driven app switcher for macOS
<sha> Initial commit
```

Confirm exactly these 9 commits are present before proceeding.

- [ ] **Step 2: Rewrite commit messages using filter-branch**

Run:
```bash
git filter-branch -f --msg-filter '
sed \
  -e "s/^feat: KeyPilot v1/feat(keypilot): KeyPilot v1/" \
  -e "s/^ci: add GitHub Actions/ci(keypilot): add GitHub Actions/" \
  -e "s/^ci: check all commits/ci(keypilot): check all commits/" \
  -e "s/^docs: add permissions/docs(keypilot): add permissions/" \
  -e "s/^ci: fix release skip/ci(keypilot): fix release skip/"
' -- HEAD
```

- [ ] **Step 3: Verify the rewritten history**

Run:
```bash
git log --oneline
```

Expected (newest first):
```
<sha> docs: add monorepo conversion implementation plan
<sha> docs: update monorepo conversion spec with reviewer fixes
<sha> docs: add monorepo conversion design spec
<sha> ci(keypilot): fix release skip logic for multi-line commit messages
<sha> docs(keypilot): add permissions, installation, and disclaimer to README
<sha> ci(keypilot): check all commits in push before skipping release
<sha> ci(keypilot): add GitHub Actions release workflow and update README
<sha> feat(keypilot): KeyPilot v1 — keyboard-driven app switcher for macOS
<sha> Initial commit
```

Confirm: only the 5 KeyPilot-era commits are scoped; "Initial commit" and the two spec commits are unchanged.

---

## Chunk 2: File restructuring

### Task 2: Create keypilot/ directory and move files

**Files:**
- Create directory: `keypilot/`
- Move: `README.md` → `keypilot/README.md`
- Move: `CLAUDE.md` → `keypilot/CLAUDE.md`
- Move: `Makefile` → `keypilot/Makefile`
- Move: `Info.plist` → `keypilot/Info.plist`
- Move: `KeyPilot.entitlements` → `keypilot/KeyPilot.entitlements`
- Move: `LICENSE` → `keypilot/LICENSE`
- Move: `Sources/` → `keypilot/Sources/`
- Move: `Resources/` → `keypilot/Resources/`
- Move: `Scripts/` → `keypilot/Scripts/`
- Move: `docs/` → `keypilot/docs/`

- [ ] **Step 1: Move all KeyPilot files into keypilot/**

Run:
```bash
mkdir keypilot
git mv README.md keypilot/README.md
git mv CLAUDE.md keypilot/CLAUDE.md
git mv Makefile keypilot/Makefile
git mv Info.plist keypilot/Info.plist
git mv KeyPilot.entitlements keypilot/KeyPilot.entitlements
git mv LICENSE keypilot/LICENSE
git mv Sources keypilot/Sources
git mv Resources keypilot/Resources
git mv Scripts keypilot/Scripts
git mv docs keypilot/docs
```

- [ ] **Step 2: Verify the moves**

Run:
```bash
git status --short
```

Expected: all moved files shown as renamed (e.g., `R  README.md -> keypilot/README.md`). No unexpected deletions or additions.

### Task 3: Split .gitignore

**Files:**
- Modify: `.gitignore` (remove build artifact paths, keep repo-wide patterns)
- Create: `keypilot/.gitignore` (build artifact paths, relative to keypilot/)

- [ ] **Step 1: Create keypilot/.gitignore with build artifact paths**

Create `keypilot/.gitignore` with this exact content:
```
# Build outputs
/KeyPilot
/KeyPilot.app/
*.iconset/
*.dSYM.zip
*.dSYM

# Generated Xcode project
*.xcodeproj/
xcuserdata/

# Swift Package Manager
.build/
```

- [ ] **Step 2: Replace root .gitignore with repo-wide patterns only**

Replace the content of `.gitignore` with:
```
# macOS
.DS_Store
```

- [ ] **Step 3: Stage the .gitignore changes**

Run:
```bash
git add .gitignore keypilot/.gitignore
```

### Task 4: Create root README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create root README.md**

Create `README.md` at the repo root with this exact content:
```markdown
# macOS Tools

Small macOS utilities built with AI.

## Tools

| Tool | Description |
|------|-------------|
| [KeyPilot](keypilot/) | Keyboard-driven app switcher — Right ⌘ + letter to jump to any app |
```

- [ ] **Step 2: Stage it**

Run:
```bash
git add README.md
```

### Task 5: Create root CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Create root CLAUDE.md**

Create `CLAUDE.md` at the repo root with this exact content:
```markdown
# CLAUDE.md

## Repo layout

This is a monorepo for small macOS tools built with AI. Each tool lives in its own subdirectory.

| Directory | Tool |
|-----------|------|
| `keypilot/` | KeyPilot — keyboard-driven app switcher |

## Adding a new tool

1. Create a `<toolname>/` subdirectory with its own `CLAUDE.md`, `Makefile`, and source files.
2. Add a workflow at `.github/workflows/<toolname>.yml` path-filtered to `<toolname>/**`.
3. Document the tool in the root `README.md`.

## CI convention

Each tool has its own workflow file (`.github/workflows/<toolname>.yml`) that triggers only on
changes inside that tool's subdirectory (`paths: ['<toolname>/**']`).

## Commit scope convention

All commits use the tool name as the conventional commit scope:
`feat(keypilot): ...`, `fix(keypilot): ...`, `ci(keypilot): ...`

Repo-level changes (e.g., root README, CLAUDE.md) use no scope: `chore: ...`, `docs: ...`

## Per-tool instructions

For build commands and code structure, read the `CLAUDE.md` inside the tool's subdirectory.

## Tool CLAUDE.md imports

@keypilot/CLAUDE.md
```

- [ ] **Step 2: Stage it**

Run:
```bash
git add CLAUDE.md
```

### Task 6: Replace release.yml with keypilot.yml

**Files:**
- Delete: `.github/workflows/release.yml`
- Create: `.github/workflows/keypilot.yml`

- [ ] **Step 1: Create keypilot.yml**

Create `.github/workflows/keypilot.yml` with this exact content:
```yaml
name: Release KeyPilot

on:
  push:
    branches: [main]
    paths: ['keypilot/**']

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: macos-latest
    steps:
      - name: Check for releasable commits
        id: check
        run: |
          HOUSEKEEPING='^(docs|chore|style|ci)(\([^)]+\))?:'
          HOUSEKEEPING_COUNT=0
          TOTAL=0
          # Use ||| as delimiter so multi-line commit bodies don't split into
          # extra entries. Only the subject line (before the first newline) of
          # each commit is checked.
          joined='${{ join(github.event.commits.*.message, '|||') }}'
          IFS='|||' read -ra MESSAGES <<< "$joined"
          for msg in "${MESSAGES[@]}"; do
            subject=$(printf '%s' "$msg" | head -n1)
            [ -z "$subject" ] && continue
            TOTAL=$((TOTAL + 1))
            if echo "$subject" | grep -qE "$HOUSEKEEPING"; then
              HOUSEKEEPING_COUNT=$((HOUSEKEEPING_COUNT + 1))
            fi
          done
          if [ "$TOTAL" -eq "$HOUSEKEEPING_COUNT" ]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
            echo "All $TOTAL commit(s) are housekeeping — skipping release"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
            echo "Found releasable commits ($((TOTAL - HOUSEKEEPING_COUNT))/$TOTAL)"
          fi

      - name: Checkout
        if: steps.check.outputs.skip != 'true'
        uses: actions/checkout@v4

      - name: Build and sign KeyPilot.app
        if: steps.check.outputs.skip != 'true'
        working-directory: keypilot
        run: make sign

      - name: Zip app bundle
        if: steps.check.outputs.skip != 'true'
        working-directory: keypilot
        run: zip -r KeyPilot.app.zip KeyPilot.app

      - name: Generate release tag
        if: steps.check.outputs.skip != 'true'
        id: tag
        working-directory: keypilot
        run: |
          TAG="build-$(date -u +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"
          echo "Generated tag: $TAG"

      - name: Create GitHub Release
        if: steps.check.outputs.skip != 'true'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.tag.outputs.tag }}
          name: KeyPilot ${{ steps.tag.outputs.tag }}
          body: |
            Automated build from commit ${{ github.sha }}.

            **Commit:** [`${{ github.sha }}`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})
          files: keypilot/KeyPilot.app.zip
```

- [ ] **Step 2: Remove the old release.yml and stage changes**

Run:
```bash
git rm .github/workflows/release.yml
git add .github/workflows/keypilot.yml
```

### Task 7: Commit the restructuring

- [ ] **Step 1: Verify staging area**

Run:
```bash
git status
```

Expected: staged changes show all the file moves, new `keypilot/.gitignore`, new root `README.md` and `CLAUDE.md`, deleted `release.yml`, new `keypilot.yml`. Working tree should be clean (no unstaged changes).

- [ ] **Step 2: Commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
chore: restructure repo as monorepo

Move all KeyPilot files into keypilot/ subdirectory. Add root README and
CLAUDE.md describing the monorepo. Replace release.yml with keypilot.yml,
path-filtered to keypilot/**, and update housekeeping regex to handle
conventional commit scopes.
EOF
)"
```

- [ ] **Step 3: Verify final git log**

Run:
```bash
git log --oneline
```

Expected (newest first):
```
<sha> chore: restructure repo as monorepo
<sha> docs: add monorepo conversion implementation plan
<sha> docs: update monorepo conversion spec with reviewer fixes
<sha> docs: add monorepo conversion design spec
<sha> ci(keypilot): fix release skip logic for multi-line commit messages
<sha> docs(keypilot): add permissions, installation, and disclaimer to README
<sha> ci(keypilot): check all commits in push before skipping release
<sha> ci(keypilot): add GitHub Actions release workflow and update README
<sha> feat(keypilot): KeyPilot v1 — keyboard-driven app switcher for macOS
<sha> Initial commit
```

- [ ] **Step 4: Verify directory structure**

Run:
```bash
find . -not -path './.git/*' -not -path './.claude/*' | sort
```

Expected root-level entries: `.github/`, `.gitignore`, `CLAUDE.md`, `README.md`, `keypilot/`
Expected `keypilot/` entries: `CLAUDE.md`, `KeyPilot.entitlements`, `LICENSE`, `Makefile`, `Info.plist`, `README.md`, `Sources/`, `Resources/`, `Scripts/`, `docs/`, `.gitignore`
