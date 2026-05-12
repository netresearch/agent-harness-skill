# Plan: retro-skill Implementation

| | |
|---|---|
| **Spec** | [`docs/specs/retro-skill.md`](../specs/retro-skill.md) |
| **Status** | Phase 2 (PLAN) — for review |
| **Date** | 2026-05-11 |

## Component Map

5 repos, 6 logical components.

| # | Component | Repo | Type | Depends on |
|---|---|---|---|---|
| C1 | feedback-memory schema reference | `agent-rules-skill` | Contract doc | none |
| C2 | materialization contract (skill PRs) | `skill-repo-skill` | Contract doc | none |
| C3 | learning-derived checkpoints reference | `automated-assessment-skill` | Contract doc | none |
| C4 | `retro-skill` repo + content | `netresearch/retro-skill` (NEW) | Skill repo | C1, C2, C3 |
| C5 | Harness integration edits | `agent-harness-skill` | SKILL/refs/templates/checkpoints | C4 (for refs to work) |
| C6 | Cross-repo smoke test | (any clean test repo) | Manual verification | C1–C5 |

## Implementation Order

```
Phase 2.A (parallel — contract docs in companion repos)
├── C1: agent-rules-skill / feedback-memory-schema.md
├── C2: skill-repo-skill / materialization-contract.md + issue template + PR block
└── C3: automated-assessment-skill / learning-derived-checkpoints.md
    
   ↓  Gate: 3 PRs open with stable doc structure (text can iterate)

Phase 2.B (sequential — retro-skill build)
├── B1: Repo creation on github.com/netresearch + local worktree under ~/p/
├── B2: skill-repo-skill scaffolding (plugin.json, composer.json, licenses, README stub)
├── B3: references/ directory (7 files; can be drafted in parallel, committed atomically)
├── B4: scripts/detect-mechanical.py (Schicht A — testable)
├── B5: scripts/find-installed-skills.sh (mechanical discovery helper)
├── B6: scripts/extract-coach-events.py + scan-cross-session.py (Schicht C)
├── B7: skills/retro/SKILL.md (frontmatter, triggers, workflow summary)
├── B8: commands/retro.md (slash command definition)
├── B9: hooks/session-end.json (off by default)
├── B10: skills/retro/checkpoints.yaml (own quality gates)
└── B11: docs/specs/retro-skill.md mirror

   ↓  Gate: retro-skill runs end-to-end with stub classification

Phase 2.C (sequential — harness integration in agent-harness-skill)
├── C5.1: SKILL.md edits (Key Principle + Delegation)
├── C5.2: references/skill-integration-map.md retro section
├── C5.3: references/harness-engineering-overview.md addendum
├── C5.4: templates/{pull_request,merge_request}_template.md.tmpl retro question
└── C5.5: checkpoints.yaml AH-22 + AH-23
    
   ↓  Gate: AH-22 + AH-23 green against test repo with retro-skill installed

Phase 2.D (smoke test + integration)
├── D1: Test session against real Coach data (1011 candidates available)
├── D2: Token budget measurement vs Coach-continuous-hooks baseline
├── D3: Materialization smoke per destination (6×)
├── D4: Private-repo confirmation path
└── D5: Documentation: README with quickstart, link from agent-harness-skill
```

## Rationale for Order

- **Contracts first (Phase A)** because retro-skill references them. Stub structure can be merged early; prose iterates.
- **retro-skill before harness (Phase B vs C)** because harness verifies retro-skill artefacts exist. Reverse order would create false-negative checkpoints.
- **Parallelism is highest in Phase A** (3 independent contract docs). Phase B is mostly sequential within retro-skill, but B3 (references/) is itself parallelizable across 7 files — subagent-dispatchable.
- **Phase D after C** because end-to-end smoke needs harness checks active.

## Risk Table

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | GitHub repo creation requires explicit user action | High | Low | User triggers `gh repo create netresearch/retro-skill` before B1; document in plan as prerequisite |
| R2 | Skill-discovery keyword match produces false positives | Medium | Medium | Ask user on ambiguity; log decisions; cache per session |
| R3 | Token budget unknown without prototype | Medium | Medium | Run early measurement after B7+B8; gate further work if >2× Coach baseline |
| R4 | Coach `events.sqlite` schema undocumented | Low | Low | Read-only, graceful degrade if schema differs; explicit fallback to JSONL scan |
| R5 | Patch worktree dirty-check produces false fallback to /tmp | Low | Low | Show user reason for fallback; allow override |
| R6 | Companion PRs merged out of order (retro references stub) | Medium | Low | All contract PRs land first; retro-skill v0.1 release blocked on companion merges |
| R7 | Private repo confirmation becomes UX friction | Medium | Medium | Remember per-repo decision per session; option to disable globally |
| R8 | LLM cost spikes on long sessions | Medium | Medium | Hard cap on transcript bytes fed to LLM; truncate with summary |
| R9 | Plugin manifest formats vary across plugins | Medium | Low | Try multiple sources (plugin.json, composer.json, git remote); fall back to user prompt |
| R10 | Existing 8 `feedback_*.md` files don't all match documented schema | Low | Low | Verify schema match in B3 (feedback-memory-schema.md draft); align doc to reality |

## Verification Gates

| Gate | When | What to verify | Pass = |
|---|---|---|---|
| **G0 → A** | Before Phase A | Spec is approved | User explicit OK |
| **A → B** | After Phase A | 3 contract docs merged or merge-ready | `gh pr list` shows 3 open/merged across companion repos with stable section structure |
| **B7 measurement** | After B7+B8 | Token cost of `/retro` against synthetic session | Cost ≤ target (TBD after first measurement, document floor) |
| **B → C** | After Phase B | retro-skill runs end-to-end with stub classification | `/retro` against test session produces ≥1 proposal of each destination type |
| **C → D** | After Phase C | AH-22 + AH-23 trigger correctly | Harness verify in test repo shows AH-22 warning if template missing retro question; AH-23 info if hook present |
| **D → release** | After Phase D | Smoke test passes for 6 destinations | One materialization per destination created in test repo; PRs land in source repos (not cache) |

## Prerequisites Before Phase A

User actions required (cannot be automated):

- [ ] **Create empty GitHub repo:** `gh repo create netresearch/retro-skill --public --description "LLM-driven session retrospection skill"` (or via web UI)
- [ ] **Approve this plan** (this document)
- [ ] **Confirm AH-22 / AH-23 IDs** are still free (re-check `checkpoints.yaml` for collisions)
- [ ] **Decide token budget target** for G3 verification (can be deferred; current placeholder is "dramatically below Coach baseline")

## Estimation

Approximations only — refine after Phase 3 (TASKS) decomposition.

| Phase | Subagents possible | Sequential elapsed | Notes |
|---|---|---|---|
| A | 3 parallel | ~1 hour | Three contract docs, modest prose |
| B | 7+ parallel (B3, scripts) | ~3 hours | retro-skill is the bulk; B4+B6 are Python with logic |
| C | 1 sequential | ~30 min | Mostly editing existing files |
| D | Manual | ~1 hour | Real session + 6 materialization smoke tests |
| **Total** | | ~5.5 hours focused work | excludes review cycles and PR roundtrips |

## Out of Plan (Out of Spec already, but reiterate)

- Coach pipeline cleanup of 1011 stale candidates
- Marketplace listing automation for retro-skill itself
- Migration of existing 8 `feedback_*.md` to a new format (current format is canonical)
- Multi-session UI / dashboard
- Auto-merge of `/retro`-created PRs

## What's Next

1. **Review** this plan
2. **Approve** prerequisites checklist above
3. Proceed to **Phase 3 (TASKS)** — per-repo file-level tasks with:
   - Acceptance criteria
   - Verify command
   - Files touched
   - One task = one file change (per user preference)
4. **Phase 4 (IMPLEMENT)** with subagent dispatch per task
