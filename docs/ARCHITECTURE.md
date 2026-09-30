<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Architecture

agent-harness-skill is an agent skill: Markdown instructions, templates and two shell scripts. It has no server, no build step and no runtime state. The design decisions are recorded as ADRs in `skills/agent-harness/references/adr/`.

## Actors

- **Agent** (Claude Code or another skill-aware agent): loads `skills/agent-harness/SKILL.md`, runs the scripts, copies templates into the user's repository.
- **User**: asks the agent to verify, bootstrap or audit a repository, or runs the scripts directly.
- **User's CI**: runs `run-shipped-checkpoints.sh`, and on GitLab and Forgejo also `verify-harness.sh`, through the workflows bootstrapped from the templates; the GitHub `harness-verify.yml` template repeats the checks inline.
- **Maintainers and this repository's CI**: change the skill through pull requests; the workflows in `.github/workflows/` validate and release it.

## Components

| Component | Path | Role |
| --- | --- | --- |
| Skill definition | `skills/agent-harness/SKILL.md` | Entry point for the agent: the verify, bootstrap and audit modes and the template table |
| References | `skills/agent-harness/references/` | Maturity levels, enforcement mechanisms, skill integration map, ADRs; read on demand |
| Checkpoints | `skills/agent-harness/checkpoints.yaml` | Mechanical and LLM checkpoints in the automated-assessment schema |
| Templates | `skills/agent-harness/templates/*.tmpl` | Files the bootstrap mode instantiates in the user's repository |
| Harness verifier | `skills/agent-harness/scripts/verify-harness.sh` | Checks the harness of the repository in the working directory in three levels; output as text, GitHub annotations or GitLab sections |
| Shipped-checkpoint runner | `skills/agent-harness/scripts/run-shipped-checkpoints.sh` | Runs the checkpoints that `.harness/checkpoints.yml` declares, through the automated-assessment runner |
| Tests | `tests/*.sh` | Execute the two scripts and `Build/hooks/pre-commit` against fixture repositories |
| Package manifests | `plugin.json`, `.claude-plugin/plugin.json`, `composer.json`, `package.json` | Distribution through the Claude Code marketplace, Composer and npm |

`Build/Scripts/check-plugin-version.sh` and `Build/hooks/pre-commit` and `Build/hooks/pre-push` are not called by any workflow or hook configuration in this repository; the hooks that run are those in `.pre-commit-config.yaml`. [CONTRIBUTING.md](../CONTRIBUTING.md#scripts-in-build) describes how to install or run them.

## Data flows

1. **Verify.** The agent or CI runs `verify-harness.sh` from the root of the checked repository. The script reads local files and `git` history, optionally asks the GitHub API for an organisation PR template (`check_pr_template`), and writes a report to standard output. Exit code 0 means all checks pass, 1 means errors, 2 means warnings only.
2. **Bootstrap.** The agent copies templates from `skills/agent-harness/templates/` into the user's repository, filling in placeholders such as `{{PROJECT_NAME}}`, and copies `verify-harness.sh` to `scripts/verify-harness.sh`.
3. **Shipped checkpoints.** In the user's CI, `run-shipped-checkpoints.sh` reads `.harness/checkpoints.yml`, clones each declared skill repository at its `ref` and the automated-assessment runner, runs the runner on each declared `checkpoints.yaml`, and turns the JSON result into an exit code: 1 for a failing checkpoint of severity `error`, 2 for a declaration it cannot resolve, 0 otherwise.
4. **Release.** A `v*` tag starts `.github/workflows/release.yml`, which calls the release workflow of `netresearch/skill-repo-skill`.

Security properties and trust boundaries of these flows: [SECURITY-ASSURANCE.md](SECURITY-ASSURANCE.md).
