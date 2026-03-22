# Agent Harness Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a skill that bootstraps, verifies, and enforces "agent-harness" infrastructure in any repository — making repos agent-ready with self-sustaining enforcement mechanisms that work for all contributors (human or AI, with or without skills installed).

**Architecture:** The skill follows verify-first design: it primarily checks harness consistency, secondarily bootstraps missing artefacts, and delegates specialised work to existing skills (agent-rules, github-project, enterprise-readiness). All enforcement is project-level (CI workflows, branch protection, git hooks, .envrc) so it outlives the skill's presence.

**Tech Stack:** Bash (verification scripts), YAML (CI workflows, checkpoints), Markdown (SKILL.md, references, ADRs, templates)

---

## File Structure

```
agent-harness-skill/
├── .claude-plugin/
│   └── plugin.json                              # Plugin metadata
├── .github/
│   └── workflows/
│       ├── release.yml                          # Release automation
│       └── lint.yml                             # Linting
├── .gitignore
├── .markdownlint-cli2.jsonc
├── .yamllint.yml
├── Build/
│   ├── Scripts/
│   │   └── check-plugin-version.sh              # Pre-release version check
│   └── hooks/
│       ├── pre-commit
│       └── pre-push
├── LICENSE-MIT
├── LICENSE-CC-BY-SA-4.0
├── README.md
├── composer.json
├── renovate.json
├── skills/
│   └── agent-harness/
│       ├── SKILL.md                             # Main skill instructions
│       ├── checkpoints.yaml                     # Harness maturity checkpoints
│       ├── references/
│       │   ├── harness-engineering-overview.md   # What harness engineering is
│       │   ├── enforcement-mechanisms.md         # CI, hooks, .envrc, composer
│       │   ├── skill-integration-map.md          # How this skill delegates
│       │   ├── maturity-levels.md                # Level 1/2/3 definitions
│       │   └── adr/
│       │       ├── 001-verify-first-design.md
│       │       ├── 002-enforcement-layers.md
│       │       ├── 003-skill-delegation-model.md
│       │       ├── 004-agents-md-as-index.md
│       │       └── 005-checkpoint-maturity-model.md
│       ├── scripts/
│       │   └── verify-harness.sh                # Portable verification script
│       └── templates/
│           ├── AGENTS.md.tmpl                   # Index-style AGENTS.md template
│           ├── ARCHITECTURE.md.tmpl             # Architecture doc template
│           ├── exec-plan.md.tmpl                # Execution plan template
│           ├── harness-verify.yml.tmpl           # CI workflow template
│           ├── pull_request_template.md.tmpl     # PR template with harness checks
│           ├── envrc.tmpl                        # .envrc template
│           └── Makefile.harness.tmpl             # Makefile harness targets
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-03-22-agent-harness-skill.md  # This plan
```

---

### Task 1: Repository Scaffolding

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `composer.json`
- Create: `LICENSE-MIT`
- Create: `LICENSE-CC-BY-SA-4.0`
- Create: `.gitignore`
- Create: `renovate.json`
- Create: `.markdownlint-cli2.jsonc`
- Create: `.yamllint.yml`

- [ ] **Step 1: Initialize git repo**

```bash
cd /home/cybot/projects/agent-harness-skill
git init
```

- [ ] **Step 2: Create plugin.json**

```json
{
  "name": "agent-harness",
  "version": "1.0.0",
  "description": "Use when making a repo agent-ready, verifying harness consistency, checking for documentation drift, or bootstrapping agent-harness infrastructure (AGENTS.md as index, docs/ structure, CI verification, enforcement mechanisms).",
  "repository": "https://github.com/netresearch/agent-harness-skill",
  "license": "(MIT AND CC-BY-SA-4.0)",
  "author": {
    "name": "Netresearch DTT GmbH",
    "url": "https://www.netresearch.de"
  },
  "skills": [
    "./skills/agent-harness"
  ]
}
```

- [ ] **Step 3: Create composer.json**

```json
{
  "name": "netresearch/agent-harness-skill",
  "description": "Agent Skill for bootstrapping, verifying, and enforcing agent-harness infrastructure in repositories",
  "type": "ai-agent-skill",
  "license": "(MIT AND CC-BY-SA-4.0)",
  "authors": [
    {
      "name": "Netresearch DTT GmbH",
      "homepage": "https://www.netresearch.de/",
      "role": "Manufacturer"
    }
  ],
  "require": {
    "netresearch/composer-agent-skill-plugin": "*"
  },
  "extra": {
    "ai-agent-skill": "skills/agent-harness/SKILL.md"
  },
  "support": {
    "issues": "https://github.com/netresearch/agent-harness-skill/issues",
    "source": "https://github.com/netresearch/agent-harness-skill"
  }
}
```

- [ ] **Step 4: Create license files, .gitignore, renovate.json, lint configs**

Standard Netresearch patterns. LICENSE-MIT and LICENSE-CC-BY-SA-4.0 with "Netresearch DTT GmbH", copyright 2026.

- [ ] **Step 5: Commit scaffolding**

```bash
git add -A
git commit -S --signoff -m "chore: initial repo scaffolding"
```

---

### Task 2: ADR Documentation

These capture all decisions made during the design conversation — the "why" behind the skill.

**Files:**
- Create: `skills/agent-harness/references/adr/001-verify-first-design.md`
- Create: `skills/agent-harness/references/adr/002-enforcement-layers.md`
- Create: `skills/agent-harness/references/adr/003-skill-delegation-model.md`
- Create: `skills/agent-harness/references/adr/004-agents-md-as-index.md`
- Create: `skills/agent-harness/references/adr/005-checkpoint-maturity-model.md`

- [ ] **Step 1: Write ADR-001 — Verify-First Design**

Decision: The skill is primarily a verifier, secondarily a bootstrapper.
Context: The original analysis suggested bootstrap-first. We reversed this because:
- Verification works on repos that built their harness manually
- It doesn't enforce a specific genesis path
- OpenAI's harness engineering paper emphasises mechanical verification over generation
- Existing skills (agent-rules, github-project) already handle generation

- [ ] **Step 2: Write ADR-002 — Enforcement Layers**

Decision: Three-layer enforcement model (hard → automatic → soft).
Context: We evaluated 10 enforcement mechanisms (CI, Branch Protection, Git Hooks, .envrc, Composer plugins, npm scripts, pre-commit framework, Makefile, AGENTS.md, PR Templates). The layered model ensures:
- Hard layer (CI + Branch Protection): Nobody gets past, server-side
- Automatic layer (.envrc, composer post-install, git hooks): Activates on clone/install
- Soft layer (AGENTS.md, PR templates, Makefile targets): Convention-based
This ensures harness enforcement works for contributors without skills installed.

- [ ] **Step 3: Write ADR-003 — Skill Delegation Model**

Decision: agent-harness delegates specialised work to existing skills instead of reimplementing.
Context: To avoid duplication:
- AGENTS.md content generation → agent-rules-skill
- Branch protection / PR templates → github-project-skill
- Quality gates → enterprise-readiness-skill
- Test infrastructure → typo3-testing / go-development / etc.
- Plan lifecycle → superpowers:writing-plans
The harness skill defines WHAT artefacts it expects from each delegate, not HOW to create them.

- [ ] **Step 4: Write ADR-004 — AGENTS.md as Index**

Decision: AGENTS.md must be a compact index (<150 lines), not an encyclopedia.
Context: OpenAI's harness engineering paper explicitly recommends this. The rationale:
- Agents read AGENTS.md every session — long files waste context
- Detail belongs in docs/ (ARCHITECTURE.md, design-docs, etc.)
- The index pattern makes drift detection simpler (fewer things to verify)
- AGENTS.md should reference, not duplicate

- [ ] **Step 5: Write ADR-005 — Checkpoint Maturity Model**

Decision: Three maturity levels measured via checkpoints, integrated with automated-assessment-skill.
Context: Binary "harness yes/no" is insufficient. We define:
- Level 1 (Basic): AGENTS.md exists, is index-format, commands documented
- Level 2 (Verified): CI harness check, no dead refs, commands match targets, architecture doc exists
- Level 3 (Enforced): Branch protection, auto-hook-setup, drift detection, PR template
Each level has mechanical checkpoints that automated-assessment can audit.

- [ ] **Step 6: Commit ADRs**

```bash
git add skills/agent-harness/references/adr/
git commit -S --signoff -m "docs: add architectural decision records for harness design"
```

---

### Task 3: Reference Documentation

**Files:**
- Create: `skills/agent-harness/references/harness-engineering-overview.md`
- Create: `skills/agent-harness/references/enforcement-mechanisms.md`
- Create: `skills/agent-harness/references/skill-integration-map.md`
- Create: `skills/agent-harness/references/maturity-levels.md`

- [ ] **Step 1: Write harness-engineering-overview.md**

Synthesise the research findings:
- OpenAI's 4 system functions: Constrain → Inform → Verify → Correct
- Anthropic's complementary focus: TDD, plan-mode, context transfer
- LangGraph's durability/checkpoint angle (noted as future direction)
- The principle: "Skills build the harness, the harness enforces itself"
- What harness engineering is NOT: not just AGENTS.md, not just CI, not just docs

- [ ] **Step 2: Write enforcement-mechanisms.md**

Detailed reference on all 10 enforcement instruments with:
- When each one triggers
- Who it affects (all vs. local vs. agents only)
- Strength/weakness
- How to set up in different project types (PHP/Composer, Node/npm, Go, generic)
- The activation chain: clone → .envrc → hooks → CI

- [ ] **Step 3: Write skill-integration-map.md**

For each integrated skill, define:
- What the harness skill expects from it (artefacts)
- When delegation happens
- What verification the harness performs on the delegated output
- Skills covered: agent-rules, github-project, enterprise-readiness, typo3-testing, git-workflow, concourse-ci, docker-development, automated-assessment

- [ ] **Step 4: Write maturity-levels.md**

Detailed definition of Level 1/2/3 with:
- What each level requires
- How to measure it
- Example output of verify-harness at each level
- Upgrade path from Level 1 → 2 → 3

- [ ] **Step 5: Commit references**

```bash
git add skills/agent-harness/references/
git commit -S --signoff -m "docs: add reference documentation for harness engineering"
```

---

### Task 4: Templates

**Files:**
- Create: `skills/agent-harness/templates/AGENTS.md.tmpl`
- Create: `skills/agent-harness/templates/ARCHITECTURE.md.tmpl`
- Create: `skills/agent-harness/templates/exec-plan.md.tmpl`
- Create: `skills/agent-harness/templates/harness-verify.yml.tmpl`
- Create: `skills/agent-harness/templates/pull_request_template.md.tmpl`
- Create: `skills/agent-harness/templates/envrc.tmpl`
- Create: `skills/agent-harness/templates/Makefile.harness.tmpl`

- [ ] **Step 1: Create AGENTS.md.tmpl**

Index-style template with sections:
- Repo Structure (where is what)
- Commands (build, test, lint, verify)
- Rules (architecture boundaries, commit format, plan requirements)
- References (links to docs/ARCHITECTURE.md, docs/exec-plans/, etc.)
Max 100 lines. Comments indicating what to fill in.

- [ ] **Step 2: Create ARCHITECTURE.md.tmpl**

Template with sections:
- System Overview (1 paragraph)
- Component Map (subsystems, their responsibilities)
- Dependency Rules (what can import what)
- Data Flow (how data moves through the system)
- Key Decisions (link to ADRs if they exist)

- [ ] **Step 3: Create exec-plan.md.tmpl**

Template matching superpowers plan format but simplified:
- Goal (1 sentence)
- Scope / Non-Goals
- Affected Systems
- Risks
- Verification Steps
- Done Criteria
- Decisions Log

- [ ] **Step 4: Create harness-verify.yml.tmpl**

GitHub Actions workflow that:
- Triggers on pull_request
- Runs verify-harness.sh
- Reports results as annotations
- Can be configured as required check
- Is self-contained (no external action dependencies beyond actions/checkout)

- [ ] **Step 5: Create pull_request_template.md.tmpl**

PR template with harness-aware checklist:
- [ ] AGENTS.md updated (if commands/structure changed)
- [ ] docs/ updated (if architecture/design changed)
- [ ] New subsystems documented
- [ ] Exec plan created (if multi-file change)

- [ ] **Step 6: Create envrc.tmpl**

.envrc template that:
- Sets git hooks path to .githooks
- Adds project bin directories to PATH
- Is safe (only local operations)
- Includes comment explaining purpose

- [ ] **Step 7: Create Makefile.harness.tmpl**

Makefile with targets:
- `verify-harness`: Run verify-harness.sh
- `bootstrap-harness`: Create missing artefacts
- `harness-status`: Show current maturity level

- [ ] **Step 8: Commit templates**

```bash
git add skills/agent-harness/templates/
git commit -S --signoff -m "feat: add project templates for harness bootstrapping"
```

---

### Task 5: Verification Script

**Files:**
- Create: `skills/agent-harness/scripts/verify-harness.sh`

- [ ] **Step 1: Write verify-harness.sh**

Portable bash script (no dependencies beyond coreutils + git + jq) that checks:

**Level 1 checks:**
- AGENTS.md exists
- AGENTS.md is under 150 lines
- AGENTS.md contains command references
- docs/ directory exists

**Level 2 checks:**
- All AGENTS.md internal references resolve to existing files
- Documented `make` targets exist in Makefile
- Documented `composer` scripts exist in composer.json
- Documented `npm` scripts exist in package.json
- docs/ARCHITECTURE.md exists
- CI harness workflow exists

**Level 3 checks:**
- .envrc or equivalent hook auto-setup exists
- .githooks/ directory exists
- PR template exists with harness checklist
- Drift detection: if build/CI files changed in last commit, AGENTS.md should have been updated too

**Output modes:**
- Default: GitHub Actions annotations format (::error::, ::warning::)
- `--format=text`: Plain text for local use
- `--check=<name>`: Run single check category
- `--level=N`: Only check up to level N
- Exit code: 0=pass, 1=errors found

- [ ] **Step 2: Make script executable and test locally**

```bash
chmod +x skills/agent-harness/scripts/verify-harness.sh
bash skills/agent-harness/scripts/verify-harness.sh --format=text
```

- [ ] **Step 3: Commit verification script**

```bash
git add skills/agent-harness/scripts/
git commit -S --signoff -m "feat: add verify-harness.sh verification script"
```

---

### Task 6: Checkpoints Definition

**Files:**
- Create: `skills/agent-harness/checkpoints.yaml`

- [ ] **Step 1: Write checkpoints.yaml**

Define mechanical checkpoints for automated-assessment integration:

```yaml
version: 1
skill_id: agent-harness

preconditions:
  - type: command
    target: "git rev-parse --git-dir"
    desc: "Must be a git repository"

mechanical:
  # Level 1 — Basic
  - id: AH-01
    type: file_exists
    target: AGENTS.md
    severity: error
    desc: "AGENTS.md exists"

  - id: AH-02
    type: command
    target: "[ $(wc -l < AGENTS.md) -lt 150 ]"
    severity: warning
    desc: "AGENTS.md is compact index (<150 lines)"

  - id: AH-03
    type: contains
    target: AGENTS.md
    value: "## Commands"
    severity: warning
    desc: "AGENTS.md documents available commands"

  # Level 2 — Verified
  - id: AH-10
    type: command
    target: "bash skills/agent-harness/scripts/verify-harness.sh --check=refs --level=2"
    severity: error
    desc: "No dead references in AGENTS.md"

  - id: AH-11
    type: command
    target: "bash skills/agent-harness/scripts/verify-harness.sh --check=commands --level=2"
    severity: warning
    desc: "Documented commands match actual targets"

  - id: AH-12
    type: file_exists
    target: docs/ARCHITECTURE.md
    severity: warning
    desc: "Architecture documentation exists"

  - id: AH-13
    type: file_exists
    target: .github/workflows/harness-verify.yml
    severity: warning
    desc: "CI harness verification workflow exists"

  # Level 3 — Enforced
  - id: AH-20
    type: file_exists
    target: .github/pull_request_template.md
    severity: warning
    desc: "PR template with harness checklist exists"

  - id: AH-21
    type: command
    target: "grep -qlr 'hooksPath\\|core.hookspath' .envrc .husky 2>/dev/null"
    severity: warning
    desc: "Git hooks auto-activate on clone"

  - id: AH-22
    type: command
    target: "bash skills/agent-harness/scripts/verify-harness.sh --check=drift"
    severity: warning
    desc: "Drift detection is active"
```

- [ ] **Step 2: Commit checkpoints**

```bash
git add skills/agent-harness/checkpoints.yaml
git commit -S --signoff -m "feat: add harness maturity checkpoints for automated assessment"
```

---

### Task 7: SKILL.md — The Main Skill Definition

**Files:**
- Create: `skills/agent-harness/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

The SKILL.md is the agent-facing instruction document. It must be under 500 words and reference
the references/ directory for detail. Key sections:

**Frontmatter:**
```yaml
---
name: agent-harness
description: "Use when making a repo agent-ready, verifying harness consistency, checking for documentation drift, bootstrapping harness infrastructure, or auditing repo agent-readiness maturity level."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires Bash, Read, Write, Edit, Glob, Grep tools"
metadata:
  author: Netresearch DTT GmbH
  version: "1.0.0"
  repository: https://github.com/netresearch/agent-harness-skill
allowed-tools: Bash(git:*,make:*,bash:*,wc:*,test:*,chmod:*) Read Write Edit Glob Grep Agent
---
```

**Body structure:**
1. **What is Agent Harness** — 2 sentences: repo-level infrastructure that makes repos agent-ready with self-sustaining enforcement.
2. **Three Modes** — Verify (check consistency), Bootstrap (create missing artefacts), Audit (measure maturity level).
3. **Verify Mode** (primary) — Run verify-harness.sh, report findings, suggest fixes.
4. **Bootstrap Mode** — Analyse repo, create missing artefacts from templates, delegate to other skills.
5. **Audit Mode** — Report maturity level (1/2/3), show what's needed for next level.
6. **Key Principles** — AGENTS.md is index not encyclopedia, enforcement must be project-level, skill is the installer not the harness.
7. **Delegation** — When to invoke agent-rules, github-project, enterprise-readiness.
8. **References** — Links to references/ for detail.

- [ ] **Step 2: Commit SKILL.md**

```bash
git add skills/agent-harness/SKILL.md
git commit -S --signoff -m "feat: add main SKILL.md for agent-harness skill"
```

---

### Task 8: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Human-facing documentation following Netresearch skill repo pattern:
- What the skill does (for humans, not agents)
- Installation (marketplace, composer, npx, git clone)
- Usage examples (verify, bootstrap, audit)
- Maturity levels explanation
- How enforcement works
- Integration with other skills
- Contributing
- License

- [ ] **Step 2: Commit README**

```bash
git add README.md
git commit -S --signoff -m "docs: add README with usage guide and maturity model"
```

---

### Task 9: Build Infrastructure

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `.github/workflows/lint.yml`
- Create: `Build/Scripts/check-plugin-version.sh`
- Create: `Build/hooks/pre-commit`
- Create: `Build/hooks/pre-push`

- [ ] **Step 1: Create release workflow**

Standard Netresearch release workflow with signed tags, GitHub release creation, composer asset.

- [ ] **Step 2: Create lint workflow**

Markdown lint + YAML lint + shellcheck for verify-harness.sh.

- [ ] **Step 3: Create build scripts and hooks**

Standard check-plugin-version.sh, pre-commit (lint), pre-push (full verify).

- [ ] **Step 4: Commit build infrastructure**

```bash
git add .github/ Build/
git commit -S --signoff -m "ci: add release, lint workflows and git hooks"
```

---

### Task 10: Final Verification

- [ ] **Step 1: Run the skill's own verify-harness.sh against itself**

The skill repo should itself be harness-compliant. Run:
```bash
bash skills/agent-harness/scripts/verify-harness.sh --format=text
```

- [ ] **Step 2: Verify plugin.json is valid**

```bash
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"
```

- [ ] **Step 3: Verify composer.json is valid**

```bash
python3 -c "import json; json.load(open('composer.json'))"
```

- [ ] **Step 4: Verify all files exist**

```bash
for f in .claude-plugin/plugin.json composer.json LICENSE-MIT LICENSE-CC-BY-SA-4.0 \
         README.md .gitignore renovate.json skills/agent-harness/SKILL.md \
         skills/agent-harness/checkpoints.yaml skills/agent-harness/scripts/verify-harness.sh; do
  test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
done
```

- [ ] **Step 5: Final commit if needed, tag v1.0.0**

```bash
git tag -s v1.0.0 -m "v1.0.0"
```
