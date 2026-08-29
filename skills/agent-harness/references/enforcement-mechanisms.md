# Enforcement Mechanisms Reference

This document covers all 10 enforcement instruments available for making repositories agent-ready. Mechanisms are ordered by enforcement strength, from hardest (server-side, nobody bypasses) to softest (convention-based, reminder only).

## Why prose is not a mechanism

The mechanisms below are ordered by strength, and the reason the list starts
where it does is measurable: **text an agent reads does not enforce anything,
including the text inside a skill.** Four levers were measured in
[netresearch/agent-system-evals](https://github.com/netresearch/agent-system-evals)
on `claude-haiku-4-5-20251001`, each on the case that motivated it, each against
an unchanged control arm.

| lever | what it changes | measured |
| --- | --- | --- |
| a reference file the skill ships | the right content is reachable | no change — 3 of 3 trials loaded the skill, none opened the file |
| a step in the skill's workflow | the skill instructs the agent | no change — the sentence was in context in every trial |
| a checkpoint in the skill's own validator | the skill checks the work | no change — the check was never run |
| the skill's `description`, words appended to its trigger list | whether the skill is loaded at all | no change — 0 of 6 against 1 of 6, Fisher p 1.000 |

The fourth is the one that surprises people, because a `description` is not
advice to an agent, it is routing metadata. Appending the exact artefacts a
request is about to its trigger list did not get the skill reached for.

**Then the same words were moved, and that did.** A second run changed nothing
but where the artefacts are named — out of the `Also triggers on:` tail and into
the opening `Use when` clause, thirty-five words earlier, with nothing removed:

| where the description names them | skill loaded | Fisher p |
| --- | --- | --- |
| appended to the trigger list | 1 of 6 | 1.000 |
| in the opening clause | **6 of 6** | **0.002** |

So a `description` routes, and position inside it is load-bearing.

**What does not follow — and was published here for a few hours — is a rule for
predicting it.** The first version of this section said a skill is reached when
the words the request itself uses appear in the opening clause. Checked against
every silent case in that benchmark rather than the two it was read from, five
of six have exactly that overlap and none of them route: a skill describing
TYPO3 *upgrades* shares "extensions, typo3, versions" with a request about
version declarations; a request opening *"Someone from the security side says…"*
sat beside a security skill in its own fleet for five trials; a modernization
skill shares "property" with a request about properties that cannot be
persisted. All zero.

What the two positive runs have in common is narrower than shared vocabulary:
the opening clause named **the action the request asks to perform**, in the
request's own terms. "Prepare the 2.4.2 release" against *"Use when creating
releases, version bumps, tagging"*; "which TYPO3 versions does it say it
supports, and the statements disagree" against an opening clause naming exactly
that. Neither `typo3-extension-upgrade` nor `security-audit` describes the action
that was asked for, however many of its nouns they share.

And one of those two positives is close to circular — that clause was written
from the request by the person running the experiment, so its matching is not a
discovery. The release case is the clean one: a published skill, written without
the benchmark in view, whose first clause names the request's verb.

**For a harness review, that means one usable instruction and no test.** Read a
skill's first sentence against the actions its users actually ask for, in their
words rather than yours, and rewrite it if it names a category instead of an
action. The 1-of-6-to-6-of-6 move above is the demonstration that rewriting
one can change reach at all; it is not evidence that this particular reading
predicts it, because that clause was written from the request. Do not treat any
of this as a predictor: nothing measured here lets you look at a fleet and a
request and say in advance whether a skill will be reached.

**What did work was composition.** The same benchmark added one skill to a fleet
— `github-release-skill`, whose description names the noun in the request — and
invocation went from **0 of 6 to 6 of 6, Fisher exact p 0.002**. An agent
offered a skill that matches the request reaches for it reliably. An agent not
offered one cannot be talked into it by any wording elsewhere.

**And being reached is not being obeyed.** In those same six trials the skill
loaded every time and the mechanical outcome stayed at 0 of 6, exactly as it was
without the skill. The release was not prepared correctly in a single run.

Three rules follow, and they are why this document exists:

1. **A rule that must hold gets a mechanism from the table below, not a
   sentence in a skill.** If it can be checked by a script, it belongs in a
   hook and in CI. Prose is how an agent is *offered* a way to do the job; it
   is not how the job is *required* to come out.
2. **A skill's opening clause is its routing surface.** Everything after it
   was measured to carry far less. Review the first sentence of a
   `description` against the *actions* its users ask for, phrased their way,
   and treat a trigger list as documentation rather than as reach. This is an
   instruction for writing one, not a test for predicting reach — sharing the
   request's nouns is measurably not enough.
3. **A capability that is not installed cannot be routed to.** Before
   concluding that an agent ignored a skill, check that the skill was in the
   fleet at all — three published results in that benchmark had to be corrected
   after that check was finally made.

## CI / Hook Parity Principle

The single most load-bearing rule across the repo-level mechanisms (1-10): **every fast, deterministic check that runs in CI must also run as a pre-commit hook.** CI is the slow, parallel, authoritative backstop. It is not the first feedback loop. When a contributor (human or agent) commits broken code and learns about it 90 seconds later from a CI failure rather than 2 seconds earlier from a pre-commit hook, the harness has a gap — even if every CI gate is correctly configured.

The corollary: when CI catches a mechanical issue that a hook could have caught, the absence of the hook is the bug. Strengthen the harness rather than asking the operator to be more careful.

### What counts as a fast check

A check qualifies for the hook layer if it:

- Completes in under ~5 seconds on a typical commit on the contributor's machine
- Is deterministic (same input → same result, no flakes)
- Has no external dependencies that the commit machine cannot satisfy (no remote API calls, no Docker pulls)
- Operates on the working tree or staged changes, not on a matrix of environments

Examples: linters, formatters, type-checkers, schema validators, AST-based static analysis, file-shape validators (e.g. SKILL.md word count, YAML well-formedness).

Examples that do NOT qualify and should stay CI-only: full test suites, mutation testing, security scanners with remote feeds, multi-version matrices, container builds, integration tests against live services.

### Stack-native framework choice

Pick the hook framework the ecosystem already expects, not the one you personally prefer:

| Stack | Default framework | Why |
| ------- | ------------------- | ----- |
| PHP | `captainhook/captainhook` | Composer-installable, integrates with `composer install` |
| Go (binary-shipping projects) | `lefthook` | Single static binary, no runtime dependency, fast |
| Node-heavy frontends | `husky` + `lint-staged` | Ecosystem-native, integrates with `npm prepare` |
| Python / skill repos / mixed | `pre-commit` | Canonical Python-world tool; huge ecosystem of pre-built hooks with `repo:`+`rev:` pinning that Renovate/Dependabot bumps automatically; runs each hook in an isolated language env so contributor PATH doesn't matter |
| Shell-only / minimal | direct `.githooks/` + `.envrc` | Zero dependencies, see mechanism #3 |

For **skill repos specifically**, prefer `pre-commit` over `lefthook` even though both work: skill repos contain Python helper scripts, contributors usually already have Python tooling (uv, ruff, validation scripts), and the upstream tools the validation pipeline depends on (`markdownlint-cli2`, `yamllint`, `actionlint`, `ruff`, `shellcheck`) all ship `.pre-commit-hooks.yaml` definitions that can be pinned by `rev:` and updated by dependency bots. See this repo's `.pre-commit-config.yaml` as the reference shape.

The framework choice is secondary to the principle. What matters is that **the local set is a subset of the CI set** — never a separate pipeline that drifts.

### How parity fails in practice

Most parity gaps follow one of three patterns:

1. **CI added a check, hook never updated.** New linter, new validator, new format rule — wired into CI, forgotten locally.
2. **Hook framework exists but is hollow.** `lefthook.yml` is present and runs `echo "lint"`, but the actual `composer lint` / `go vet` / `validate-skill.sh` invocation lives only in CI.
3. **Hook bypassed by default.** Contributors run `git commit --no-verify` because some hook step is slow or flaky. The fix is to make that step fast (or move it to `pre-push` / CI), not to tolerate the bypass.

Audit periodically: for each command line in CI workflows that meets the "fast check" definition above, grep the hook config files. If the command is not represented, that is the harness gap.

## Calibrating a check before you ship it

The parity principle above pushes toward more gates. This section is its
counterweight: a gate that is *wrong* is worse than the gap it was meant to
close, because a gap is visible and a wrong gate is not.

**A false reject silently disables a real check.** In a warning-only gate a
missed case costs a warning nobody read. In a denying gate a false positive
blocks legitimate work, and what happens next is either that someone disables
the gate or that the blocked check simply reports failure forever and stops
being read. One hardening pass on a shell-command allowlist rejected four
legitimate checks this way — including one that searched a project for the very
attack the allowlist existed to stop. Every one of them had reported `fail` on
every run since.

So state **both** error directions before shipping, not just the one that
motivated the work:

- what the incident that prompted the check scores, and
- what the loudest *legitimate* input scores.

A denying gate's threshold belongs where the negative corpus is silent, not at
the edge of the positive one.

**Say how the corpus was assembled.** A "no regressions across N inputs" number
is evidence only if someone else can reproduce it, and a corpus built by a
convenient extraction usually is not the population the gate will meet. One such
claim — "0 verdict changes across 274 patterns" — turned out to count lines
produced by splitting multi-line YAML block scalars, text the runtime never
executes as a command. The real corpus was 230 unique single-line patterns, and
the correction had to be published after the fact. Write down the extraction
command next to the number.

**A predicate shared by two tools must not read ambient state.** An
authoring-time validator and a runtime gate that apply "the same rule" only
agree while that rule is a pure function of its input. Tokenizing a string with
shell globbing left enabled made one predicate consult the working directory —
so the same input was accepted in the author's checkout and rejected in the
project under test, which is precisely the divergence a shared implementation
exists to prevent. Audit a shared predicate for reads of cwd, environment,
clock, network and filesystem; a check that answers differently in two places is
not one rule, it is two.

**A documented gap beats a wrong guard.** When closing a case would cost more
false rejects than the case is worth, record it — in the checker itself, next to
the rule it qualifies — rather than shipping an approximation that reads as
coverage. Note what was tried and what it broke, so the next reader re-opens the
question with the measurement rather than the intuition.

## Mechanism Summary

| # | Mechanism | Triggers | Affects | Strength |
| --- | ----------- | ---------- | --------- | ---------- |
| 1 | Branch Protection / Rulesets | Merge attempt | Everyone | Hard |
| 2 | CI Workflows | PR push | Everyone | Hard |
| 3 | Git Hooks | Commit / push | Local devs | Automatic |
| 4 | .envrc (direnv) | `cd` into repo | Local devs with direnv | Automatic |
| 5 | Composer post-install-cmd | `composer install` | PHP devs | Automatic |
| 6 | npm prepare script | `npm install` | Node devs | Automatic |
| 7 | Makefile / justfile | Manual invocation | Everyone | Soft |
| 8 | AGENTS.md | Agent session start | AI agents | Soft |
| 9 | PR Templates | PR creation | PR authors | Soft |
| 10 | pre-commit framework | Commit (after install) | Local devs | Automatic |
| 11 | Claude Code agent hook | Every tool call | AI agents on one machine | Automatic |

## Detailed Mechanisms

### 1. Branch Protection / Rulesets

**What it is:** GitHub server-side rules that block merging unless required conditions are met.

**When it triggers:** On merge attempt (merge button, API merge call, `gh pr merge`).

**Who it affects:** Everyone -- humans, agents, CI bots. No bypass without admin override.

**Strength:** Hard. Server-side enforcement cannot be circumvented locally.

**Setup:**

- Configure via GitHub UI: Settings > Branches > Branch protection rules, or Settings > Rules > Rulesets.
- Configure via API: `gh api repos/OWNER/REPO/branches/main/protection -X PUT`.
- Configure via `github-project-skill`: delegates branch protection setup.

**Key configuration:** Add `harness-verify` as a required status check. This means the CI workflow from mechanism 2 must pass before any PR can merge.

**Limitations:** Requires repository admin access. Does not provide fast local feedback.

**GitLab equivalent:**

- Configure via GitLab UI: Settings > Repository > Protected branches, or Settings > Merge requests > Merge checks.
- Configure via API: `glab api projects/:id/protected_branches`.
- Add `harness-verify` as a required pipeline job. Under Settings > Merge requests, enable "Pipelines must succeed".

---

### 2. CI Workflows

**What it is:** A GitHub Actions workflow (`.github/workflows/harness-verify.yml`) that runs `verify-harness.sh` on every pull request.

**When it triggers:** On every PR push event. Can also trigger on `push` to specific branches.

**Who it affects:** Everyone. CI runs regardless of contributor setup.

**Strength:** Hard (when combined with branch protection). Automatic (standalone -- visible but not blocking).

**Setup:**

Copy or generate the workflow from `templates/harness-verify.yml.tmpl`:

```yaml
name: Harness Verify
on:
  pull_request:
    branches: [main]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify harness
        run: bash scripts/verify-harness.sh --level=2
```

The workflow uses only `actions/checkout` and bash -- no external action dependencies.

**Reports:** Results appear as GitHub Actions annotations (`::error::`, `::warning::`) visible on the PR Files Changed tab.

**Limitations:** Requires a round-trip to CI. Local feedback is faster via hooks.

**GitLab equivalent:**

A GitLab CI job in `.gitlab-ci.yml` that runs `verify-harness.sh` on every merge request:

```yaml
harness-verify:
  stage: test
  script:
    - bash scripts/verify-harness.sh --level=2 --format=gitlab
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

Results appear in the job log. GitLab does not have inline file annotations, but the structured output is visible in the pipeline job output.

---

### 3. Git Hooks

**What it is:** Local scripts in `.githooks/` that run before commits (`pre-commit`) and before pushes (`pre-push`).

**When it triggers:** `pre-commit` runs before every `git commit`. `pre-push` runs before every `git push`.

**Who it affects:** Local developers who have hooks activated. Does not affect CI or web-based edits.

**Strength:** Automatic (once activated). Can be bypassed with `git commit --no-verify`.

**Setup:**

```bash
# Activate hooks for this repo
git config core.hooksPath .githooks

# Or system-wide
git config --global core.hooksPath .githooks
```

Hooks should call `verify-harness.sh`:

```bash
#!/usr/bin/env bash
# .githooks/pre-commit
bash scripts/verify-harness.sh --level=1 --format=text
```

**Limitations:** Requires activation. Bypassable with `--no-verify`. This is why the hard layer (CI + branch protection) exists as a backstop.

---

### 4. .envrc (direnv)

**What it is:** A direnv configuration file that activates automatically when a developer enters the repository directory.

**When it triggers:** On `cd` into the repo directory (if direnv is installed and allowed).

**Who it affects:** Local developers with direnv installed.

**Strength:** Automatic. Silent activation -- no manual step required after initial `direnv allow`.

**Setup:**

```bash
# .envrc
# Activate git hooks
git config core.hooksPath .githooks

# Add project scripts to PATH
PATH_add scripts
PATH_add bin
```

After creating `.envrc`, a developer entering the directory for the first time sees:

```text
direnv: error .envrc is blocked. Run `direnv allow` to approve its content
```

After running `direnv allow`, all subsequent directory entries silently activate the configuration.

**Limitations:** Requires direnv installed. First-time `direnv allow` is a manual step. Not available in CI (not needed -- CI has its own workflow).

---

### 5. Composer post-install-cmd

**What it is:** A Composer lifecycle hook that runs after `composer install` or `composer update`.

**When it triggers:** After dependency installation in PHP projects.

**Who it affects:** PHP developers using Composer.

**Strength:** Automatic. Transparent to the developer -- hooks install as a side effect of normal workflow.

**Setup:**

Add to `composer.json`:

```json
{
  "scripts": {
    "post-install-cmd": [
      "git config core.hooksPath .githooks || true"
    ],
    "post-update-cmd": [
      "git config core.hooksPath .githooks || true"
    ]
  }
}
```

The `|| true` ensures the script does not fail in environments without git (CI Docker containers, production deploys).

**Limitations:** PHP/Composer projects only. Does not work for contributors who skip `composer install`.

---

### 6. npm prepare Script

**What it is:** An npm lifecycle script that runs after `npm install`.

**When it triggers:** After dependency installation in Node projects.

**Who it affects:** Node developers using npm/yarn/pnpm.

**Strength:** Automatic. Transparent to the developer.

**Setup (direct):**

```json
{
  "scripts": {
    "prepare": "git config core.hooksPath .githooks || true"
  }
}
```

**Setup (with Husky):**

```json
{
  "scripts": {
    "prepare": "husky"
  }
}
```

Then configure Husky hooks to call `verify-harness.sh`.

**Limitations:** Node projects only. Does not work if `--ignore-scripts` is used.

---

### 7. Makefile / justfile

**What it is:** A build automation target that runs harness verification on demand.

**When it triggers:** Manual invocation (`make verify-harness` or `just verify-harness`).

**Who it affects:** Everyone who can run make/just. Language-agnostic.

**Strength:** Soft. Requires the contributor to know about and choose to run it.

**Setup:**

```makefile
.PHONY: verify-harness
verify-harness:
 bash scripts/verify-harness.sh --format=text

.PHONY: bootstrap-harness
bootstrap-harness:
 @echo "Run agent-harness:bootstrap via your agent framework"

.PHONY: harness-status
harness-status:
 bash scripts/verify-harness.sh --format=text --level=3 || true
```

**Advantages:** Works in any project regardless of language or package manager. Discoverable via `make help` or reading the Makefile. Can be called by CI workflows.

**Limitations:** Requires manual invocation. Not enforced.

---

### 8. AGENTS.md

**What it is:** A markdown file at the repo root read by AI agents at the start of every session.

**When it triggers:** Agent session start. Claude Code, OpenAI Codex, GitHub Copilot, Gemini CLI, and other agents look for this file automatically.

**Who it affects:** AI agents. Humans can read it but it is optimised for agent consumption.

**Strength:** Soft. Convention-based. The agent reads it but is not mechanically forced to comply.

**Setup:**

Create `AGENTS.md` at the repo root following the index format (see ADR-004). Keep it under 150 lines. Reference detailed documentation in `docs/` rather than inlining it.

```markdown
# AGENTS.md

## Repo Structure
- `src/` -- application source
- `docs/` -- documentation (ARCHITECTURE.md, ADRs, design docs)
- `scripts/` -- automation scripts

## Commands
- `make build` -- build the project
- `make test` -- run all tests
- `make verify-harness` -- verify harness consistency

## Rules
- Follow conventional commits
- All new subsystems must be documented in ARCHITECTURE.md
```

**Limitations:** No mechanical enforcement. An agent can ignore instructions. This is why CI and hooks exist as harder layers.

---

### 9. PR Templates

**What it is:** A GitHub pull request template (`.github/pull_request_template.md`) that pre-fills the PR description with a checklist.

**When it triggers:** PR creation via GitHub UI or `gh pr create`.

**Who it affects:** PR authors. Visible reminder during PR creation.

**Strength:** Soft. Reminder only -- unchecked items do not block merge.

**Setup:**

Create `.github/pull_request_template.md`:

```markdown
## Changes

<!-- Describe your changes -->

## Harness Checklist

- [ ] AGENTS.md updated (if commands or structure changed)
- [ ] docs/ updated (if architecture or design changed)
- [ ] New subsystems documented in ARCHITECTURE.md
- [ ] Exec plan created (if multi-file structural change)
```

**Limitations:** Reminder, not enforcement. Contributors can delete the template text. No merge blocking.

**GitLab equivalent:**

GitLab uses merge request templates stored in `.gitlab/merge_request_templates/`:

```markdown
<!-- .gitlab/merge_request_templates/Default.md -->
## Changes

<!-- Describe your changes -->

## Harness Checklist

- [ ] AGENTS.md updated (if commands or structure changed)
- [ ] docs/ updated (if architecture or design changed)
- [ ] New subsystems documented in ARCHITECTURE.md
- [ ] Exec plan created (if multi-file structural change)
```

The `Default.md` template is automatically applied to new merge requests. Additional named templates can coexist in the same directory.

---

### 10. pre-commit Framework

**What it is:** A multi-language hook manager that standardises git hook setup via `.pre-commit-config.yaml`.

**When it triggers:** On commit (after `pre-commit install` has been run).

**Who it affects:** Local developers who have run `pre-commit install`.

**Strength:** Automatic (once installed). Bypassable with `--no-verify`.

**Setup:**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: verify-harness
        name: Verify harness consistency
        entry: bash scripts/verify-harness.sh --level=1 --format=text
        language: system
        pass_filenames: false
        always_run: true
```

Then: `pre-commit install`

**Advantages:** Standardised hook management. Easy to add additional hooks (linting, formatting). Supports auto-update of hook versions.

**Limitations:** Requires `pre-commit` installed (`pip install pre-commit`). Requires `pre-commit install` to be run once. Bypassable with `--no-verify`.

### 11. Claude Code Agent Hook

**What it is:** A `PreToolUse` / `Stop` hook wired into `~/.claude/settings.json`, run by the Claude Code harness before every matching tool call. It reads the tool payload on stdin and answers on stdout.

**When it triggers:** On every tool call the `matcher` selects — before the tool runs, so it can block.

**Who it affects:** AI agents on the machine where it is installed. Not teammates, and not CI.

**Strength:** Automatic and unbypassable *by the agent* — unlike every other mechanism here, there is no `--no-verify` equivalent the agent can reach for.

**When to reach for it:** Mechanisms 1-10 gate a *repo*. This one gates the *agent*, so it is the right instrument for a rule the agent keeps violating across every repo — where a per-repo hook would have to be installed everywhere and would still miss commands run outside any repo.

**Setup:**

```jsonc
// ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "python3 $HOME/.claude/hooks/my-gate.py" }] }
    ]
  }
}
```

The script exits 0 always; the *verdict* is the JSON it prints. Silence means allow:

```python
# block, with a reason the agent reads
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "<what to do instead>"}}))

# advisory only — surfaces in the transcript, does not block
print(json.dumps({"systemMessage": "...", "suppressOutput": True}))
```

**Escalate advisory to deny when the nudge is ignored.** Ship a rule as `systemMessage` first and let it run for a few sessions. If the transcript shows the nudge firing correctly and the behaviour continuing anyway, that is the evidence for promoting it to `deny` — the rule is not unclear, it is unenforced. Two rules in this author's own hook took that path after a retro counted the violations.

**Write the deny reason for the reader, and name what it does *not* block.** A gate that blocks a legitimate variant with no stated escape sends the agent hunting for a workaround. State the allowed forms explicitly.

**Test it directly — the hook is a pure function of its payload:**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"<cmd>"},"cwd":"/tmp"}' \
  | python3 ~/.claude/hooks/my-gate.py
```

Keep a table of `(command, expected verdict)` cases and run them after every edit. Beware the self-match trap: a test *command* containing the pattern trips the agent's own gate, so keep cases in a file rather than inline in the shell.

**Derive the negative cases from the guarded resource's stated purpose, not from
your own sense of what looks legitimate.** A table you invent covers the shapes
you thought of; the one shape you forget is the one that fires on a colleague
the same afternoon. Whatever document defines the thing you are gating — the
AGENTS.md paragraph, the reference section, the ADR — usually states what it is
*for*, in a sentence adjacent to the rule you are enforcing. Read that sentence
and turn every clause of it into a negative case.

Worked example: a gate that refuses git writes inside a bare-layout `main/`
worktree shipped with six negative cases and blocked its own author's
`git merge --ff-only origin/main` within the hour. The rule and the purpose sat
in the same reference file — *"exists for reading code, running `git fetch`, and
serving as the base for new worktrees"* — and *serving as a base* entails being
current, which entails the refresh. Three clauses, three negative cases; two had
been guessed, the third had not.

The discriminator is worth stating in the gate itself: `merge --ff-only` was
exempted while `reset --hard` stayed refused, because the first cannot create a
commit or discard work and the second reaches the same state by discarding.

**Advantages:** Reaches every repo and every session on the machine. Catches commands no repo hook sees. Deny reasons are read by the agent, so the fix propagates immediately.

**Limitations:** Reach is one machine, one user — it is not shared with teammates and cannot replace a CI check or branch protection for anything humans also do. Pair it with a repo-level mechanism whenever humans can trip the same rule. Pattern-matching on shell strings has false positives; prefer a narrow regex plus an explicit allowlist of legitimate shapes.

## The Activation Chain

This diagram shows how enforcement mechanisms activate in sequence during a typical development workflow:

```text
Developer clones repo
  |
  +---> .envrc detected by direnv
  |       +---> git config core.hooksPath .githooks
  |       +---> scripts/ added to PATH
  |
  +---> composer install / npm install
  |       +---> post-install-cmd / prepare script
  |       +---> git hooks confirmed active
  |
  +---> Developer makes changes, runs git commit
  |       +---> .githooks/pre-commit runs
  |       +---> verify-harness.sh --level=1 (fast check)
  |       +---> Commit succeeds or fails with feedback
  |
  +---> Developer runs git push
  |       +---> .githooks/pre-push runs
  |       +---> verify-harness.sh --level=2 (full check)
  |       +---> Push succeeds or fails with feedback
  |
  +---> PR/MR created
  |       +---> PR/MR template pre-fills harness checklist
  |       +---> CI workflow/pipeline triggers
  |       +---> verify-harness.sh runs in CI
  |       +---> Results reported as annotations (GitHub) or job log (GitLab)
  |
  +---> Merge attempted
          +---> Branch protection checks required status
          +---> harness-verify must be green
          +---> Merge succeeds or is blocked
```

Each layer catches issues that earlier layers missed or that bypassed them. The chain is designed so that the last layer (branch protection) is impossible to bypass without admin access.

## Choosing Mechanisms for Your Project

### Minimum (any project)

- AGENTS.md (mechanism 8)
- CI workflow (mechanism 2)
- Makefile target (mechanism 7)

This is the Level 1 baseline. Works for any language, any team size.

### PHP project

All of the minimum, plus:

- Composer post-install-cmd (mechanism 5)
- .envrc (mechanism 4)
- Git hooks (mechanism 3)

### Node project

All of the minimum, plus:

- npm prepare script (mechanism 6)
- Husky or direct hooks (mechanism 3)
- .envrc (mechanism 4)

### Go project

All of the minimum, plus:

- .envrc (mechanism 4)
- Makefile targets (mechanism 7 -- Go projects already use Make heavily)
- Git hooks (mechanism 3)

### Maximum (Level 3)

All mechanisms active:

- Branch protection with `harness-verify` as required check (mechanism 1)
- CI workflow (mechanism 2)
- Git hooks via .githooks/ (mechanism 3)
- .envrc for automatic activation (mechanism 4)
- Language-specific auto-setup (mechanism 5 or 6)
- Makefile targets (mechanism 7)
- AGENTS.md as index (mechanism 8)
- PR template with harness checklist (mechanism 9)
- pre-commit framework (mechanism 10, optional -- overlaps with direct hooks)
