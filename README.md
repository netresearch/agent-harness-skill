<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Agent Harness Skill

[![Lint](https://github.com/netresearch/agent-harness-skill/actions/workflows/lint.yml/badge.svg)](https://github.com/netresearch/agent-harness-skill/actions/workflows/lint.yml)
[![Harness Verification](https://github.com/netresearch/agent-harness-skill/actions/workflows/harness-verify.yml/badge.svg)](https://github.com/netresearch/agent-harness-skill/actions/workflows/harness-verify.yml)
[![Security](https://github.com/netresearch/agent-harness-skill/actions/workflows/security.yml/badge.svg)](https://github.com/netresearch/agent-harness-skill/actions/workflows/security.yml)

Agent Skill for bootstrapping, verifying, and enforcing agent-harness infrastructure in repositories. Makes repos agent-ready with self-sustaining enforcement mechanisms that work for all contributors -- human or AI, with or without skills installed.

## What is Agent Harness?

Agent harness is repo-level infrastructure that makes AI coding agents reliable. Instead of relying on individual skill installations, the harness embeds enforcement directly into the project via CI workflows, git hooks, and conventions.

The skill follows the "verify-first" principle: it primarily checks consistency, secondarily creates missing artefacts, and delegates specialised work to existing skills.

**Key concepts:**

- AGENTS.md as compact index (<150 lines), not encyclopedia
- Three enforcement layers: hard (CI/branch protection), automatic (.envrc/hooks), soft (conventions)
- Three maturity levels: Basic, Verified, Enforced
- The skill is the installer; the harness enforces itself

## Installation

### Claude Code Marketplace

```bash
/plugin marketplace add netresearch/claude-code-marketplace
/plugin install agent-harness@netresearch-claude-code-marketplace
```

### Without a marketplace

Since Claude Code 2.1.157 a plugin directory under your personal skills directory loads on its own:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/netresearch/agent-harness-skill.git \
  ~/.claude/skills/agent-harness
```

It loads as `agent-harness@skills-dir` on the next session. Update with `git -C ~/.claude/skills/agent-harness pull` and start a new session; remove it by deleting the directory. This route has no `claude plugin update`.

### Composer

```bash
composer require netresearch/agent-harness-skill
```

### npm (Node Projects)

```bash
npm install --save-dev \
  @netresearch/agent-skill-coordinator \
  github:netresearch/agent-harness-skill
```

Requires [@netresearch/agent-skill-coordinator](https://github.com/netresearch/node-agent-skill-coordinator), which discovers the skill in `node_modules` and registers it in `AGENTS.md` via a `postinstall` hook. For pnpm, also allowlist the coordinator's postinstall:

```json
{
  "pnpm": {
    "onlyBuiltDependencies": ["@netresearch/agent-skill-coordinator"]
  }
}
```

### npx (skills.sh)

```bash
npx skills add https://github.com/netresearch/agent-harness-skill
```

### Git Clone

```bash
git clone https://github.com/netresearch/agent-harness-skill.git
```

## Usage

### Verify (Primary Mode)

Check harness consistency in the current repo:

> "Verify the harness in this repo"
> "Check if this repo is agent-ready"
> "Run harness verification"

### Bootstrap

Create missing harness artefacts:

> "Make this repo agent-ready"
> "Bootstrap the harness for this project"

### Audit

Check maturity level:

> "What's the harness maturity of this repo?"
> "Audit agent-readiness"

### CLI (without skill)

The verification script works standalone. The bootstrap mode copies it to `scripts/verify-harness.sh` in your repository, which the examples use; in this repository it is `skills/agent-harness/scripts/verify-harness.sh`.

```bash
# Full check
bash scripts/verify-harness.sh --format=text

# Check specific level
bash scripts/verify-harness.sh --level=2

# Status summary
bash scripts/verify-harness.sh --status

# In CI
bash scripts/verify-harness.sh  # auto-detects GitHub Actions format
```

## Maturity Levels

### Level 1 -- Basic

- AGENTS.md exists and is index-format
- Commands documented
- docs/ directory exists

### Level 2 -- Verified

- All AGENTS.md references resolve
- Documented commands match actual targets
- docs/ARCHITECTURE.md exists
- CI harness verification active

### Level 3 -- Enforced

- harness-verify is a required check
- Git hooks auto-activate on clone
- PR template includes harness checklist
- Drift detection active

See [maturity-levels.md](skills/agent-harness/references/maturity-levels.md) for details.

## Enforcement Mechanisms

The skill sets up enforcement that works for ALL contributors:

| Mechanism | Layer | Works without skill? |
| --- | --- | --- |
| CI Workflow | Hard | Yes -- runs on GitHub |
| Branch Protection | Hard | Yes -- GitHub server-side |
| .envrc (direnv) | Automatic | Yes -- in repo |
| composer/npm hooks | Automatic | Yes -- runs on install |
| Git hooks | Automatic | Yes -- in repo |
| AGENTS.md | Soft | Yes -- agents read it |
| PR Template | Soft | Yes -- GitHub shows it |
| Makefile targets | Soft | Yes -- in repo |

See [enforcement-mechanisms.md](skills/agent-harness/references/enforcement-mechanisms.md) for details.

## Integration with Other Skills

The harness skill delegates specialised work:

| Skill | Delegation | What harness verifies |
| --- | --- | --- |
| agent-rules | AGENTS.md content | Index format, length, references |
| github-project | Branch protection, PR templates | Required checks configured |
| enterprise-readiness | Quality gates, SLSA | Gates present |
| typo3-testing | Test infrastructure | Test commands work |
| git-workflow | Commit conventions, hooks | Hooks installed |
| automated-assessment | Checkpoint evaluation | Maturity checkpoints |

See [skill-integration-map.md](skills/agent-harness/references/skill-integration-map.md) for details.

## Architecture Decisions

- [ADR-001: Verify-First Design](skills/agent-harness/references/adr/001-verify-first-design.md)
- [ADR-002: Enforcement Layers](skills/agent-harness/references/adr/002-enforcement-layers.md)
- [ADR-003: Skill Delegation Model](skills/agent-harness/references/adr/003-skill-delegation-model.md)
- [ADR-004: AGENTS.md as Index](skills/agent-harness/references/adr/004-agents-md-as-index.md)
- [ADR-005: Checkpoint Maturity Model](skills/agent-harness/references/adr/005-checkpoint-maturity-model.md)

## Contributing

Contributions are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) describes the setup, how to run the tests, where CI runs them, and the rule that new behaviour comes with tests. In addition:

- The SKILL.md body stays under 500 lines (`validate-skill.sh` in the Lint workflow enforces it)
- Templates remain self-contained and portable

## Governance and policies

This repository follows the organisation-wide policies of `netresearch`:

- [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md): roles, how changes are decided and disputes resolved, and who controls access to sensitive resources.
- [Roadmap](https://github.com/netresearch/.github/blob/main/ROADMAP.md): the maintenance work planned and excluded for the coming year.
- [Handling of dependency and code analysis findings](https://github.com/netresearch/.github/blob/main/SECURITY.md#handling-of-dependency-and-code-analysis-findings): which vulnerability, licence and static-analysis findings block a change, the deadlines for the others, and how exceptions are recorded.
- [Secret management](https://github.com/netresearch/.github/blob/main/SECURITY.md#secret-management): where CI secrets are stored, who can access them, and when they are rotated.
- [Access roster](https://github.com/netresearch/.github/blob/main/docs/access-roster.md): the accounts with admin, maintain and write access to this repository.

Dependency and static security checks that run on every pull request to `main` (`.github/workflows/security.yml`):

- Dependency review: fails on a known vulnerability of severity high or critical in a dependency the pull request adds or changes.
- Composer Audit: installs the Composer dependencies from `composer.json` and fails on a known vulnerability in them.
- Opengrep: static security analysis of the repository's code; which findings fail the check is set by the [organisation's static analysis rule](https://github.com/netresearch/.github/blob/main/SECURITY.md#static-analysis-sast).
- Betterleaks: fails on a committed secret.
- zizmor: static analysis of the GitHub Actions workflows.

Branch protection of `main` requires Composer Audit, Opengrep and Betterleaks to pass, together with Skill Validation (`.github/workflows/lint.yml`), CodeQL's analysis of the workflows, SonarCloud and the DCO check. Dependency review and zizmor run on every pull request but are not required checks.

What you can and cannot expect from this repository in terms of security, with its threat model: [docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md).

## License

Split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skills, references, docs): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

Copyright (c) 2026 Netresearch DTT GmbH
