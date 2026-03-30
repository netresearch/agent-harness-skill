# GitLab CI/CD Platform Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the agent-harness skill platform-aware so it correctly verifies and bootstraps repos hosted on GitHub OR GitLab.

**Architecture:** Add a `--platform=github|gitlab` flag with auto-detection fallback. The verify script detects the platform from CI env vars (`$GITHUB_ACTIONS`, `$GITLAB_CI`) and git remote URL patterns. CI annotation output, workflow file checks, and MR/PR template checks branch on the detected platform. Templates gain GitLab equivalents alongside existing GitHub ones.

**Tech Stack:** Bash (verify script), YAML (CI templates, checkpoints), Markdown (docs, templates)

---

### Task 1: Platform detection in verify-harness.sh

**Files:**
- Modify: `skills/agent-harness/scripts/verify-harness.sh:10-64`

**Step 1: Add PLATFORM global and --platform flag**

Add after the existing globals block (line 15) and extend the argument parser:

```bash
# After line 15 (STATUS_ONLY=false)
PLATFORM=""   # github | gitlab | "" (auto-detect)
```

Add to the `while` loop in `main()` (after the `--status)` case around line 534):

```bash
            --platform=*)
                PLATFORM="${1#--platform=}"
                if [[ ! "$PLATFORM" =~ ^(github|gitlab)$ ]]; then
                    echo "Error: --platform must be 'github' or 'gitlab'" >&2
                    exit 1
                fi
                ;;
```

**Step 2: Create detect_platform() function**

Add after `detect_format()` (after line 64):

```bash
# Detect hosting platform from CI env, git remote, or flag
detect_platform() {
    if [[ -n "$PLATFORM" ]]; then
        return
    fi
    # CI environment detection
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        PLATFORM="github"
        return
    fi
    if [[ "${GITLAB_CI:-}" == "true" ]]; then
        PLATFORM="gitlab"
        return
    fi
    # Git remote URL detection
    local remote_url=""
    remote_url=$(git remote get-url origin 2>/dev/null || true)
    if [[ "$remote_url" == *"gitlab"* ]]; then
        PLATFORM="gitlab"
    elif [[ "$remote_url" == *"github"* ]]; then
        PLATFORM="github"
    else
        # Default to github for backward compatibility
        PLATFORM="github"
    fi
}
```

**Step 3: Update detect_format() to handle GitLab CI**

Replace the existing `detect_format()` function:

```bash
detect_format() {
    if [[ -n "$FORMAT" ]]; then
        return
    fi
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        FORMAT="github"
    elif [[ "${GITLAB_CI:-}" == "true" ]]; then
        FORMAT="gitlab"
    else
        FORMAT="text"
    fi
}
```

**Step 4: Call detect_platform in main()**

Add `detect_platform` right after `detect_format` in `main()` (after line 549):

```bash
    detect_format
    detect_platform
```

**Step 5: Update usage text**

Add to the usage() function options section:

```
  --platform=P    Target platform: github or gitlab (auto-detected from
                  CI environment or git remote URL if not specified)
  --format=gitlab GitLab CI section annotations (auto-detected in CI)
```

**Step 6: Run the script with --help to verify it parses**

Run: `bash skills/agent-harness/scripts/verify-harness.sh --help`
Expected: Help text shows new `--platform` and `--format=gitlab` options

**Step 7: Commit**

```bash
git add skills/agent-harness/scripts/verify-harness.sh
git commit -m "feat: add --platform flag and auto-detection to verify-harness.sh"
```

---

### Task 2: GitLab CI annotation output format

**Files:**
- Modify: `skills/agent-harness/scripts/verify-harness.sh:17-102,470-474,584-590`

**Step 1: Add GITLAB_LINES array**

Add after the `GITHUB_LINES` declaration (line 19):

```bash
declare -a GITLAB_LINES=()
```

**Step 2: Update fail() to record GitLab annotations**

GitLab CI does not have native annotation syntax like GitHub's `::error::`. Instead, GitLab uses ANSI section markers for collapsible sections and relies on exit codes. The closest equivalent is printing clearly formatted error lines that GitLab's UI displays in the job log.

Update `fail()` to also record GitLab-formatted lines (after the GITHUB_LINES line, around line 83):

```bash
    GITLAB_LINES+=("ERROR: [Level ${level}] ${msg} (${file})")
```

**Step 3: Update warn() to record GitLab annotations**

Same pattern, after line 98:

```bash
    GITLAB_LINES+=("WARNING: [Level ${level}] ${msg} (${file})")
```

**Step 4: Add render_gitlab() function**

Add after `render_github()` (after line 474):

```bash
render_gitlab() {
    # GitLab CI uses section markers for collapsible output
    echo -e "\e[0Ksection_start:$(date +%s):harness_verify[collapsed=false]\r\e[0KAgent Harness Verification"
    for line in "${GITLAB_LINES[@]}"; do
        echo "$line"
    done
    # Summary
    echo ""
    echo "Summary: ${ERRORS} error(s), ${WARNINGS} warning(s)"
    echo -e "\e[0Ksection_end:$(date +%s):harness_verify\r\e[0K"
}
```

**Step 5: Update output routing in main()**

Replace the format conditional block (lines 584-590):

```bash
    if [[ "$STATUS_ONLY" == true ]]; then
        render_status
    elif [[ "$FORMAT" == "github" ]]; then
        render_github
    elif [[ "$FORMAT" == "gitlab" ]]; then
        render_gitlab
    else
        render_text
    fi
```

**Step 6: Test output formats**

Run: `cd /tmp && git init test-repo && cd test-repo && bash /home/psi/workspace/projects/nr-claude-code-marketplace/agent-harness-skill/skills/agent-harness/scripts/verify-harness.sh --format=gitlab 2>&1; echo "exit: $?"`
Expected: Output shows `ERROR:` prefixed lines in GitLab section format, exits non-zero

Run: `bash /home/psi/workspace/projects/nr-claude-code-marketplace/agent-harness-skill/skills/agent-harness/scripts/verify-harness.sh --format=github 2>&1; echo "exit: $?"`
Expected: Output shows `::error::` prefixed lines (existing behavior preserved)

**Step 7: Commit**

```bash
git add skills/agent-harness/scripts/verify-harness.sh
git commit -m "feat: add GitLab CI annotation output format"
```

---

### Task 3: Platform-aware CI workflow check (AH-12)

**Files:**
- Modify: `skills/agent-harness/scripts/verify-harness.sh:277-283`

**Step 1: Replace check_ci_workflow() with platform-aware version**

Replace the existing `check_ci_workflow()` function:

```bash
check_ci_workflow() {
    if [[ "$PLATFORM" == "gitlab" ]]; then
        # GitLab: look for harness-verify job in .gitlab-ci.yml
        if [[ -f ".gitlab-ci.yml" ]]; then
            if grep -q "harness-verify\|verify-harness" ".gitlab-ci.yml"; then
                pass 2 "CI harness job found in .gitlab-ci.yml"
            else
                warn 2 "CI config exists (.gitlab-ci.yml) but no harness-verify job found"
            fi
        else
            fail 2 "CI harness workflow missing -- create .gitlab-ci.yml with a harness-verify job" ""
        fi
    else
        # GitHub: existing check
        if [[ -f ".github/workflows/harness-verify.yml" ]]; then
            pass 2 "CI harness workflow exists"
        else
            fail 2 "CI harness workflow missing -- create .github/workflows/harness-verify.yml" ""
        fi
    fi
}
```

**Step 2: Test with a mock GitLab repo**

Run:
```bash
cd /tmp && rm -rf test-gl && git init test-gl && cd test-gl
touch AGENTS.md && mkdir docs
bash /path/to/verify-harness.sh --platform=gitlab --check=structure --format=text
```
Expected: FAIL mentioning `.gitlab-ci.yml`

Then:
```bash
echo "harness-verify:" > .gitlab-ci.yml
bash /path/to/verify-harness.sh --platform=gitlab --check=structure --format=text
```
Expected: PASS for CI harness job

**Step 3: Commit**

```bash
git add skills/agent-harness/scripts/verify-harness.sh
git commit -m "feat: platform-aware CI workflow check for GitHub and GitLab"
```

---

### Task 4: Platform-aware MR/PR template check (AH-20)

**Files:**
- Modify: `skills/agent-harness/scripts/verify-harness.sh:327-354`

**Step 1: Replace check_pr_template() with platform-aware version**

Replace the existing function:

```bash
check_pr_template() {
    if [[ "$PLATFORM" == "gitlab" ]]; then
        # GitLab: merge request templates in .gitlab/merge_request_templates/
        if [[ -d ".gitlab/merge_request_templates" ]]; then
            local tmpl_count
            tmpl_count=$(find .gitlab/merge_request_templates -name '*.md' 2>/dev/null | wc -l)
            if (( tmpl_count > 0 )); then
                pass 3 "MR template exists (.gitlab/merge_request_templates/, ${tmpl_count} template(s))"
                return
            fi
        fi

        # Try to detect group-level template via GitLab API (graceful fallback)
        if command -v glab &>/dev/null; then
            local project_path=""
            project_path=$(git remote get-url origin 2>/dev/null | sed -n 's|.*gitlab[^/]*/\(.*\)\.git$|\1|p; s|.*gitlab[^/]*/\(.*\)$|\1|p')
            if [[ -n "$project_path" ]]; then
                # glab doesn't have a direct MR template query, skip gracefully
                :
            fi
        fi

        warn 3 "MR template missing (create .gitlab/merge_request_templates/Default.md)"
    else
        # GitHub: existing check
        if [[ -f ".github/pull_request_template.md" ]]; then
            pass 3 "PR template exists (repo-level)"
            return
        fi

        if [[ -d ".github/PULL_REQUEST_TEMPLATE" ]]; then
            pass 3 "PR template exists (directory form)"
            return
        fi

        # Try to detect org-level template via GitHub API (graceful fallback)
        local org=""
        org=$(git remote get-url origin 2>/dev/null | sed -n 's|.*github\.com[:/]\([^/]*\)/.*|\1|p')
        if [[ -n "$org" ]]; then
            local api_result=""
            api_result=$(gh api "repos/${org}/.github/contents/pull_request_template.md" --jq '.name' 2>/dev/null || true)
            if [[ "$api_result" == "pull_request_template.md" ]]; then
                pass 3 "PR template exists (org-level via ${org}/.github)"
                return
            fi
        fi

        warn 3 "PR template missing (.github/pull_request_template.md or org-level)"
    fi
}
```

**Step 2: Test GitLab MR template detection**

Run:
```bash
cd /tmp && rm -rf test-gl && git init test-gl && cd test-gl
git remote add origin git@gitlab.example.com:group/project.git
mkdir -p .gitlab/merge_request_templates
echo "## Summary" > .gitlab/merge_request_templates/Default.md
touch AGENTS.md && mkdir -p docs
echo "## Commands" >> AGENTS.md
bash /path/to/verify-harness.sh --platform=gitlab --level=3 --format=text
```
Expected: PASS for MR template check

**Step 3: Commit**

```bash
git add skills/agent-harness/scripts/verify-harness.sh
git commit -m "feat: platform-aware MR/PR template check for GitHub and GitLab"
```

---

### Task 5: Platform-aware drift detection

**Files:**
- Modify: `skills/agent-harness/scripts/verify-harness.sh:356-395`

**Step 1: Update the drift file pattern match to include GitLab CI files**

In `check_drift()`, update the case statement (around line 381) to also detect `.gitlab-ci.yml` changes:

```bash
        case "$changed_file" in
            Makefile|composer.json|package.json|.github/workflows/*|.gitlab-ci.yml)
                build_files_changed=true
                ;;
            AGENTS.md)
                agents_changed=true
                ;;
        esac
```

**Step 2: Commit**

```bash
git add skills/agent-harness/scripts/verify-harness.sh
git commit -m "feat: include .gitlab-ci.yml in drift detection"
```

---

### Task 6: GitLab CI template

**Files:**
- Create: `skills/agent-harness/templates/gitlab-ci-harness-verify.yml.tmpl`

**Step 1: Create the GitLab CI template**

```yaml
# Agent Harness Verification job for GitLab CI
# Add this to your .gitlab-ci.yml or include it via !reference

harness-verify:
  stage: test
  image: alpine:latest
  before_script:
    - apk add --no-cache bash git coreutils
  script:
    - bash scripts/verify-harness.sh --level=2 --format=gitlab
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
  allow_failure: false
```

**Step 2: Verify YAML validity**

Run: `python3 -c "import yaml; yaml.safe_load(open('skills/agent-harness/templates/gitlab-ci-harness-verify.yml.tmpl'))" && echo OK`
Expected: `OK`

**Step 3: Commit**

```bash
git add skills/agent-harness/templates/gitlab-ci-harness-verify.yml.tmpl
git commit -m "feat: add GitLab CI harness-verify job template"
```

---

### Task 7: GitLab MR template

**Files:**
- Create: `skills/agent-harness/templates/merge_request_template.md.tmpl`

**Step 1: Create the GitLab MR template**

The content is identical to the PR template (it is platform-agnostic markdown), but the file name and install path differ:

```markdown
## Summary

<!-- Brief description of changes -->

## Checklist

- [ ] AGENTS.md updated (if commands or repo structure changed)
- [ ] docs/ updated (if architecture or design changed)
- [ ] New subsystems/directories documented
- [ ] Exec plan created in `docs/exec-plans/active/` (if multi-file change)

## Test Plan

<!-- How to verify these changes work -->
```

**Step 2: Commit**

```bash
git add skills/agent-harness/templates/merge_request_template.md.tmpl
git commit -m "feat: add GitLab merge request template"
```

---

### Task 8: Update checkpoints.yaml for platform awareness

**Files:**
- Modify: `skills/agent-harness/checkpoints.yaml:49-61`

**Step 1: Update AH-12 and AH-20 targets to be platform-aware**

Replace the AH-12 checkpoint:

```yaml
  - id: AH-12
    type: command
    target: "test -f .github/workflows/harness-verify.yml || (test -f .gitlab-ci.yml && grep -q 'harness-verify\\|verify-harness' .gitlab-ci.yml)"
    severity: warning
    desc: "CI harness verification workflow exists (GitHub Actions or GitLab CI)"
```

Replace the AH-20 checkpoint:

```yaml
  - id: AH-20
    type: command
    target: "test -f .github/pull_request_template.md || test -d .github/PULL_REQUEST_TEMPLATE || test -d .gitlab/merge_request_templates"
    severity: warning
    desc: "PR/MR template with harness checklist exists"
```

**Step 2: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('skills/agent-harness/checkpoints.yaml'))" && echo OK`
Expected: `OK`

**Step 3: Commit**

```bash
git add skills/agent-harness/checkpoints.yaml
git commit -m "feat: platform-agnostic checkpoint definitions for AH-12 and AH-20"
```

---

### Task 9: Update SKILL.md bootstrap table

**Files:**
- Modify: `skills/agent-harness/SKILL.md:33-43`

**Step 1: Update the bootstrap artefact table to show both platforms**

Replace the table:

```markdown
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
```

**Step 2: Update the delegation note for github-project**

Find the line:
```
  - Branch protection setup: `@github-project`
```

Replace with:
```
  - Branch protection / merge checks setup: `@github-project` (GitHub) or manual GitLab settings
```

**Step 3: Commit**

```bash
git add skills/agent-harness/SKILL.md
git commit -m "docs: update SKILL.md bootstrap table for GitLab support"
```

---

### Task 10: Update enforcement-mechanisms.md for GitLab

**Files:**
- Modify: `skills/agent-harness/references/enforcement-mechanisms.md`

**Step 1: Add GitLab equivalents to mechanism 1 (Branch Protection)**

After the existing GitHub setup section (around line 37), add:

```markdown
**GitLab equivalent:**

- Configure via GitLab UI: Settings > Repository > Protected branches, or Settings > Merge requests > Merge checks.
- Configure via API: `glab api projects/:id/protected_branches`.
- Add `harness-verify` as a required pipeline job. Under Settings > Merge requests, enable "Pipelines must succeed".
```

**Step 2: Add GitLab equivalents to mechanism 2 (CI Workflows)**

After the existing GitHub workflow section (around line 77), add:

```markdown
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
```

**Step 3: Add GitLab equivalents to mechanism 9 (PR Templates)**

After the existing GitHub PR template section (around line 311), add:

```markdown
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
```

**Step 4: Update the activation chain diagram**

Update the activation chain (around line 371) to mention GitLab:

Replace `PR created on GitHub` with `PR/MR created` and adjust sub-items to mention both platforms.

**Step 5: Commit**

```bash
git add skills/agent-harness/references/enforcement-mechanisms.md
git commit -m "docs: add GitLab equivalents to enforcement mechanisms reference"
```

---

### Task 11: Update maturity-levels.md for GitLab

**Files:**
- Modify: `skills/agent-harness/references/maturity-levels.md`

**Step 1: Update Level 2 setup instructions**

In the "How to set up" section for Level 2 (around line 108), after the GitHub workflow instruction, add:

```markdown
5. **GitLab alternative:** If using GitLab, add a `harness-verify` job to `.gitlab-ci.yml` using the template. This job runs `verify-harness.sh` on every merge request.
```

**Step 2: Update Level 3 setup instructions**

In the "How to set up" section for Level 3 (around line 172-178), update:

- Change step 2 to mention GitLab branch protection: "Configure branch protection: on GitHub, add `harness-verify` as a required status check. On GitLab, enable 'Pipelines must succeed' under Settings > Merge requests."
- Change step 4 to mention both: "Create the PR/MR template. For GitHub: copy to `.github/pull_request_template.md`. For GitLab: copy to `.gitlab/merge_request_templates/Default.md`."

**Step 3: Update checkpoint reference table**

Update checkpoint AH-13 description:
```
| AH-13 | 2 | CI harness workflow exists (GitHub Actions or GitLab CI) | Warning | file_exists / command |
```

Update checkpoint AH-20 description:
```
| AH-20 | 3 | PR/MR template with harness checklist | Warning | file_exists |
```

**Step 4: Update CI usage example**

After the existing GitHub CI example (around line 255-258), add:

```markdown
```yaml
# .gitlab-ci.yml
harness-verify:
  stage: test
  script: bash scripts/verify-harness.sh --level=2 --format=gitlab
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

The GitLab format uses structured log output. Enable "Pipelines must succeed" in GitLab merge request settings to make it a hard gate.
```

**Step 5: Commit**

```bash
git add skills/agent-harness/references/maturity-levels.md
git commit -m "docs: add GitLab guidance to maturity levels reference"
```

---

### Task 12: Update skill-integration-map.md

**Files:**
- Modify: `skills/agent-harness/references/skill-integration-map.md:39-56`

**Step 1: Rename and generalize section 2**

Replace the heading `### 2. github-project-skill` with `### 2. github-project-skill / GitLab project settings`.

Update the description to mention both:

```markdown
**What it provides:** Configures platform features: branch protection rules, PR/MR templates, CODEOWNERS/code owners, repository settings, label schemas.

**Platform notes:**

- **GitHub:** Delegates to `github-project-skill` for branch protection and PR template setup.
- **GitLab:** No equivalent skill exists yet. Configure branch protection and merge request settings manually via GitLab UI (Settings > Repository > Protected branches, Settings > Merge requests).
```

Update "What harness expects back" to mention GitLab:

```markdown
- Branch protection rule on the default branch with `harness-verify` as a required status/pipeline check.
- PR template at `.github/pull_request_template.md` (GitHub) or MR template at `.gitlab/merge_request_templates/Default.md` (GitLab).
```

**Step 2: Commit**

```bash
git add skills/agent-harness/references/skill-integration-map.md
git commit -m "docs: add GitLab notes to skill integration map"
```

---

### Task 13: End-to-end verification

**Step 1: Run the full verify script against its own repo**

Run: `cd /home/psi/workspace/projects/nr-claude-code-marketplace/agent-harness-skill && bash skills/agent-harness/scripts/verify-harness.sh --format=text`
Expected: No regressions from existing checks; platform detected as `github` from remote URL

**Step 2: Run with explicit --platform=gitlab**

Run: `bash skills/agent-harness/scripts/verify-harness.sh --format=text --platform=gitlab`
Expected: CI workflow check now looks for `.gitlab-ci.yml` instead of `.github/workflows/harness-verify.yml`

**Step 3: Run with --format=gitlab**

Run: `bash skills/agent-harness/scripts/verify-harness.sh --format=gitlab --platform=gitlab`
Expected: Output uses GitLab CI section markers

**Step 4: Validate all YAML files**

Run: `python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['skills/agent-harness/checkpoints.yaml', 'skills/agent-harness/templates/gitlab-ci-harness-verify.yml.tmpl']]" && echo "All YAML valid"`
Expected: `All YAML valid`

**Step 5: Run existing lint checks**

Run: `make lint` (or whatever lint target exists)
Expected: All checks pass

**Step 6: Final commit if any fixes needed, then tag**

Only if fixes were required during verification.

---

## Summary of Changes

| Area | GitHub (existing) | GitLab (new) |
|------|------------------|--------------|
| CI env detection | `$GITHUB_ACTIONS` | `$GITLAB_CI` |
| Remote URL pattern | `github.com` | `gitlab` (substring match) |
| CI annotation format | `::error::` / `::warning::` | `ERROR:` / `WARNING:` with section markers |
| CI workflow path | `.github/workflows/harness-verify.yml` | `.gitlab-ci.yml` with `harness-verify` job |
| PR/MR template path | `.github/pull_request_template.md` | `.gitlab/merge_request_templates/Default.md` |
| CLI tool | `gh` | `glab` (optional) |
| Branch protection | GitHub API / UI | GitLab API / UI (manual) |
| Drift detection files | `.github/workflows/*` | `.gitlab-ci.yml` |
