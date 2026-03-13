# Monorepo Conversion Design

**Date:** 2026-03-13
**Status:** Approved
**Approach:** Option A — Rebase message rewrite + new restructuring commit

## Goal

Convert the single-tool `keypilot` repository into a monorepo for multiple small macOS tools built with AI.

## Git History Rewrite

Rewrite the 5 KeyPilot-era commits via interactive rebase to insert `(keypilot)` scope. The "Initial commit" and the `docs: add monorepo conversion design spec` commit are left unchanged (they are repo-level, not tool-specific).

**Before → After:**
```
feat: KeyPilot v1 — keyboard-driven app switcher for macOS
  → feat(keypilot): KeyPilot v1 — keyboard-driven app switcher for macOS

ci: add GitHub Actions release workflow and update README
  → ci(keypilot): add GitHub Actions release workflow and update README

ci: check all commits in push before skipping release
  → ci(keypilot): check all commits in push before skipping release

docs: add permissions, installation, and disclaimer to README
  → docs(keypilot): add permissions, installation, and disclaimer to README

ci: fix release skip logic for multi-line commit messages
  → ci(keypilot): fix release skip logic for multi-line commit messages
```

The rebase range covers exactly these 5 commits (everything from root up to but not including `docs: add monorepo conversion design spec`).

## Directory Structure

All KeyPilot files move into `keypilot/`. The `.claude/` directory stays at the monorepo root (it is repo-wide tooling, not KeyPilot-specific). The `docs/` subtree moves wholesale into `keypilot/docs/` preserving its full subdirectory structure (including `docs/superpowers/plans/` and `docs/superpowers/specs/`).

```
/                          ← monorepo root
├── README.md              ← NEW: monorepo index
├── CLAUDE.md              ← NEW: monorepo-level agent instructions
├── .gitignore             ← stays at root (covers repo-wide patterns)
├── .claude/               ← stays at root (repo-wide tooling)
├── .github/
│   └── workflows/
│       └── keypilot.yml   ← renamed from release.yml; path-filtered
└── keypilot/
    ├── README.md          ← moved from root
    ├── CLAUDE.md          ← moved from root
    ├── Makefile
    ├── Info.plist
    ├── KeyPilot.entitlements
    ├── LICENSE
    ├── .gitignore         ← NEW: keypilot-specific build artifact ignores
    ├── Sources/KeyPilot/
    ├── Resources/
    ├── Scripts/
    └── docs/              ← moved from root, full subtree preserved
        └── superpowers/
            ├── plans/
            └── specs/
```

**Root `.gitignore` changes:** The root `.gitignore` currently contains keypilot-specific build artifact paths (`/KeyPilot`, `/KeyPilot.app/`, etc.). After the move, a new `keypilot/.gitignore` is created with those paths (now relative to `keypilot/`), and the root `.gitignore` keeps only repo-wide patterns (`.DS_Store`, etc.).

## Root README

```markdown
# macOS Tools

Small macOS utilities built with AI.

## Tools

| Tool | Description |
|------|-------------|
| [KeyPilot](keypilot/) | Keyboard-driven app switcher — Right ⌘ + letter to jump to any app |
```

## Root CLAUDE.md

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
```

## CI/CD Pipeline

`release.yml` is renamed to `keypilot.yml`. Changes from the original:

1. **Path filter** — trigger only when changes are under `keypilot/**`:
   ```yaml
   on:
     push:
       branches: [main]
       paths: ['keypilot/**']
   ```

2. **Working directory** — all `run:` steps use `working-directory: keypilot` (build, zip, tag generation). Note: `working-directory` does not apply to `uses:` steps. The `softprops/action-gh-release` action resolves `files:` relative to the workspace root, so the path must be updated to `keypilot/KeyPilot.app.zip`.

3. **Housekeeping-skip regex** — updated to handle optional conventional commit scopes:
   ```
   HOUSEKEEPING='^(docs|chore|style|ci)(\([^)]+\))?:'
   ```
   This matches both `ci:` and `ci(keypilot):` forms.

New tools get their own `<toolname>.yml` with the same pattern, path-filtered to `<toolname>/**`.

## Release tag naming

Tags keep the flat `build-YYYYMMDD-HHMMSS-<sha>` format. This is sufficient for a small number of tools; a `keypilot/build-...` prefix can be adopted later if tag collision becomes an issue.

## Implementation Steps

1. Rewrite the 5 KeyPilot-era commit messages via `git rebase` (amend each)
2. Move all KeyPilot files into `keypilot/` subdirectory
3. Split `.gitignore`: move build-artifact paths to `keypilot/.gitignore`, keep repo-wide patterns at root
4. Create root `README.md`
5. Create root `CLAUDE.md`
6. Rename `.github/workflows/release.yml` → `keypilot.yml`; apply path filter, `working-directory`, and updated housekeeping regex
7. Commit as `chore: restructure repo as monorepo`
