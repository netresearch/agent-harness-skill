---
name: agent-harness
description: "Use when making a repo agent-ready, verifying harness consistency, checking for documentation drift, bootstrapping harness infrastructure (AGENTS.md as index, docs/ structure, CI verification, enforcement mechanisms), or auditing repo agent-readiness maturity level."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires Bash, Read, Write, Edit, Glob, Grep tools"
metadata:
  author: Netresearch DTT GmbH
  version: "1.8.0"
  repository: https://github.com/netresearch/agent-harness-skill
allowed-tools: Bash(git:*,make:*,bash:*,wc:*,test:*,chmod:*) Read Write Edit Glob Grep Agent
---

# Agent Harness

The agent harness makes a repo agent-ready with self-sustaining enforcement. This skill **installs** it; CI, hooks, and conventions then enforce it.

## Modes

### 1. Verify (primary)

Always start here. From the target repo root, run:

```bash
scripts/verify-harness.sh
```

Analyse the output and fix or suggest fixes. Verification checks dead references, line counts, missing artefacts, and command/target alignment.

### 2. Bootstrap

When artefacts are missing, create them from templates:

| Artefact | Template | Platform |
| --- | --- | --- |
| `AGENTS.md` | `templates/AGENTS.md.tmpl` | All |
| `docs/ARCHITECTURE.md` | `templates/ARCHITECTURE.md.tmpl` | All |
| `docs/exec-plans/{active,completed}/` | Create directories | All |
| `.github/workflows/harness-verify.yml` | `templates/harness-verify.yml.tmpl` | GitHub |
| `.gitlab-ci.yml` (harness-verify job) | `templates/gitlab-ci-harness-verify.yml.tmpl` | GitLab |
| `.forgejo/workflows/harness-verify.yml` | `templates/forgejo-harness-verify.yml.tmpl` | Forgejo/Gitea |
| `.github/pull_request_template.md` | `templates/pull_request_template.md.tmpl` | GitHub |
| `.gitlab/merge_request_templates/Default.md` | `templates/merge_request_template.md.tmpl` | GitLab |
| `.forgejo/pull_request_template.md` | `templates/pull_request_template.md.tmpl` | Forgejo/Gitea |
| `.envrc` | `templates/envrc.tmpl` | All |
| Makefile harness targets | `templates/Makefile.harness.tmpl` | All |
| `scripts/verify-harness.sh` | `scripts/verify-harness.sh` (copy directly) | All |

Populate with repo-specific values; never overwrite existing files without confirmation.

### 3. Audit

Report the repo's maturity level (1, 2, or 3) and show what is needed to reach the next level. See `references/maturity-levels.md` for detailed criteria.

## Key Principles

- **AGENTS.md is an index, not an encyclopedia.** Keep it under 150 lines. Put detail in `docs/`.
- **Enforcement is project-level.** CI workflows, git hooks, and branch protection enforce the harness -- not this skill at runtime.
- **Verify first, bootstrap second.** Always run verification before creating artefacts. The skill checks artefacts, not tools.
- **Delegate specialist work.** See `references/skill-integration-map.md` for skill routing (`@agent-rules`, `@github-project`, `@enterprise-readiness`, `@retro`).
- **Does not own learning.** Session retrospection, outcome review, and constitutional audits are delegated to `retro-skill`. The harness verifies integration points exist (AH-22, AH-23) but does not invoke retro at runtime.

## Maturity Levels

**Level 1 -- Basic:** AGENTS.md exists, is an index, documents commands.

**Level 2 -- Verified:** CI enforces harness integrity, AGENTS.md references resolve, commands match Makefile/scripts, ARCHITECTURE.md exists.

**Level 3 -- Enforced:** Branch protection requires harness CI, git hooks auto-activate, PR template includes checklist, drift detection on push.

See `references/maturity-levels.md` for the full breakdown.

## References

- `references/maturity-levels.md` -- Maturity criteria and progression
- `references/agents-md-rules.md` -- AGENTS.md authoring rules
- `references/artefact-inventory.md` -- Harness artefacts list
- `references/harness-engineering-overview.md` -- Theory: four functions, patterns
- `references/agent-first-architecture.md` -- Legibility, layered deps, agent-first tech
- `references/enforcement-mechanisms.md` -- 10-mechanism table (CI, hooks, protection, drift)
- `references/skill-integration-map.md` -- Skill routing map + integration contracts with companion skills
