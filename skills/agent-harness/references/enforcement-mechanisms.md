# Enforcement Mechanisms Reference

This document covers all 10 enforcement instruments available for making repositories agent-ready. Mechanisms are ordered by enforcement strength, from hardest (server-side, nobody bypasses) to softest (convention-based, reminder only).

## Mechanism Summary

| # | Mechanism | Triggers | Affects | Strength |
|---|-----------|----------|---------|----------|
| 1 | Branch Protection / Rulesets | Merge attempt | Everyone | Hard |
| 2 | CI Workflows | PR push | Everyone | Hard |
| 3 | Git Hooks | Commit / push | Local devs | Automatic |
| 4 | .envrc (direnv) | `cd` into repo | Local devs with direnv | Automatic |
| 5 | Composer post-install-cmd | `composer install` | PHP devs | Automatic |
| 6 | npm prepare script | `npm install` | Node devs | Automatic |
| 7 | Makefile / justfile | Manual invocation | Everyone | Soft |
| 8 | AGENTS.md | Agent session start | AI agents | Soft |
| 9 | PR Templates | PR creation | PR authors | Soft |
| 10 | pre-commit framework | Commit (after install) | Local devs | Automatic |

## Detailed Mechanisms

### 1. Branch Protection / Rulesets

**What it is:** GitHub server-side rules that block merging unless required conditions are met.

**When it triggers:** On merge attempt (merge button, API merge call, `gh pr merge`).

**Who it affects:** Everyone -- humans, agents, CI bots. No bypass without admin override.

**Strength:** Hard. Server-side enforcement cannot be circumvented locally.

**Setup:**

- Configure via GitHub UI: Settings > Branches > Branch protection rules, or Settings > Rules > Rulesets.
- Configure via API: `gh api repos/OWNER/REPO/branches/main/protection -X PUT`.
- Configure via `github-project-skill`: delegates branch protection setup.

**Key configuration:** Add `harness-verify` as a required status check. This means the CI workflow from mechanism 2 must pass before any PR can merge.

**Limitations:** Requires repository admin access. Does not provide fast local feedback.

---

### 2. CI Workflows

**What it is:** A GitHub Actions workflow (`.github/workflows/harness-verify.yml`) that runs `verify-harness.sh` on every pull request.

**When it triggers:** On every PR push event. Can also trigger on `push` to specific branches.

**Who it affects:** Everyone. CI runs regardless of contributor setup.

**Strength:** Hard (when combined with branch protection). Automatic (standalone -- visible but not blocking).

**Setup:**

Copy or generate the workflow from `templates/harness-verify.yml.tmpl`:

```yaml
name: Harness Verify
on:
  pull_request:
    branches: [main]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify harness
        run: bash scripts/verify-harness.sh --level=2
```

The workflow uses only `actions/checkout` and bash -- no external action dependencies.

**Reports:** Results appear as GitHub Actions annotations (`::error::`, `::warning::`) visible on the PR Files Changed tab.

**Limitations:** Requires a round-trip to CI. Local feedback is faster via hooks.

---

### 3. Git Hooks

**What it is:** Local scripts in `.githooks/` that run before commits (`pre-commit`) and before pushes (`pre-push`).

**When it triggers:** `pre-commit` runs before every `git commit`. `pre-push` runs before every `git push`.

**Who it affects:** Local developers who have hooks activated. Does not affect CI or web-based edits.

**Strength:** Automatic (once activated). Can be bypassed with `git commit --no-verify`.

**Setup:**

```bash
# Activate hooks for this repo
git config core.hooksPath .githooks

# Or system-wide
git config --global core.hooksPath .githooks
```

Hooks should call `verify-harness.sh`:

```bash
#!/usr/bin/env bash
# .githooks/pre-commit
bash scripts/verify-harness.sh --level=1 --format=text
```

**Limitations:** Requires activation. Bypassable with `--no-verify`. This is why the hard layer (CI + branch protection) exists as a backstop.

---

### 4. .envrc (direnv)

**What it is:** A direnv configuration file that activates automatically when a developer enters the repository directory.

**When it triggers:** On `cd` into the repo directory (if direnv is installed and allowed).

**Who it affects:** Local developers with direnv installed.

**Strength:** Automatic. Silent activation -- no manual step required after initial `direnv allow`.

**Setup:**

```bash
# .envrc
# Activate git hooks
git config core.hooksPath .githooks

# Add project scripts to PATH
PATH_add scripts
PATH_add bin
```

After creating `.envrc`, a developer entering the directory for the first time sees:

```
direnv: error .envrc is blocked. Run `direnv allow` to approve its content
```

After running `direnv allow`, all subsequent directory entries silently activate the configuration.

**Limitations:** Requires direnv installed. First-time `direnv allow` is a manual step. Not available in CI (not needed -- CI has its own workflow).

---

### 5. Composer post-install-cmd

**What it is:** A Composer lifecycle hook that runs after `composer install` or `composer update`.

**When it triggers:** After dependency installation in PHP projects.

**Who it affects:** PHP developers using Composer.

**Strength:** Automatic. Transparent to the developer -- hooks install as a side effect of normal workflow.

**Setup:**

Add to `composer.json`:

```json
{
  "scripts": {
    "post-install-cmd": [
      "git config core.hooksPath .githooks || true"
    ],
    "post-update-cmd": [
      "git config core.hooksPath .githooks || true"
    ]
  }
}
```

The `|| true` ensures the script does not fail in environments without git (CI Docker containers, production deploys).

**Limitations:** PHP/Composer projects only. Does not work for contributors who skip `composer install`.

---

### 6. npm prepare Script

**What it is:** An npm lifecycle script that runs after `npm install`.

**When it triggers:** After dependency installation in Node projects.

**Who it affects:** Node developers using npm/yarn/pnpm.

**Strength:** Automatic. Transparent to the developer.

**Setup (direct):**

```json
{
  "scripts": {
    "prepare": "git config core.hooksPath .githooks || true"
  }
}
```

**Setup (with Husky):**

```json
{
  "scripts": {
    "prepare": "husky"
  }
}
```

Then configure Husky hooks to call `verify-harness.sh`.

**Limitations:** Node projects only. Does not work if `--ignore-scripts` is used.

---

### 7. Makefile / justfile

**What it is:** A build automation target that runs harness verification on demand.

**When it triggers:** Manual invocation (`make verify-harness` or `just verify-harness`).

**Who it affects:** Everyone who can run make/just. Language-agnostic.

**Strength:** Soft. Requires the contributor to know about and choose to run it.

**Setup:**

```makefile
.PHONY: verify-harness
verify-harness:
	bash scripts/verify-harness.sh --format=text

.PHONY: bootstrap-harness
bootstrap-harness:
	@echo "Run agent-harness:bootstrap via your agent framework"

.PHONY: harness-status
harness-status:
	bash scripts/verify-harness.sh --format=text --level=3 || true
```

**Advantages:** Works in any project regardless of language or package manager. Discoverable via `make help` or reading the Makefile. Can be called by CI workflows.

**Limitations:** Requires manual invocation. Not enforced.

---

### 8. AGENTS.md

**What it is:** A markdown file at the repo root read by AI agents at the start of every session.

**When it triggers:** Agent session start. Claude Code, OpenAI Codex, GitHub Copilot, Gemini CLI, and other agents look for this file automatically.

**Who it affects:** AI agents. Humans can read it but it is optimised for agent consumption.

**Strength:** Soft. Convention-based. The agent reads it but is not mechanically forced to comply.

**Setup:**

Create `AGENTS.md` at the repo root following the index format (see ADR-004). Keep it under 150 lines. Reference detailed documentation in `docs/` rather than inlining it.

```markdown
# AGENTS.md

## Repo Structure
- `src/` -- application source
- `docs/` -- documentation (ARCHITECTURE.md, ADRs, design docs)
- `scripts/` -- automation scripts

## Commands
- `make build` -- build the project
- `make test` -- run all tests
- `make verify-harness` -- verify harness consistency

## Rules
- Follow conventional commits
- All new subsystems must be documented in ARCHITECTURE.md
```

**Limitations:** No mechanical enforcement. An agent can ignore instructions. This is why CI and hooks exist as harder layers.

---

### 9. PR Templates

**What it is:** A GitHub pull request template (`.github/pull_request_template.md`) that pre-fills the PR description with a checklist.

**When it triggers:** PR creation via GitHub UI or `gh pr create`.

**Who it affects:** PR authors. Visible reminder during PR creation.

**Strength:** Soft. Reminder only -- unchecked items do not block merge.

**Setup:**

Create `.github/pull_request_template.md`:

```markdown
## Changes

<!-- Describe your changes -->

## Harness Checklist

- [ ] AGENTS.md updated (if commands or structure changed)
- [ ] docs/ updated (if architecture or design changed)
- [ ] New subsystems documented in ARCHITECTURE.md
- [ ] Exec plan created (if multi-file structural change)
```

**Limitations:** Reminder, not enforcement. Contributors can delete the template text. No merge blocking.

---

### 10. pre-commit Framework

**What it is:** A multi-language hook manager that standardises git hook setup via `.pre-commit-config.yaml`.

**When it triggers:** On commit (after `pre-commit install` has been run).

**Who it affects:** Local developers who have run `pre-commit install`.

**Strength:** Automatic (once installed). Bypassable with `--no-verify`.

**Setup:**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: verify-harness
        name: Verify harness consistency
        entry: bash scripts/verify-harness.sh --level=1 --format=text
        language: system
        pass_filenames: false
        always_run: true
```

Then: `pre-commit install`

**Advantages:** Standardised hook management. Easy to add additional hooks (linting, formatting). Supports auto-update of hook versions.

**Limitations:** Requires `pre-commit` installed (`pip install pre-commit`). Requires `pre-commit install` to be run once. Bypassable with `--no-verify`.

## The Activation Chain

This diagram shows how enforcement mechanisms activate in sequence during a typical development workflow:

```
Developer clones repo
  |
  +---> .envrc detected by direnv
  |       +---> git config core.hooksPath .githooks
  |       +---> scripts/ added to PATH
  |
  +---> composer install / npm install
  |       +---> post-install-cmd / prepare script
  |       +---> git hooks confirmed active
  |
  +---> Developer makes changes, runs git commit
  |       +---> .githooks/pre-commit runs
  |       +---> verify-harness.sh --level=1 (fast check)
  |       +---> Commit succeeds or fails with feedback
  |
  +---> Developer runs git push
  |       +---> .githooks/pre-push runs
  |       +---> verify-harness.sh --level=2 (full check)
  |       +---> Push succeeds or fails with feedback
  |
  +---> PR created on GitHub
  |       +---> PR template pre-fills harness checklist
  |       +---> CI workflow triggers (harness-verify.yml)
  |       +---> verify-harness.sh runs in CI
  |       +---> Results reported as annotations
  |
  +---> Merge attempted
          +---> Branch protection checks required status
          +---> harness-verify must be green
          +---> Merge succeeds or is blocked
```

Each layer catches issues that earlier layers missed or that bypassed them. The chain is designed so that the last layer (branch protection) is impossible to bypass without admin access.

## Choosing Mechanisms for Your Project

### Minimum (any project)

- AGENTS.md (mechanism 8)
- CI workflow (mechanism 2)
- Makefile target (mechanism 7)

This is the Level 1 baseline. Works for any language, any team size.

### PHP project

All of the minimum, plus:

- Composer post-install-cmd (mechanism 5)
- .envrc (mechanism 4)
- Git hooks (mechanism 3)

### Node project

All of the minimum, plus:

- npm prepare script (mechanism 6)
- Husky or direct hooks (mechanism 3)
- .envrc (mechanism 4)

### Go project

All of the minimum, plus:

- .envrc (mechanism 4)
- Makefile targets (mechanism 7 -- Go projects already use Make heavily)
- Git hooks (mechanism 3)

### Maximum (Level 3)

All mechanisms active:

- Branch protection with `harness-verify` as required check (mechanism 1)
- CI workflow (mechanism 2)
- Git hooks via .githooks/ (mechanism 3)
- .envrc for automatic activation (mechanism 4)
- Language-specific auto-setup (mechanism 5 or 6)
- Makefile targets (mechanism 7)
- AGENTS.md as index (mechanism 8)
- PR template with harness checklist (mechanism 9)
- pre-commit framework (mechanism 10, optional -- overlaps with direct hooks)
