# ADR-002: Enforcement Layers

**Status:** Accepted
**Date:** 2026-03-22
**Context:** We evaluated 10 enforcement mechanisms for making repos agent-ready: CI workflows, Branch Protection/Rulesets, Git Hooks, .envrc (direnv), Composer plugins/scripts, npm scripts, pre-commit framework, Makefile/justfile, AGENTS.md, PR Templates. The question was which to use and how to layer them.
**Decision:** Three-layer enforcement model ordered by strength: hard (server-side), automatic (local), and soft (convention-based).
**Consequences:** The skill must produce artefacts for all three layers. No single mechanism is sufficient alone.

## The Three Layers

### 1. Hard Layer (server-side, nobody bypasses)

- **CI workflows** (`.github/workflows/harness-verify.yml`) -- runs on every PR, fails the build if harness artefacts are missing or inconsistent.
- **Branch Protection / Rulesets** -- `harness-verify` configured as a required status check, blocking merge on failure.

This layer is the backstop. It works regardless of contributor setup, editor, operating system, or whether they have the skill installed. If the CI check fails, the PR cannot merge.

### 2. Automatic Layer (activates on clone/install, local)

- **`.envrc` (direnv)** -- auto-sets `core.hooksPath` to `.githooks/` when a developer enters the repo directory.
- **`composer post-install-cmd` / `npm prepare`** -- installs git hooks automatically when dependencies are installed.
- **Git hooks (`.githooks/`)** -- pre-commit checks run verification before each commit; pre-push runs full verification before push.

This layer provides fast feedback during development. Developers catch issues before pushing, reducing CI round-trip time. It activates without manual setup for anyone using direnv or the project's package manager.

### 3. Soft Layer (convention-based, visible)

- **`AGENTS.md`** -- every agent reads this at session start; it points to harness documentation and verification commands.
- **PR Templates** -- GitHub shows a checklist to PR creators, reminding them to run verification.
- **`Makefile` targets** -- `make verify-harness` provides a discoverable entry point for manual checks.

This layer guides behaviour through conventions and visibility. It works for contributors who may not have direnv or the project's package manager but can read instructions.

## Rationale

- The hard layer ensures no unverified code merges, regardless of the contributor's local setup.
- The automatic layer gives fast feedback during development without manual configuration.
- The soft layer guides behaviour through conventions and visibility.
- The combination works for all four contributor types: humans with skills, humans without skills, AI agents with skills, AI agents without skills.
- Each layer is optional -- a repo at Level 1 (see ADR-005) may only have soft enforcement, while Level 3 has all three.

## Trade-offs and Limitations

- `.envrc` requires direnv -- documented as recommended, not required.
- Composer/npm hooks only work for projects using those ecosystems. For other ecosystems, `.envrc` or manual `git config core.hooksPath .githooks/` is the fallback.
- The hard layer requires repository admin access to configure branch protection.
- Git hooks can be bypassed with `--no-verify` locally, which is why the hard layer exists as backstop.
