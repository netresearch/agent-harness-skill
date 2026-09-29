<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case — agent-harness-skill

This document states what a user can expect from this repository in terms of security, and argues why that expectation holds. Every claim names the file that implements it. Reporting a vulnerability: see the [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md).

## What the repository ships

| Part | Files | Runs where |
| --- | --- | --- |
| Skill content: instructions and references for an AI agent | `skills/agent-harness/SKILL.md`, `skills/agent-harness/references/**/*.md` | Read by the agent as instructions; not executed |
| Checkpoints | `skills/agent-harness/checkpoints.yaml` | Commands run by the automated-assessment runner against a repository, when a user or CI asks for it |
| Templates | `skills/agent-harness/templates/*.tmpl` | Copied by the agent into the user's repository (CI workflows, PR templates, `.envrc`, Makefile targets) |
| Harness verifier | `skills/agent-harness/scripts/verify-harness.sh` | On the user's machine or in the user's CI, from the root of the repository it checks; bootstrap copies it to `scripts/verify-harness.sh` |
| Shipped-checkpoint runner | `skills/agent-harness/scripts/run-shipped-checkpoints.sh` | In the user's CI (job from `templates/harness-checkpoints.yml.tmpl` and its GitLab and Forgejo variants) |
| Repository checks | `tests/*.sh`, `.pre-commit-config.yaml` | In this repository's CI and on contributors' machines |
| Unwired scripts | `Build/Scripts/check-plugin-version.sh`, `Build/hooks/*` | Not called by any workflow or hook configuration (see [ARCHITECTURE.md](ARCHITECTURE.md)) |

The skill has no server component, stores no data, and handles no user accounts or credentials of its own.

## Security requirements

1. `verify-harness.sh` reads the checked repository's files as data. It does not execute them, source them or fetch anything they reference.
2. `run-shipped-checkpoints.sh` fetches only the checkpoint runner and the repositories that the repository's own `.harness/checkpoints.yml` names, and fails the job instead of passing when a declared entry cannot be fetched or resolved.
3. The workflows of this repository run with no token permission unless a job names it.
4. Nothing committed to the repository contains a secret.
5. The required checks of a pull request fail when it adds a Composer dependency with a known vulnerability or introduces a static-analysis finding of severity WARNING or higher.

## Actors and trust boundaries

- **Skill user and agent.** The agent reads the Markdown files as instructions and copies the templates into the user's repository. Text in this repository is therefore trusted input to the agent; changes to it go through pull request review like code (see [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md)).
- **Checked repository.** `verify-harness.sh` runs in the working directory and reads `AGENTS.md`, `Makefile`, `composer.json`, `package.json`, `.gitlab-ci.yml`, `.envrc` and the workflow directories with `grep`, `awk` and `wc`, and asks `git` for the last commit's changed files (`check_drift`). Paths taken from `AGENTS.md` links are only tested for existence (`check_refs`).
- **GitHub API.** When the checked repository has no PR template of its own and its `origin` remote is on github.com, `check_pr_template` in `verify-harness.sh` calls `gh api repos/<org>/.github/contents/pull_request_template.md` with whatever `gh` credentials the user has. It only reads the file name from the answer.
- **Declared skills and the checkpoint runner (remote code).** `run-shipped-checkpoints.sh` clones each repository named in `.harness/checkpoints.yml` at the declared `ref`, and clones the checkpoint runner from `HARNESS_RUNNER_REPO` at `HARNESS_RUNNER_REF` (default: `netresearch/automated-assessment-skill` at `main`). It then runs the runner with `bash`, and the runner executes the commands in the declared `checkpoints.yaml`. Everything behind this boundary runs with the permissions of the CI job. The declaration is therefore trusted like code: whoever can change it chooses what runs. The script checks that `repo`, `ref` and `path` are present; it does not restrict their values.
- **CI.** Workflows run on GitHub-hosted runners with `permissions: {}` at the top level and the minimum job permissions each reusable workflow needs (`.github/workflows/*.yml`). The three `pull_request_target` workflows (`auto-merge-deps.yml`, `labeler.yml`, `pr-quality.yml`) have no steps of their own; each calls one reusable workflow, and their comments state that it neither checks out nor runs the pull request's code.

## Threats and countermeasures

| Threat | Countermeasure | Evidence |
| --- | --- | --- |
| A crafted `AGENTS.md` or build file makes the verifier execute code (CWE-78, CWE-94) | The verifier never passes file content to `eval`, `source` or a shell; values extracted from `AGENTS.md` for pattern matching are limited to `[a-zA-Z0-9_-]` (make targets) or `[a-zA-Z0-9:_-]` (composer and npm scripts) | `verify-harness.sh` (`check_commands`, `check_refs`) |
| The verifier aborts silently and a broken harness reads as a pass | The script runs under `set -euo pipefail`; commands that may fail are guarded, and the exit code distinguishes errors (1) from warnings only (2) | `verify-harness.sh` (`main`); `tests/verify-harness-runs.sh` asserts a complete report with and without an `origin` remote |
| A declared check silently does not run and a repository reads as checked | An unfetchable repository, a missing `checkpoints.yaml`, an entry without `repo`, `ref` or `path`, and a runner without output each exit 2; a failing checkpoint of severity `error` exits 1 | `run-shipped-checkpoints.sh`; `tests/shipped-checkpoints.sh` asserts the missing-file, unfetchable-repository and missing-`ref` cases and both severities |
| A declaration exists but no CI job runs it, or the reverse | `verify-harness.sh` reports both as errors | `verify-harness.sh` (`check_shipped_checkpoints`); `tests/shipped-checkpoints.sh` asserts the severity for all four combinations |
| A declared skill changes under a repository without a commit there | Each declaration entry requires a `ref`; the script clones exactly that ref | `run-shipped-checkpoints.sh` (entry check, `fetch_repo`) |
| Temporary clones are left behind | Clones go to a `mktemp -d` directory removed by an `EXIT` trap | `run-shipped-checkpoints.sh` |
| Shell defects in the scripts | ShellCheck runs in CI on every `*.sh` file at severity `error`, and in the pre-commit hook on every shell script at its default severity `style`; all seven shell files in this repository pass `shellcheck -x -S style` with no finding | `.github/workflows/lint.yml`, `.pre-commit-config.yaml` |
| A secret is committed | Betterleaks scans every push to `main` and every pull request to `main` | `.github/workflows/security.yml` |
| A vulnerable or malicious dependency is added | Dependency review fails on high or critical vulnerabilities in a pull request; Composer Audit fails on known advisories; Renovate proposes updates | `.github/workflows/security.yml`, `renovate.json` |
| Insecure code or workflow patterns | Opengrep fails a pull request on findings of severity WARNING or higher; zizmor and CodeQL analyse the workflows | `.github/workflows/security.yml`; CodeQL runs as GitHub default setup, a repository setting described in `.github/template.yaml` |
| A workflow token is misused | Top-level `permissions: {}`; each job grants only what its reusable workflow needs | `.github/workflows/*.yml` |

## Secure design principles applied

- **Least privilege:** workflows declare `permissions: {}` and grant each job only what its reusable workflow needs (`.github/workflows/*.yml`).
- **Fail closed:** `run-shipped-checkpoints.sh` exits 2 on every declaration it cannot resolve instead of skipping it.
- **Minimal attack surface:** the skill is mostly static content; the two scripts run only on explicit invocation, and `verify-harness.sh` needs no network access unless the PR-template fallback applies.
- **Data, not code:** `verify-harness.sh` treats every file it checks as text to match against.

## What a user cannot expect

- `run-shipped-checkpoints.sh` is not a sandbox. It executes the checkpoint runner and the commands of every declared `checkpoints.yaml` with the CI job's permissions.
- The checkpoint runner is not pinned by default: `HARNESS_RUNNER_REF` defaults to the `main` branch of `netresearch/automated-assessment-skill`, although the comment above that line in `run-shipped-checkpoints.sh` calls it pinned. The CI job templates (`templates/*harness-checkpoints.yml.tmpl`) set `HARNESS_RUNNER_REF` from the `{{ASSESSMENT_SKILL_REF}}` placeholder; a direct call without it uses `main`.
- The declaration has to be reviewed like the CI configuration it drives: its values decide what is fetched and run, and the script does not restrict them.
- The reusable workflows this repository calls are referenced by branch (`@main`), not by commit (`.github/workflows/*.yml`).
- The verifier checks the structure and consistency of an agent harness. It is not a security scanner for the checked repository.
