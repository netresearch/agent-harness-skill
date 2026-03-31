# Agent Harness Skill

Agent skill for bootstrapping, verifying, and enforcing agent-harness infrastructure in repositories.

## Structure

- `skills/agent-harness/SKILL.md` — Main skill definition (verify, bootstrap, audit modes)
- `skills/agent-harness/checkpoints.yaml` — Mechanical and LLM checkpoints
- `skills/agent-harness/scripts/verify-harness.sh` — Standalone verification script
- `skills/agent-harness/references/` — Maturity levels, skill integration map, enforcement mechanisms
- `docs/ARCHITECTURE.md` — Architecture overview

## Commands

- `make lint` — Run YAML, Markdown, and ShellCheck linting
- `make test` — Run verification script against itself

## Rules

- AGENTS.md must be a compact index (<150 lines)
- All file references in AGENTS.md must resolve
- Checkpoints use the schema from `references/checkpoints-schema.md`
- Quality delegation: harness verifies output of specialist skills, not the tools
