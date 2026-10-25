<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Review evidence integration

## Scope

Connect delegated review findings, executed checks and merge controls without
treating one as proof of another. Preserve the existing verification runner and
its outcome semantics. Keep review effort proportional to the change and within
the user's authorization.

## Changes

- [x] Narrow skill selection to repository harness work.
- [x] Require revision, environment and property scope for reused evidence.
- [x] Document delegation boundaries and independent finding validation.
- [x] Separate static review, actual execution and enforced merge controls.
- [x] Keep human approvals bound to the reviewed revision.
- [x] Add task-level budgets, calibration feedback and model-change comparisons.
- [x] Extend PR/MR templates with testing, risk and rollback information.
- [x] Add behavioral regression cases and positive/negative selection queries.
- [x] Update the instruction index and architecture inventory for the eval files.

## Acceptance and verification

- Existing runner behavior remains unchanged; no live branch rule is configured.
- Missing tools, denied access and timeouts must not be described as passes.
- An agent's review cannot supply a required human approval or extra authority.
- New eval patterns have passing and failing samples checked by
  `validate-evals.sh`; those checks establish structure, not model effectiveness.
- Existing script tests and pre-commit checks cover the unchanged runner and the
  modified documentation and data files.

The recorded self-verification is PARTIAL: zero errors and two existing warnings
about hook setup and the local checkpoint declaration. No live model evaluation
of this harness skill is claimed by this change.

## Risks and rollback

Prose cannot enforce a permission or merge rule. Repository owners must inspect
the host configuration when enforcement is in scope. Revert this commit to undo
the instructions, templates and eval cases; there is no deployed state to undo.
