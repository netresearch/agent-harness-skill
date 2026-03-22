# ADR-004: AGENTS.md as Index

**Status:** Accepted
**Date:** 2026-03-22
**Context:** AGENTS.md files in practice tend to grow into encyclopedias -- long documents with detailed instructions, code patterns, API documentation, and architectural detail. This wastes agent context window (AGENTS.md is read every session), makes drift harder to detect, and duplicates information better stored elsewhere. OpenAI's harness engineering paper (https://openai.com/index/harness-engineering/) explicitly recommends AGENTS.md as a "table of contents" that points to detailed documentation elsewhere.
**Decision:** AGENTS.md must be a compact index (hard limit: under 150 lines), not an encyclopedia. Detail lives in `docs/` and other referenced files.
**Consequences:** The verification script enforces the line limit and checks that all internal references resolve.

## What AGENTS.md Should Contain

- **Repo structure map** -- where is what (10-15 lines). Enough for an agent to orient itself without reading every directory.
- **Available commands** -- build, test, lint, verify (10-15 lines). The commands an agent needs to validate its own work.
- **Key rules** -- architecture boundaries, commit format, coding standards (10-15 lines). Only rules that apply to every change.
- **References** -- links to ARCHITECTURE.md, design docs, ADRs, and other detailed documentation. The index entries.

## What AGENTS.md Should NOT Contain

- Detailed API documentation (belongs in docs/ or inline code docs).
- Code patterns or examples (belongs in docs/patterns/ or a cookbook).
- Full architecture descriptions (belongs in docs/ARCHITECTURE.md).
- Historical context or ADRs (belongs in docs/adr/ or similar).
- CI/CD pipeline details (belongs in docs/ci.md or workflow comments).
- Troubleshooting guides (belongs in docs/troubleshooting.md).

## Rationale

- Agents read AGENTS.md every session -- every line costs context window space.
- Short files are easier to keep current. Less drift surface means fewer stale instructions.
- The index pattern makes dead-reference detection mechanical: parse references, check they resolve.
- Detail in referenced files can be read on-demand, only when relevant to the current task.
- Multiple agents (Claude, Codex, Copilot, Gemini) all read AGENTS.md -- the compact format benefits all of them.

## Enforcement

The `verify-harness.sh` script checks two things related to this ADR:

1. **Line count** -- AGENTS.md must be under 150 lines. If it exceeds this limit, verification fails with a message indicating the current line count and the limit.

2. **Reference resolution** -- every file path referenced in AGENTS.md (detected by patterns like `docs/...`, `./...`, relative paths) must resolve to an existing file or directory in the repository. Dead references cause verification failure.

## Migration Path for Existing Repos

Repos with long AGENTS.md files can migrate incrementally:

1. Identify sections that are detailed documentation (not index entries).
2. Move each section to an appropriate file in `docs/`.
3. Replace the section in AGENTS.md with a one-line reference to the new location.
4. Run `make verify-harness` to confirm the result is under 150 lines and all references resolve.
