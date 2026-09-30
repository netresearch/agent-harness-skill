#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# tests/build-pre-commit-hook.sh — Build/hooks/pre-commit must enforce the
# SKILL.md limit that validate-skill.sh enforces, not a stricter one.
#
# The hook counted 500 WORDS over the body while validate-skill.sh (from
# netresearch/skill-repo-skill) allows 500 LINES. With a 558-word SKILL.md
# the hook exited 1 on main although every CI gate passed.
#
# The hook must also reject staged changes that `git diff --cached --check`
# reports (trailing whitespace, leftover conflict markers).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
HOOK="$ROOT/Build/hooks/pre-commit"
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

mk_skill() { # mk_skill <name> <body-lines> <words-per-line>
    local d="$WORK/$1" i
    mkdir -p "$d/skills/agent-harness"
    git init -q "$d"
    {
        printf -- '---\nname: agent-harness\ndescription: fixture\n---\n'
        for ((i = 0; i < $2; i++)); do
            printf 'word%.0s ' $(seq "$3")
            printf '\n'
        done
    } > "$d/skills/agent-harness/SKILL.md"
    printf '%s\n' "$d"
}

run_hook() { # run_hook <repo-dir> -> exit code
    ( cd "$1" && bash "$HOOK" >/dev/null 2>&1 )
    echo $?
}

echo "Build/hooks/pre-commit:"

r=$(mk_skill many-words 100 10)
check "a 100-line body with 1000 words passes" 0 "$(run_hook "$r")"

r=$(mk_skill at-limit 500 1)
check "a 500-line body passes" 0 "$(run_hook "$r")"

r=$(mk_skill over-limit 501 1)
check "a 501-line body fails" 1 "$(run_hook "$r")"
check "and says why" "ERROR: SKILL.md body exceeds 500 lines (501 lines)" \
    "$( cd "$r" && bash "$HOOK" 2>&1 | head -1 )"

check "this repository's own SKILL.md passes" 0 "$(run_hook "$ROOT")"

# The whitespace check sat in an if-block with an empty body, so a staged
# line with trailing whitespace passed.
r=$(mk_skill staged-clean 10 1)
printf 'clean line\n' > "$r/notes.txt"
git -C "$r" add notes.txt
check "a staged file without whitespace errors passes" 0 "$(run_hook "$r")"

r=$(mk_skill staged-trailing 10 1)
printf 'trailing space \n' > "$r/notes.txt"
git -C "$r" add notes.txt
check "a staged line with trailing whitespace fails" 1 "$(run_hook "$r")"
check "and says why" "ERROR: staged changes contain whitespace errors (listed above)" \
    "$( cd "$r" && bash "$HOOK" 2>&1 | tail -1 )"

echo
if [ "$fail" -eq 0 ]; then
    echo "All pre-commit hook tests passed"
else
    echo "Some pre-commit hook tests FAILED"
fi
exit "$fail"
