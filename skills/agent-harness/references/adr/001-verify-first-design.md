# ADR-001: Verify-First Design

**Status:** Accepted
**Date:** 2026-03-22
**Context:** The agent-harness skill could be designed as primarily a generator (creating files) or primarily a verifier (checking consistency). The initial design discussion suggested bootstrap-first, but was reversed.
**Decision:** The skill is primarily a verifier, secondarily a bootstrapper.
**Consequences:** Verification is the default mode; bootstrapping is explicit and optional.

## Rationale

- Verification works on repos that built their harness manually -- no lock-in to skill-generated artefacts.
- It does not enforce a specific genesis path -- teams can adopt gradually.
- OpenAI's harness engineering paper (https://openai.com/index/harness-engineering/) emphasises mechanical verification over generation.
- Existing skills (agent-rules, github-project) already handle generation of specific artefacts.
- Verify-first means `make verify-harness` works even without the skill installed at runtime.

## Detail

The skill's primary mode is "check this repo," not "set up this repo." When invoked, it inspects the repository for the presence, format, and consistency of harness artefacts (AGENTS.md, CI workflows, git hooks, documentation references). It reports what is present, what is missing, and what is inconsistent.

Bootstrap is a secondary mode triggered explicitly (for example, via `agent-harness:bootstrap`). It generates missing artefacts using sensible defaults, but never overwrites existing files without confirmation. The generated artefacts are the same ones the verifier checks, so the workflow is: bootstrap once, verify continuously.

The verification script (`verify-harness.sh`) is designed to be portable. It uses only standard shell utilities and has no dependency on the skill runtime, Claude, or any agent framework. A repository can copy the script into its own CI pipeline and run it independently.

## Implications

- The skill must produce a standalone verification script that works without the skill installed.
- Bootstrap must be idempotent -- running it on an already-configured repo should report "nothing to do."
- Documentation must lead with the verification workflow, not the bootstrap workflow.
- Teams that set up harness artefacts manually get the same verification benefits as teams that used bootstrap.
