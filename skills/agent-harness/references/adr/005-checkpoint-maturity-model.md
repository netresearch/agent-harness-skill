# ADR-005: Checkpoint Maturity Model

**Status:** Accepted
**Date:** 2026-03-22
**Context:** Binary "harness yes/no" is insufficient for gradual adoption. Teams need to understand their current maturity and what to do next. OpenAI's harness engineering paper describes maturity levels (single developer to small team to production). The Netresearch automated-assessment-skill already provides a checkpoint-based audit system.
**Decision:** Three maturity levels, each with mechanical checkpoints that automated-assessment can evaluate.
**Consequences:** Verification accepts a `--level=N` flag. Checkpoint IDs follow the scheme AH-0x (Level 1), AH-1x (Level 2), AH-2x (Level 3).

## Level 1 -- Basic

Suitable for any repo at any team size. The minimum bar for agent-readiness.

| Checkpoint | ID | Verification |
|---|---|---|
| AGENTS.md exists | AH-01 | File exists at repo root |
| AGENTS.md is index-format | AH-02 | Under 150 lines (see ADR-004) |
| Commands are documented | AH-03 | AGENTS.md contains a commands section |
| docs/ directory exists | AH-04 | Directory exists at repo root |

## Level 2 -- Verified

Suitable for team repos with CI. Adds consistency checks.

| Checkpoint | ID | Verification |
|---|---|---|
| All Level 1 checkpoints pass | -- | Prerequisite |
| All AGENTS.md references resolve | AH-11 | Every referenced path exists |
| Documented commands match actual targets | AH-12 | Commands listed in AGENTS.md exist in Makefile, composer.json, or package.json |
| docs/ARCHITECTURE.md exists | AH-13 | File exists |
| CI harness verification workflow exists | AH-14 | `.github/workflows/harness-verify.yml` exists |

## Level 3 -- Enforced

Suitable for production repos with full enforcement. Adds server-side guarantees.

| Checkpoint | ID | Verification |
|---|---|---|
| All Level 2 checkpoints pass | -- | Prerequisite |
| harness-verify is a required check | AH-21 | Branch protection or ruleset includes harness-verify as required status check |
| Git hooks auto-activate on clone | AH-22 | `.envrc` sets `core.hooksPath` or equivalent mechanism exists |
| PR template includes harness checklist | AH-23 | `.github/pull_request_template.md` references harness verification |
| Drift detection is active | AH-24 | Structural changes (new dirs, renamed files) trigger docs-update warnings in CI |

## Rationale

- Gradual adoption -- teams start at Level 1 and upgrade when ready.
- Each level is strictly additive -- Level 2 includes all of Level 1.
- Mechanical checkpoints make maturity measurable, not subjective. Every checkpoint can be evaluated by a script without human judgment.
- Integration with automated-assessment gives cross-skill audit capability.
- Levels map roughly to OpenAI's single-developer / small-team / production model.

## Usage

The verification script accepts a level flag:

```shell
# Check Level 1 only (default)
./verify-harness.sh --level=1

# Check Levels 1 and 2
./verify-harness.sh --level=2

# Check all levels
./verify-harness.sh --level=3
```

Teams can set their target level in project configuration (for example, in `.harness.yml` or as a variable in the CI workflow). The skill reports the current level and what is needed to reach the next level.

## Checkpoint ID Scheme

- **AH-0x** -- Level 1 (Basic). IDs 01 through 09.
- **AH-1x** -- Level 2 (Verified). IDs 11 through 19.
- **AH-2x** -- Level 3 (Enforced). IDs 21 through 29.

This scheme leaves room for additional checkpoints within each level without renumbering.
