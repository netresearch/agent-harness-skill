#!/usr/bin/env bash
# tests/verify-harness-runs.sh — the verifier must produce a report.
#
# It ran under `set -euo pipefail` with an unguarded `git remote get-url
# origin | sed` in the PR-template check. Without an origin remote the
# pipeline exits non-zero and set -e kills the script there — before anything
# is rendered, with git's message swallowed by 2>/dev/null. The observable
# result was zero bytes and exit 2, which reads as a broken harness.
#
# That is the first state of the skill's own headline use case: a repository
# being made agent-ready has a git repo and usually no remote yet. So the
# property under test is not a message, it is that the verifier speaks at all.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
VERIFY="$ROOT/skills/agent-harness/scripts/verify-harness.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

mk_repo() { # mk_repo <name> <with-origin: y|n>
    local d="$WORK/$1"
    mkdir -p "$d/.github/workflows" "$d/docs"
    printf '# %s\n' "$1" > "$d/AGENTS.md"
    git init -q "$d"
    [ "$2" = y ] && git -C "$d" remote add origin https://github.com/example/fixture.git
    printf '%s\n' "$d"
}

# Reports something, whatever the verdict: a verifier that renders nothing
# cannot be acted on, and its exit code alone does not say whether it judged
# the repository or died before looking at it.
speaks() { # speaks <repo-dir> -> "yes"/"no"
    local out
    out=$( cd "$1" && PLATFORM=github bash "$VERIFY" --format=text 2>&1 )
    [ -n "$out" ] && echo yes || echo no
}

echo "verify-harness:"

r=$(mk_repo with-origin y)
check "a repository with an origin remote gets a report" yes "$(speaks "$r")"

# The regression. Same fixture, one difference.
r=$(mk_repo no-origin n)
check "a repository WITHOUT an origin remote gets one too" yes "$(speaks "$r")"

# Both must reach the same verdict — the remote is not an input to any check
# this fixture exercises, so a difference would mean the fix changed behaviour
# rather than stopping an abort.
verdict() { ( cd "$1" && PLATFORM=github bash "$VERIFY" --format=text 2>&1 ) | grep -c '^Summary:'; }
check "and the report is a complete one" "1" "$(verdict "$(mk_repo no-origin-2 n)")"

echo
if [ "$fail" -eq 0 ]; then
    echo "All verify-harness tests passed"
else
    echo "Some verify-harness tests FAILED"
fi
exit "$fail"
