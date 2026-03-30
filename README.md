# Agent Harness Skill

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
```

### Composer

```bash
composer require netresearch/agent-harness-skill
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

The verification script works standalone:

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

Contributions are welcome. Please ensure:

- Changes pass `bash skills/agent-harness/scripts/verify-harness.sh`
- SKILL.md stays under 500 words
- Templates remain self-contained and portable

## License

Split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skills, references, docs): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

Copyright (c) 2026 Netresearch DTT GmbH
