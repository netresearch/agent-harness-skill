# ADR-003: Skill Delegation Model

**Status:** Accepted
**Date:** 2026-03-22
**Context:** The agent-harness skill could implement everything itself (AGENTS.md generation, branch protection setup, quality gates, test infrastructure) or delegate specialised work to existing skills. Several skills already exist in the Netresearch ecosystem: agent-rules, github-project, enterprise-readiness, typo3-testing, git-workflow, automated-assessment, and more.
**Decision:** agent-harness delegates specialised work to existing skills and defines the integration contract (what artefacts it expects back).
**Consequences:** The harness skill remains lean and focused on orchestration and verification. Delegation is advisory, not forced.

## Delegation Map

| Task | Delegate To | Expected Artefact | Harness Verifies |
|---|---|---|---|
| AGENTS.md content | agent-rules-skill | AGENTS.md file | Is it index-format? Under 150 lines? No dead refs? |
| Branch protection | github-project-skill | Ruleset/protection config | Is harness-verify a required check? |
| Quality gates | enterprise-readiness-skill | Quality gate config | Are quality gates present? |
| Test infrastructure | typo3-testing / go-development / etc. | Test config and CI jobs | Do documented test commands work? |
| Commit conventions | git-workflow-skill | Git hooks, commit config | Are hooks installed? |
| Plan lifecycle | superpowers:writing-plans | Plan documents | Do active plans exist in docs/exec-plans/? |
| Maturity audit | automated-assessment-skill | Checkpoint evaluation | Do checkpoints pass at target level? |

## How Delegation Works

The harness skill does not call delegated skills directly. Instead, it operates in two modes:

1. **Verification mode** -- checks whether the expected artefacts exist and are well-formed. This mode has no dependency on any delegated skill. It checks files and configurations, not tools.

2. **Guidance mode** -- when artefacts are missing or malformed, the skill reports what is wrong and which skill to invoke to fix it. For example: "AGENTS.md is 230 lines. Run agent-rules:agents to restructure it as an index (see ADR-004)."

This separation means teams can adopt harness verification without adopting all delegated skills. A team that manages AGENTS.md manually still gets verification. A team that uses agent-rules gets the same verification plus automated generation.

## Rationale

- Avoids duplication -- each skill maintains its domain expertise.
- Allows the harness skill to remain lean and focused on orchestration.
- Skills evolve independently -- the harness skill does not need updating when agent-rules improves its AGENTS.md generation.
- Teams can adopt harness verification without adopting all delegated skills.

## Implications

- The harness skill must clearly document when to invoke which delegate.
- The verification script works without delegated skills (it checks artefacts, not tools).
- The delegation map must be kept current as new skills are added to the ecosystem.
- Circular dependencies must be avoided -- delegated skills should not depend on agent-harness.
