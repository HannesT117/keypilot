# Monorepo Conversion Design

**Date:** 2026-03-13
**Status:** Approved
**Approach:** Option A — Rebase message rewrite + new restructuring commit

## Goal

Convert the single-tool `keypilot` repository into a monorepo for multiple small macOS tools built with AI.

## Git History Rewrite

Rewrite the 5 non-initial commits via interactive rebase to insert `(keypilot)` scope into existing conventional commit messages. The "Initial commit" is left unchanged.

**Before → After:**
```
ci: fix release skip logic for multi-line commit messages
  → ci(keypilot): fix release skip logic for multi-line commit messages

docs: add permissions, installation, and disclaimer to README
  → docs(keypilot): add permissions, installation, and disclaimer to README

ci: check all commits in push before skipping release
  → ci(keypilot): check all commits in push before skipping release

ci: add GitHub Actions release workflow and update README
  → ci(keypilot): add GitHub Actions release workflow and update README

feat: KeyPilot v1 — keyboard-driven app switcher for macOS
  → feat(keypilot): KeyPilot v1 — keyboard-driven app switcher for macOS
```

## Directory Structure

```
/                          ← monorepo root
├── README.md              ← NEW: monorepo index
├── CLAUDE.md              ← NEW: minimal, describes monorepo structure
├── .github/
│   └── workflows/
│       └── keypilot.yml   ← renamed from release.yml
└── keypilot/
    ├── README.md          ← moved from root
    ├── CLAUDE.md          ← moved from root
    ├── Makefile
    ├── Info.plist
    ├── KeyPilot.entitlements
    ├── LICENSE
    ├── Sources/KeyPilot/
    ├── Resources/
    ├── Scripts/
    └── docs/              ← moved from root (contains superpowers plans)
```

## Root README

Minimal monorepo index describing purpose and listing tools:

```markdown
# macOS Tools

Small macOS utilities built with AI.

## Tools

| Tool | Description |
|------|-------------|
| [KeyPilot](keypilot/) | Keyboard-driven app switcher — Right ⌘ + letter to jump to any app |
```

## CI/CD Pipeline

`release.yml` is renamed to `keypilot.yml`. Two changes from the original:

1. **Path filter** — only triggers on pushes that include changes under `keypilot/**`
2. **Working directory** — all build steps run with `working-directory: keypilot`

The housekeeping-commit skip logic is preserved unchanged.

New tools get their own `<toolname>.yml` workflow file with the same pattern.

## Implementation Steps

1. Rewrite commit messages via `git rebase` (amend each of the 5 commits)
2. Move all KeyPilot files into `keypilot/` subdirectory
3. Create root `README.md`
4. Create root `CLAUDE.md` describing monorepo layout
5. Rename `.github/workflows/release.yml` → `keypilot.yml` with path filter and working-directory
6. Commit as `chore(keypilot): restructure repo as monorepo`
