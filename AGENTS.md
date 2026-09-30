<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Agent Harness Skill

Agent skill for bootstrapping, verifying, and enforcing agent-harness infrastructure in repositories.

## Structure

- [skills/agent-harness/SKILL.md](skills/agent-harness/SKILL.md) — Main skill definition (verify, bootstrap, audit modes)
- [skills/agent-harness/checkpoints.yaml](skills/agent-harness/checkpoints.yaml) — Mechanical and LLM checkpoints
- [skills/agent-harness/scripts/verify-harness.sh](skills/agent-harness/scripts/verify-harness.sh) — Standalone verification script
- [skills/agent-harness/scripts/run-shipped-checkpoints.sh](skills/agent-harness/scripts/run-shipped-checkpoints.sh) — Runs the checkpoints declared in `.harness/checkpoints.yml`
- [skills/agent-harness/references/](skills/agent-harness/references/) — Maturity levels, skill integration map, enforcement mechanisms, ADRs
- [skills/agent-harness/templates/](skills/agent-harness/templates/) — Files the bootstrap mode copies into a repository
- [tests/](tests/) — Tests that execute the two scripts and `Build/hooks/pre-commit`
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture overview
- [docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md) — Security assurance case
- [CONTRIBUTING.md](CONTRIBUTING.md) — Setup, tests, test policy

## Commands

There is no Makefile. Run from the repository root:

- `pre-commit run --all-files` — Hooks from `.pre-commit-config.yaml`: YAML, Markdown and ShellCheck linting, skill validation, version parity
- `bash tests/shipped-checkpoints.sh`, `bash tests/verify-harness-runs.sh` and `bash tests/build-pre-commit-hook.sh` — Test suite (CI: `.github/workflows/tests.yml`)
- `bash skills/agent-harness/scripts/verify-harness.sh` — Run the verification script against this repository

## Rules

- AGENTS.md must be a compact index (<150 lines)
- All file references in AGENTS.md must resolve
- Checkpoints use the schema from `references/checkpoints-schema.md` in [automated-assessment-skill](https://github.com/netresearch/automated-assessment-skill/blob/main/skills/automated-assessment/references/checkpoints-schema.md)
- Quality delegation: harness verifies output of specialist skills, not the tools
