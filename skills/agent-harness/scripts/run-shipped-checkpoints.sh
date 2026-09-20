#!/usr/bin/env bash
# run-shipped-checkpoints.sh — run the checkpoints that skills ship, against
# this repository, without asking an agent.
#
# Why this exists: agent-harness-skill#61 measured three levers inside a loaded
# skill — a reference file it ships, a step in its workflow, a checkpoint in
# its own validator — and none of them changed behaviour. The validator that
# would have caught the defect was run in one trial of six on the case where it
# was most obviously relevant. A check an agent may choose to skip is not a
# control, so the execution has to sit where the choice does not: CI.
#
# Contract: the repository declares, in .harness/checkpoints.yml, which skills'
# checkpoints apply to it. Each entry is a git repository, a ref and the path to
# a checkpoints.yaml inside it:
#
#   skills:
#     - repo: netresearch/typo3-docs-skill
#       ref: v2.19.0
#       path: skills/typo3-docs/checkpoints.yaml
#
# The ref is pinned deliberately: an unpinned check changes what the gate means
# without a commit in this repository.
#
# Exit code: 1 when a checkpoint of severity `error` failed, 0 otherwise. A
# `warning`/`info` failure is reported and does not gate — the same split the
# assessment skill's severities already declare. `blocked` never gates either:
# it reports a broken checkpoint, not a broken project.

set -uo pipefail

DECL="${HARNESS_CHECKPOINTS_FILE:-.harness/checkpoints.yml}"
# The runner lives in the automated-assessment skill. Pinned, for the same
# reason the skill refs are.
RUNNER_REPO="${HARNESS_RUNNER_REPO:-https://github.com/netresearch/automated-assessment-skill.git}"
RUNNER_REF="${HARNESS_RUNNER_REF:-main}"
RUNNER_PATH="skills/automated-assessment/scripts/run-checkpoints.sh"
# Pre-fetched checkouts, for tests and for a CI job that already has them.
CACHE="${HARNESS_SKILL_CACHE:-}"

usage() {
    cat <<'USAGE'
Usage: run-shipped-checkpoints.sh [--declaration <file>] [<project-root>]

Runs every checkpoints.yaml named by .harness/checkpoints.yml against the
project root (default: the working directory).

Environment:
  HARNESS_CHECKPOINTS_FILE  declaration path (default .harness/checkpoints.yml)
  HARNESS_RUNNER_REPO/_REF  where run-checkpoints.sh comes from
  HARNESS_SKILL_CACHE       directory holding pre-fetched checkouts, named
                            <owner>_<repo>__<ref> (slashes and colons
                            become underscores); anything found there is
                            used instead of cloning
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --declaration) DECL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) break ;;
    esac
done

PROJECT_ROOT="${1:-$PWD}"

if [[ ! -f "$DECL" ]]; then
    echo "No $DECL — this repository declares no shipped checkpoints." >&2
    exit 0
fi

for tool in git yq jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "run-shipped-checkpoints: $tool is required" >&2; exit 2; }
done

COUNT=$(yq -r '.skills | length' "$DECL" 2>/dev/null || echo 0)
if [[ "$COUNT" == "null" || -z "$COUNT" || "$COUNT" -eq 0 ]]; then
    echo "$DECL declares no skills." >&2
    exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Resolve a repo+ref to a checkout directory, preferring the cache.
fetch_repo() {
    local repo="$1" ref="$2" slug dest
    slug=$(echo "${repo}__${ref}" | tr '/:' '__')
    if [[ -n "$CACHE" && -d "$CACHE/$slug" ]]; then
        printf '%s\n' "$CACHE/$slug"
        return 0
    fi
    dest="$WORK/$slug"
    if [[ -d "$dest" ]]; then printf '%s\n' "$dest"; return 0; fi
    local url="$repo"
    [[ "$url" == *://* || "$url" == git@* ]] || url="https://github.com/${repo}.git"
    if ! git clone -q --depth 1 --branch "$ref" "$url" "$dest" 2>/dev/null; then
        # --branch takes a tag or a branch, not a commit sha.
        if ! { git init -q "$dest" \
            && git -C "$dest" remote add origin "$url" \
            && git -C "$dest" fetch -q --depth 1 origin "$ref" \
            && git -C "$dest" checkout -q FETCH_HEAD; }; then
            return 1
        fi
    fi
    printf '%s\n' "$dest"
}

RUNNER_DIR=$(fetch_repo "$RUNNER_REPO" "$RUNNER_REF") || {
    echo "::error::cannot fetch the checkpoint runner from $RUNNER_REPO@$RUNNER_REF" >&2
    exit 2
}
RUNNER="$RUNNER_DIR/$RUNNER_PATH"
[[ -x "$RUNNER" || -f "$RUNNER" ]] || { echo "::error::$RUNNER_PATH not found in $RUNNER_REPO@$RUNNER_REF" >&2; exit 2; }

gate_failures=0
soft_failures=0
ran=0

for i in $(seq 0 $((COUNT - 1))); do
    repo=$(yq -r ".skills[$i].repo" "$DECL")
    ref=$(yq -r ".skills[$i].ref" "$DECL")
    path=$(yq -r ".skills[$i].path" "$DECL")
    if [[ "$repo" == "null" || "$ref" == "null" || "$path" == "null" ]]; then
        echo "::error::$DECL entry $i needs repo, ref and path" >&2
        exit 2
    fi

    dir=$(fetch_repo "$repo" "$ref") || {
        echo "::error::cannot fetch $repo@$ref" >&2
        exit 2
    }
    cp_file="$dir/$path"
    if [[ ! -f "$cp_file" ]]; then
        # An entry naming a file that is not there is a broken declaration, not
        # a silent no-op: that is the failure mode this whole mechanism exists
        # to avoid.
        echo "::error::$repo@$ref has no $path" >&2
        exit 2
    fi

    json=$(bash "$RUNNER" --json "$cp_file" "$PROJECT_ROOT" 2>/dev/null)
    if [[ -z "$json" ]]; then
        echo "::error::the runner produced no output for $repo@$ref" >&2
        exit 2
    fi
    ran=$((ran + 1))

    skipped=$(printf '%s' "$json" | jq -r '.status // ""' 2>/dev/null)
    if [[ "$skipped" == "skipped" ]]; then
        echo "— $repo@$ref: not applicable ($(printf '%s' "$json" | jq -r '.reason // ""'))"
        continue
    fi

    errs=$(printf '%s' "$json" | jq -r '[.checkpoints[] | select(.status == "fail" and .severity == "error") | .id] | join(" ")')
    softs=$(printf '%s' "$json" | jq -r '[.checkpoints[] | select(.status == "fail" and .severity != "error") | .id] | join(" ")')
    summary=$(printf '%s' "$json" | jq -r '"pass \(.summary.pass) fail \(.summary.fail) skip \(.summary.skip) blocked \(.summary.blocked)"')
    echo "• $repo@$ref: $summary"

    if [[ -n "$errs" ]]; then
        echo "::error::$repo: failing checkpoints of severity error: $errs"
        gate_failures=$((gate_failures + 1))
    fi
    if [[ -n "$softs" ]]; then
        echo "::warning::$repo: failing checkpoints below severity error: $softs"
        soft_failures=$((soft_failures + 1))
    fi
done

echo "----------------------------------------"
echo "ran $ran of $COUNT declared skill(s); $gate_failures with an error-severity failure, $soft_failures with warnings only"

[[ "$gate_failures" -eq 0 ]] || exit 1
exit 0
