---
name: agent-harness
description: "Use when making a repo agent-ready, verifying harness consistency, checking for documentation drift, bootstrapping harness infrastructure (AGENTS.md as index, docs/ structure, CI verification, enforcement mechanisms), or auditing repo agent-readiness maturity level."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires Bash, Read, Write, Edit, Glob, Grep tools"
metadata:
  author: Netresearch DTT GmbH
  version: "1.0.0"
  repository: https://github.com/netresearch/agent-harness-skill
allowed-tools: Bash(git:*,make:*,bash:*,wc:*,test:*,chmod:*) Read Write Edit Glob Grep Agent
---

# Agent Harness

The agent harness is repo-level infrastructure that makes repositories agent-ready with self-sustaining enforcement. This skill is the **installer**; the harness enforces itself via CI, hooks, and conventions once installed.

## Modes

### 1. Verify (primary)

Always start here. Run the verification script against the target repo:

```bash
scripts/verify-harness.sh /path/to/target-repo
```

Analyse the output. Fix issues directly or suggest fixes to the user. Verification checks for dead references, line count limits, missing artefacts, and command/target alignment.

### 2. Bootstrap

When artefacts are missing, create them from templates:

| Artefact | Template | Platform |
|---|---|---|
| `AGENTS.md` | `templates/AGENTS.md.tmpl` | All |
| `docs/ARCHITECTURE.md` | `templates/ARCHITECTURE.md.tmpl` | All |
| `docs/exec-plans/{active,completed}/` | Create directories | All |
| `.github/workflows/harness-verify.yml` | `templates/harness-verify.yml.tmpl` | GitHub |
| `.gitlab-ci.yml` (harness-verify job) | `templates/gitlab-ci-harness-verify.yml.tmpl` | GitLab |
| `.github/pull_request_template.md` | `templates/pull_request_template.md.tmpl` | GitHub |
| `.gitlab/merge_request_templates/Default.md` | `templates/merge_request_template.md.tmpl` | GitLab |
| `.envrc` | `templates/envrc.tmpl` | All |
| Makefile harness targets | `templates/Makefile.harness.tmpl` | All |
| `scripts/verify-harness.sh` | `scripts/verify-harness.sh` (copy directly) | All |

Populate templates with repo-specific values (project name, tech stack, existing conventions). Do not overwrite files that already exist without user confirmation.

### 3. Audit

Report the repo's maturity level (1, 2, or 3) and show what is needed to reach the next level. See `references/maturity-levels.md` for detailed criteria.

## Key Principles

- **AGENTS.md is an index, not an encyclopedia.** Keep it under 150 lines. Put detail in `docs/`.
- **Enforcement is project-level.** CI workflows, git hooks, and branch protection enforce the harness -- not this skill at runtime.
- **Verify first, bootstrap second.** Always run verification before creating artefacts. The skill checks artefacts, not tools.
- **Delegate specialist work.** Route concerns to the appropriate skill:
  - AGENTS.md content rules: `@agent-rules`
  - Branch protection / merge checks setup: `@github-project` (GitHub) or manual GitLab settings
  - Quality gates and CI pipelines: `@enterprise-readiness`

## Maturity Levels

**Level 1 -- Basic:** AGENTS.md exists, serves as an index (not a wall of text), and documents available commands.

**Level 2 -- Verified:** CI checks enforce harness integrity, all AGENTS.md references resolve, documented commands match actual Makefile/script targets, and ARCHITECTURE.md exists.

**Level 3 -- Enforced:** Branch protection requires harness CI to pass, git hooks auto-activate on clone, PR template includes harness checklist, and drift detection runs on every push.

See `references/maturity-levels.md` for the full breakdown.

## References

- `references/maturity-levels.md` -- Detailed maturity level criteria and progression guidance
- `references/agents-md-rules.md` -- AGENTS.md authoring rules and anti-patterns
- `references/artefact-inventory.md` -- Complete list of harness artefacts with purposes
- `references/delegation-map.md` -- Which skill handles which concern
