# Skill Integration Map

The agent-harness skill does not operate in isolation. It delegates specialised work to other skills in the ecosystem and verifies that the output of those skills meets harness requirements. This document defines the integration contract for each skill.

## Integration Principle

The harness skill checks artefacts, not tools. It verifies that the OUTPUT of delegated skills is present and consistent. It does not require the delegated skill to be installed. A team that creates AGENTS.md manually gets the same verification as a team that used agent-rules-skill to generate it.

This means:

- The harness skill never imports or calls another skill's code directly.
- Integration is through shared file conventions (AGENTS.md, ARCHITECTURE.md, CI workflows).
- Verification works on any repo, regardless of which skills were used to set it up.

## Skill Integration Details

### 1. agent-rules-skill

**What it provides:** Generates AGENTS.md content following best practices for agent-readable repository documentation.

**When harness delegates to it:** When AGENTS.md needs to be created (bootstrap mode) or updated (after structural changes). The harness skill invokes agent-rules when it detects AGENTS.md is missing or when a user explicitly requests AGENTS.md generation.

**What harness expects back:**

- An `AGENTS.md` file at the repo root.
- Index format: compact, under 150 lines.
- Contains at minimum: repo structure section, commands section, rules section.
- References external documentation in `docs/` rather than inlining detail.

**What harness verifies:**

- `AGENTS.md` exists (checkpoint AH-01).
- `AGENTS.md` is under 150 lines (checkpoint AH-02).
- `AGENTS.md` contains a commands section (checkpoint AH-03).
- All file references in `AGENTS.md` resolve to existing files (checkpoint AH-10).

---

### 2. github-project-skill / GitLab project settings

**What it provides:** Configures platform features: branch protection rules, PR/MR templates, CODEOWNERS/code owners, repository settings, label schemas.

**Platform notes:**

- **GitHub:** Delegates to `github-project-skill` for branch protection and PR template setup.
- **GitLab:** No equivalent skill exists yet. Configure branch protection and merge request settings manually via GitLab UI (Settings > Repository > Protected branches, Settings > Merge requests).

**When harness delegates to it (GitHub):** When Level 3 enforcement needs to be set up on GitHub, the harness skill delegates branch protection configuration and PR template creation to `github-project-skill`. On GitLab, the harness does not delegate these actions; it only verifies that branch protection and merge request templates have been configured manually as described above.

**What harness expects back:**

- Branch protection rule on the default branch with `harness-verify` as a required status/pipeline check.
- PR template at `.github/pull_request_template.md` (GitHub) or MR template at `.gitlab/merge_request_templates/Default.md` (GitLab).
- CODEOWNERS file if the project has designated maintainers.

**What harness verifies:**

- PR template exists (checkpoint AH-20).
- `harness-verify` is listed as a required status check (verified via `gh api`, not by file inspection).
- PR template contains harness-related checklist items.

---

### 3. enterprise-readiness-skill

**What it provides:** Quality gates, SLSA provenance configuration, SBOM generation, OpenSSF Scorecard integration, supply chain security setup.

**When harness delegates to it:** When assessing production-readiness of a repository. The harness skill does not directly invoke enterprise-readiness but references it when a repo needs to move beyond harness maturity into production-readiness concerns.

**What harness expects back:**

- Quality gate configuration in CI workflows.
- Security scanning enabled (dependency review, CodeQL, or equivalent).
- SLSA provenance configured for releases.

**What harness verifies:**

- Quality gate workflows exist (informational -- not a harness checkpoint).
- The harness skill reports enterprise-readiness as a separate concern, not a harness maturity requirement.

---

### 4. typo3-testing-skill

**What it provides:** Test infrastructure for TYPO3 extensions: PHPUnit configuration, functional test setup, CI test matrix, code coverage configuration.

**When harness delegates to it:** When the target repo is a TYPO3 extension and test infrastructure needs setup. The harness skill detects TYPO3 extensions by the presence of `ext_emconf.php` or TYPO3-specific composer types.

**What harness expects back:**

- Test commands defined in `composer.json` scripts (e.g., `ci:test:php:unit`, `ci:test:php:functional`).
- Test commands documented in AGENTS.md.
- CI workflow that runs tests.

**What harness verifies:**

- Documented test commands in AGENTS.md match actual `composer.json` script definitions (checkpoint AH-11).
- CI workflow exists and references the test commands.

---

### 5. go-development-skill

**What it provides:** Go application patterns, test infrastructure, linting configuration (golangci-lint), Makefile targets for Go projects.

**When harness delegates to it:** When the target repo is a Go project (detected by `go.mod`). Same delegation pattern as typo3-testing but for Go.

**What harness expects back:**

- Test commands defined as Makefile targets (e.g., `make test`, `make lint`).
- Test commands documented in AGENTS.md.
- CI workflow that runs Go tests and linting.

**What harness verifies:**

- Documented `make` targets in AGENTS.md match actual Makefile targets (checkpoint AH-11).
- CI workflow exists and runs tests.

---

### 6. git-workflow-skill

**What it provides:** Commit conventions, branching strategy, git hooks, changelog generation, release workflow patterns.

**When harness delegates to it:** When git workflow setup is needed (hooks, commit message format, branching rules). The harness skill delegates hook content and commit format rules to git-workflow-skill.

**What harness expects back:**

- Git hooks configured in `.githooks/` directory.
- Commit format defined (conventional commits or project-specific).
- Hooks documented in AGENTS.md rules section.

**What harness verifies:**

- `.githooks/` directory exists with executable hooks (checkpoint AH-21 -- partial).
- Hook auto-activation is configured via `.envrc`, composer, or npm (checkpoint AH-21).
- Commit format rules are documented in AGENTS.md.

---

### 7. concourse-ci-skill

**What it provides:** Concourse CI pipeline definitions, task configurations, resource types.

**When harness delegates to it:** When the target repo uses Concourse CI instead of or alongside GitHub Actions. The harness skill detects Concourse by the presence of `ci/` or `concourse/` directories with pipeline YAML files.

**What harness expects back:**

- Pipeline definition files in a standard location.
- CI commands documented in AGENTS.md.

**What harness verifies:**

- Documented CI commands match pipeline task definitions (checkpoint AH-11 -- adapted for Concourse).
- If both GitHub Actions and Concourse are present, both are documented.

---

### 8. docker-development-skill

**What it provides:** Docker setup, docker-compose configuration, multi-stage build patterns, development environment containerisation.

**When harness delegates to it:** When Docker-based development setup is needed. The harness skill does not directly manage Docker configuration but verifies that Docker commands are documented.

**What harness expects back:**

- Docker commands documented in AGENTS.md (e.g., `docker compose up`, `make docker-build`).
- `docker-compose.yml` or equivalent present if referenced.

**What harness verifies:**

- Documented Docker commands reference files that exist (checkpoint AH-10 -- general reference check).
- Docker-related commands in AGENTS.md match actual compose file service definitions (best-effort).

---

### 9. automated-assessment-skill

**What it provides:** Checkpoint-based audit system. Reads `checkpoints.yaml` from skills and evaluates them mechanically against a target repository.

**When harness delegates to it:** The relationship is inverted -- automated-assessment reads the harness skill's checkpoints, not the other way around. The harness skill provides `checkpoints.yaml` that defines what to check; automated-assessment provides the runtime that evaluates those checks.

**What harness provides to it:**

- `checkpoints.yaml` with maturity-level checks (AH-01 through AH-21).
- Preconditions (must be a git repository).
- Severity levels (error vs. warning) for each checkpoint.

**What harness expects back:**

- Assessment results in structured format (pass/fail per checkpoint).
- Maturity level determination (Level 1/2/3 based on which checkpoints pass).

**What harness verifies:** N/A -- automated-assessment is the verifier, not the verified.

### Integration Rule: Assessment Before Enhancement

When any quality-related skill is invoked to ENHANCE (not just verify) a project's quality posture, the automated-assessment skill MUST run first. This applies to:

- `typo3-testing` invoked with "enhance", "improve", "strengthen"
- `enterprise-readiness` invoked with "audit", "production ready"
- `php-modernization` invoked with "upgrade", "modernize"
- `security-audit` invoked with "audit", "scan", "review"

The assessment generates a structured gap report from checkpoints. This report becomes the task list, preventing iterative manual discovery of issues that checkpoints would catch automatically.

**The harness enforces this through AH-30..AH-35**: if quality infrastructure is missing, the harness flags it before any enhancement work begins.

---

### 10. superpowers (writing-plans, executing-plans)

**What it provides:** Plan lifecycle management. Writing-plans creates structured execution plans; executing-plans tracks and executes them step by step.

**When harness delegates to it:** When the harness detects a complex change that should be planned before execution. The harness skill recommends plan creation for multi-file structural changes.

**What harness expects back:**

- `docs/superpowers/plans/` directory exists if the project uses plans.
- Active plans are tracked with checkbox syntax.

**What harness verifies:**

- If `docs/superpowers/plans/` is referenced in AGENTS.md, the directory exists (checkpoint AH-10 -- general reference check).
- Plan template is available for bootstrap mode (`templates/exec-plan.md.tmpl`).

---

### 11. skill-repo-skill

**What it provides:** Defines the structure of a *skill* repository: `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, split licensing (MIT + CC-BY-SA-4.0), release workflows, composer integration.

**When harness applies alongside it:** Skill repos benefit from both layers: `skill-repo-skill` verifies skill-specific structure (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `composer.json` conventions) via its own `validate-skill.sh`; harness layers generic agent-readiness on top (`AGENTS.md` as index, `docs/` structure, `.github/workflows/harness-verify.yml`). The two verifiers don't overlap — they target different artefacts.

**What harness expects back:**

- An `AGENTS.md` index for the skill repo.
- The standard harness workflows (`harness-verify.yml`).

**What harness verifies in skill repos:**

- The same generic harness checkpoints apply as for any other repo (`AH-01` `AGENTS.md` exists, `AH-02` line count, `AH-12` `harness-verify.yml` exists). Skill-specific structural validation is left to `skill-repo-skill`'s own `validate-skill.sh`.

## Integration Flow Diagram

```
                    agent-harness (verify / bootstrap / audit)
                    |
        +-----------+-----------+------------------+
        |           |           |                  |
   [Verify]    [Bootstrap]  [Audit]           [Delegate]
        |           |           |                  |
        v           v           v                  v
  verify-harness.sh  templates/   checkpoints.yaml   Other skills
        |           |           |                  |
        |           |           |        +---------+---------+
        |           |           |        |         |         |
        |           |           |   agent-rules  github-  git-workflow
        |           |           |   (AGENTS.md)  project  (hooks)
        |           |           |                (branch
        |           |           |                protection)
        |           |           |
        +-----+-----+----------+
              |
              v
         Artefact checks
    (files exist, refs resolve,
     commands match targets)
```

The harness skill sits at the centre, delegating creation to specialised skills and verifying the output. The verification layer works independently of which skill created the artefacts.
