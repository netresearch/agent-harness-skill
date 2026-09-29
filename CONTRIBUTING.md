<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Contributing to agent-harness-skill

The organisation-wide rules apply: [Contributing to Netresearch Projects](https://github.com/netresearch/.github/blob/main/CONTRIBUTING.md) covers commit messages, commit signing, the DCO sign-off and the pull request flow. This file adds what is specific to this repository.

## Setup

You need `bash`, `git`, `python3`, [`shellcheck`](https://www.shellcheck.net/), [`yq`](https://github.com/mikefarah/yq) and [`jq`](https://jqlang.org/). Install the hooks once after cloning:

```bash
pre-commit install
```

The hooks are listed in `.pre-commit-config.yaml`.

## Tests

### Running them locally

From the repository root:

```bash
bash tests/shipped-checkpoints.sh
bash tests/verify-harness-runs.sh
pre-commit run --all-files
```

`pre-commit run --all-files` currently reports markdownlint findings in `docs/plans/` and in five files under `skills/agent-harness/references/`. They predate the hooks; CI's markdown lint checks only the Markdown files in the repository root, so it does not report them.

### Where CI runs them

| Workflow | What it runs |
| --- | --- |
| `.github/workflows/tests.yml` (Skill Tests) | Every `tests/**/*.sh` file, through the `tests.yml` reusable workflow of `netresearch/skill-repo-skill`. A failing file fails the job. |
| `.github/workflows/lint.yml` (Skill Validation) | `validate-skill.sh`, markdownlint, yamllint, actionlint, a JSON syntax check, ShellCheck on every `*.sh` file, and the checkpoint schema check. |
| `.github/workflows/harness-verify.yml` (Harness Verification) | AGENTS.md length, the links in AGENTS.md, the documented commands, documentation drift, and `docs/ARCHITECTURE.md`. |
| `.github/workflows/security.yml` | See [Governance and policies](README.md#governance-and-policies). |

All four run on every pull request to `main`.

### What the tests cover

- `tests/shipped-checkpoints.sh` runs `skills/agent-harness/scripts/run-shipped-checkpoints.sh` against a stub checkpoint runner, without network access. It asserts the exit code and the output for a passing skill, a failing checkpoint of severity `error` (gates) and of severity `warning` (does not gate), a blocked checkpoint, a skill that does not apply, and every broken declaration (missing file, unfetchable repository, entry without `ref`). It also runs `verify-harness.sh` on four fixture repositories and asserts the severity of the `.harness/checkpoints.yml` finding for each combination of declaration and CI job.
- `tests/verify-harness-runs.sh` asserts that `skills/agent-harness/scripts/verify-harness.sh` prints a complete report in a repository with and without an `origin` remote.

The other checks in `verify-harness.sh` (Level 1 and 2, drift, hooks, PR template) have no test of their own.

### Reading a failure

Each case prints one line: `ok <case>` or `FAIL <case>: expected '<value>', got '<value>'`. A file with a failing case exits 1; in CI the job then marks the file with `::error file=<test file>::test failed`. `tests/shipped-checkpoints.sh` prints `SKIP: <tool> not installed` and exits 0 when `git`, `yq` or `jq` is missing. Such a run tested nothing: install the tool and run it again.

### Tests are required for new behaviour

A pull request that adds or changes behaviour of a script under `skills/agent-harness/scripts/` adds or updates a test under `tests/` that runs the script and asserts its exit code and output. A bug fix adds a case that fails without the fix. Passing the existing tests is not enough on its own. A new `tests/<name>.sh` is picked up by the Skill Tests job without further configuration.

Changes that touch only Markdown content (SKILL.md, references, docs) need no test. The reviewer checks this rule; the pull request template has a checklist item for it.

## Governance and security policies

See [Governance and policies](README.md#governance-and-policies) in the README.
