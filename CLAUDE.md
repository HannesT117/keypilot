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
