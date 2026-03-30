# Harness Maturity Levels

The harness maturity model defines three levels of agent-readiness for a repository. Each level builds on the previous one, adding stronger enforcement and more comprehensive verification. Levels are measured mechanically via checkpoints -- there is no subjective assessment.

## Level Overview

| Level | Name | Target | Effort (manual) | Effort (with skill) |
|-------|------|--------|-----------------|---------------------|
| 1 | Basic | Any repo, solo dev, minimal effort | ~15 minutes | ~2 minutes |
| 2 | Verified | Team repos, CI-backed, actively maintained | ~30 minutes | ~5 minutes |
| 3 | Enforced | Production repos, full enforcement, drift-resistant | ~1 hour | ~10 minutes |

## Level 1 -- Basic

**Target audience:** Any repository, solo developer or small team, minimal effort to adopt.

### Requirements

| Checkpoint | Check | Severity |
|------------|-------|----------|
| AH-01 | `AGENTS.md` exists at repo root | Error |
| AH-02 | `AGENTS.md` is index-format (under 150 lines) | Warning |
| AH-03 | `AGENTS.md` documents available commands (build, test, lint) | Warning |
| -- | `docs/` directory exists (even if minimal) | Warning |

### What it gives you

- **Any AI agent can understand your repo.** Claude Code, OpenAI Codex, GitHub Copilot, and Gemini CLI all read `AGENTS.md` at session start. A compact, well-structured AGENTS.md means every agent interaction starts with correct context.
- **Contributors know what commands to run.** New team members (human or AI) can find build, test, and lint commands without reading source code.
- **Baseline for gradual improvement.** Level 1 is the foundation. Everything at Level 2 and 3 builds on these artefacts.

### What it does not give you

- No mechanical verification that docs are accurate.
- No CI enforcement.
- No protection against documentation drift.

### How to set up

**Manual:**

1. Create `AGENTS.md` at the repo root. Use the index format -- keep it under 150 lines. Include sections for repo structure, commands, and rules.
2. Create a `docs/` directory. Add at least a placeholder file.
3. Document your build, test, and lint commands in AGENTS.md.

**With skill bootstrap:**

```
agent-harness:bootstrap --level=1
```

The skill analyses the repo, detects available commands from Makefile/composer.json/package.json, and generates `AGENTS.md` from the template.

### Verification

```bash
bash scripts/verify-harness.sh --level=1 --format=text
```

Example output:

```
[PASS] AH-01: AGENTS.md exists
[PASS] AH-02: AGENTS.md is 87 lines (under 150)
[PASS] AH-03: AGENTS.md contains commands section
[PASS] docs/ directory exists

Level 1: PASS (4/4 checks passed)
```

---

## Level 2 -- Verified

**Target audience:** Team repositories with CI, actively maintained, multiple contributors.

### Requirements

All of Level 1, plus:

| Checkpoint | Check | Severity |
| ---------- | ----- | -------- |
| AH-10 | All references in `AGENTS.md` resolve to existing files | Error |
| -- | Documented commands match actual Makefile/composer/npm targets | Warning |
| AH-11 | `docs/ARCHITECTURE.md` exists with system overview | Warning |
| AH-12 | CI workflow runs harness verification on every PR/MR | Warning |

### What it gives you

- **Mechanical guarantee that docs are not lying.** Every file path referenced in AGENTS.md is verified to exist. Every command documented in AGENTS.md is verified to match an actual build target. If someone renames a file or removes a Makefile target, verification catches it.
- **Architecture is documented for onboarding.** New contributors (human or AI) can read ARCHITECTURE.md to understand the system before modifying it. This is the "Inform" function from harness engineering.
- **CI catches harness drift automatically.** The harness verification workflow runs on every PR. If a PR changes the Makefile but does not update AGENTS.md, the CI check warns about it.

### What it does not give you

- CI results are advisory, not blocking (unless branch protection is configured).
- No automatic hook setup -- contributors must manually activate hooks.
- No drift detection for structural file changes.

### How to set up

**Manual:**

1. Complete all Level 1 requirements.
2. Audit every file reference in AGENTS.md. Fix or remove any that point to non-existent files.
3. Audit every command in AGENTS.md. Ensure each one matches an actual Makefile target, composer script, or npm script.
4. Create `docs/ARCHITECTURE.md`. Include at minimum: system overview (1 paragraph), component map, and dependency rules.
5. Create `.github/workflows/harness-verify.yml` using the template. This workflow runs `verify-harness.sh` on every PR.
6. **GitLab alternative:** If using GitLab, add a `harness-verify` job to `.gitlab-ci.yml` using the template. This job runs `verify-harness.sh` on every merge request.

**With skill bootstrap:**

```
agent-harness:bootstrap --level=2
```

The skill creates ARCHITECTURE.md from the template, generates the CI workflow, and fixes any broken references it can detect.

### Verification

```bash
bash scripts/verify-harness.sh --level=2 --format=text
```

Example output:

```
[PASS] AH-01: AGENTS.md exists
[PASS] AH-02: AGENTS.md is 87 lines (under 150)
[PASS] AH-03: AGENTS.md contains commands section
[PASS] AH-04: docs/ directory exists
[PASS] AH-10: All 12 references in AGENTS.md resolve
[PASS] AH-11: docs/ARCHITECTURE.md exists
[PASS] AH-12: CI harness workflow exists

Level 2: PASS (7/7 checks passed)
```

---

## Level 3 -- Enforced

**Target audience:** Production repositories, full enforcement, drift-resistant. Repos where harness consistency is a hard requirement.

### Requirements

All of Level 2, plus:

| Checkpoint | Check | Severity |
|------------|-------|----------|
| AH-20 | PR template includes harness checklist | Warning |
| AH-21 | Git hooks auto-activate on clone (via .envrc, composer, or npm) | Warning |
| AH-22 | Drift detection: structural file changes trigger warnings if AGENTS.md is not also updated | Warning |

### What it gives you

- **No unverified code merges.** `harness-verify` is a required status check in branch protection. If the harness is inconsistent, the PR cannot merge. This works for all contributors -- human or AI, with or without skills installed.
- **New contributors get fast feedback immediately.** Git hooks auto-activate on clone via `.envrc` (direnv), `composer post-install-cmd`, or `npm prepare`. No manual setup required. The first commit attempt runs verification.
- **Structural changes cannot silently break documentation.** Drift detection monitors changes to structural files (Makefile, composer.json, package.json, CI workflows). If these files change in a PR but AGENTS.md is not also updated, the verification emits a warning.
- **Full enforcement works for everyone.** The enforcement is project-level (CI workflows, branch protection, git hooks), not tool-level. It works whether the contributor uses Claude Code, VS Code, vim, or the GitHub web editor.

### What it does not give you

- Runtime agent observability (tracing, evals).
- Automatic AGENTS.md updates (the skill detects drift but does not auto-fix).
- Cross-repo consistency (each repo is verified independently).

### How to set up

**Manual:**

1. Complete all Level 2 requirements.
2. Configure branch protection: on GitHub, add `harness-verify` as a required status check on the default branch. On GitLab, enable 'Pipelines must succeed' under Settings > Merge requests.
3. Set up hook auto-activation using one or more of:
   - `.envrc` with `git config core.hooksPath .githooks` (for direnv users).
   - `composer.json` `post-install-cmd` (for PHP projects).
   - `package.json` `prepare` script (for Node projects).
4. Create the PR/MR template. For GitHub: copy to `.github/pull_request_template.md`. For GitLab: copy to `.gitlab/merge_request_templates/Default.md`.
5. Ensure `.githooks/pre-commit` and `.githooks/pre-push` exist and are executable.

**With skill bootstrap:**

```
agent-harness:bootstrap --level=3
```

The skill creates all missing artefacts and delegates branch protection setup to github-project-skill.

### Verification

```bash
bash scripts/verify-harness.sh --level=3 --format=text
```

Example output:

```
[PASS] AH-01: AGENTS.md exists
[PASS] AH-02: AGENTS.md is 92 lines (under 150)
[PASS] AH-03: AGENTS.md contains commands section
[PASS] AH-04: docs/ directory exists
[PASS] AH-10: All 15 references in AGENTS.md resolve
[PASS] AH-11: docs/ARCHITECTURE.md exists
[PASS] AH-12: CI harness workflow exists
[PASS] AH-20: PR/MR template with harness checklist exists
[PASS] AH-21: Git hooks auto-activate (.envrc configures hooksPath)
[PASS] No drift detected

Level 3: PASS (10/10 checks passed)
```

---

## Upgrade Paths

### Level 1 to Level 2

1. **Add the CI workflow.** Copy `templates/harness-verify.yml.tmpl` to `.github/workflows/harness-verify.yml`. Adjust the level flag to `--level=2`.
2. **Create ARCHITECTURE.md.** Use `templates/ARCHITECTURE.md.tmpl` as a starting point. Document the system overview, component map, and dependency rules.
3. **Fix dead references.** Run `verify-harness.sh --level=2` and fix any file paths in AGENTS.md that do not resolve.
4. **Align commands.** Ensure every command listed in AGENTS.md has a matching Makefile target, composer script, or npm script.

### Level 2 to Level 3

1. **Configure branch protection.** Add `harness-verify` as a required status check. This is the single most impactful change -- it turns advisory CI into blocking enforcement.
2. **Add hook auto-setup.** Choose the mechanism appropriate for your project:
   - PHP: add `post-install-cmd` to `composer.json`.
   - Node: add `prepare` script to `package.json`.
   - Any: create `.envrc` with hook configuration.
3. **Create the PR template.** Copy `templates/pull_request_template.md.tmpl` to `.github/pull_request_template.md`.
4. **Create git hooks.** Add `.githooks/pre-commit` and `.githooks/pre-push` that call `verify-harness.sh`.

## Measuring Maturity

### Command-line usage

```bash
# Check current maturity level (runs all checks, reports highest passing level)
bash scripts/verify-harness.sh --format=text

# Check a specific level
bash scripts/verify-harness.sh --level=2 --format=text

# Use in CI (exits non-zero on failure)
bash scripts/verify-harness.sh --level=2

# Run a single check category
bash scripts/verify-harness.sh --check=refs --format=text
```

### CI usage

```yaml
# .github/workflows/harness-verify.yml
- name: Verify harness (Level 2)
  run: bash scripts/verify-harness.sh --level=2
```

The default output format uses GitHub Actions annotation syntax (`::error::`, `::warning::`), which makes results visible directly on the PR Files Changed tab.

```yaml
# .gitlab-ci.yml
harness-verify:
  stage: test
  script: bash scripts/verify-harness.sh --level=2 --format=gitlab
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

The GitLab format uses structured log output. Enable "Pipelines must succeed" in GitLab merge request settings to make it a hard gate.

### Automated assessment usage

The `checkpoints.yaml` file integrates with automated-assessment-skill for batch auditing across multiple repositories:

```bash
# Audit a single repo
automated-assessment:audit --skill=agent-harness --target=/path/to/repo

# Audit all repos in an organisation
automated-assessment:audit --skill=agent-harness --org=netresearch
```

## Checkpoint Reference

| ID | Level | Check | Severity | Type |
| ---- | ----- | ----- | -------- | ---- |
| AH-01 | 1 | AGENTS.md exists | Error | file_exists |
| AH-02 | 1 | AGENTS.md under 150 lines | Warning | command |
| AH-03 | 1 | AGENTS.md has commands section | Warning | regex |
| AH-04 | 1 | docs/ directory exists | Warning | command |
| AH-10 | 2 | No dead references in AGENTS.md | Error | command |
| AH-11 | 2 | docs/ARCHITECTURE.md exists | Warning | file_exists |
| AH-12 | 2 | CI harness verification workflow exists (GitHub Actions or GitLab CI) | Warning | command |
| AH-20 | 3 | PR/MR template with harness checklist | Warning | command |
| AH-21 | 3 | Git hooks auto-activate | Warning | command |
