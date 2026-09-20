#!/usr/bin/env bash
# tests/shipped-checkpoints.sh — execute run-shipped-checkpoints.sh.
#
# The script exists because a check an agent may choose to skip is not a
# control (issue #61). A test that only inspected it would repeat that mistake
# one level up, so every case here runs it and asserts on its exit code and its
# output.
#
# No network: HARNESS_SKILL_CACHE holds hand-built checkouts, which is also the
# shape a CI job with a pre-fetched skill directory uses.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/skills/agent-harness/scripts/run-shipped-checkpoints.sh"
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

for tool in git yq jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "SKIP: $tool not installed"; exit 0; }
done

# --- a stand-in for the assessment runner ---------------------------------
# The real runner lives in another repository. What this script has to get
# right is its own half: reading the declaration, resolving each entry, and
# turning the runner's JSON into an exit code. A stub makes that testable here
# and keeps the suite off the network; the runner's own behaviour is tested in
# the repository that owns it.
CACHE="$WORK/cache"
RUNNER_SLUG="stub-runner__main"
mkdir -p "$CACHE/$RUNNER_SLUG/skills/automated-assessment/scripts"
cat > "$CACHE/$RUNNER_SLUG/skills/automated-assessment/scripts/run-checkpoints.sh" <<'STUB'
#!/usr/bin/env bash
# Echoes the JSON stored next to the checkpoints file it is given, so a case
# can hand the script any runner verdict.
set -uo pipefail
for a in "$@"; do case "$a" in --json) ;; *) last="$a" ;; esac; done
cp_file=""
for a in "$@"; do [[ "$a" == *.yaml ]] && cp_file="$a"; done
cat "${cp_file%.yaml}.json"
STUB

mk_skill() { # mk_skill <slug> <json-payload>
    local slug="$1" payload="$2"
    mkdir -p "$CACHE/$slug/skills/x"
    echo "version: 1" > "$CACHE/$slug/skills/x/checkpoints.yaml"
    printf '%s\n' "$payload" > "$CACHE/$slug/skills/x/checkpoints.json"
}

decl() { # decl <file> <slug-as-repo> <ref>
    cat > "$1" <<EOF
skills:
  - repo: $2
    ref: $3
    path: skills/x/checkpoints.yaml
EOF
}

run() { # run <declaration>
    HARNESS_SKILL_CACHE="$CACHE" \
    HARNESS_RUNNER_REPO="stub-runner" HARNESS_RUNNER_REF="main" \
        bash "$SCRIPT" --declaration "$1" "$WORK/proj" 2>&1
}

mkdir -p "$WORK/proj"

PASSING='{"summary":{"total":2,"pass":2,"fail":0,"skip":0,"blocked":0},"checkpoints":[{"id":"X-01","status":"pass","severity":"error"},{"id":"X-02","status":"pass","severity":"warning"}]}'
ERRFAIL='{"summary":{"total":2,"pass":1,"fail":1,"skip":0,"blocked":0},"checkpoints":[{"id":"X-01","status":"fail","severity":"error"},{"id":"X-02","status":"pass","severity":"warning"}]}'
WARNFAIL='{"summary":{"total":2,"pass":1,"fail":1,"skip":0,"blocked":0},"checkpoints":[{"id":"X-01","status":"pass","severity":"error"},{"id":"X-02","status":"fail","severity":"warning"}]}'
BLOCKED='{"summary":{"total":1,"pass":0,"fail":0,"skip":0,"blocked":1},"checkpoints":[{"id":"X-01","status":"blocked","severity":"error"}]}'
NOTAPPL='{"checkpoint_file":"x","skill_id":"x","status":"skipped","reason":"precondition failed: json_path composer.json"}'

echo "run-shipped-checkpoints:"

# Both directions of the gate, in the same shape: a suite that only asserted
# the failure would be satisfied by a script that always exits 1.
mk_skill "ok__v1"   "$PASSING"; decl "$WORK/d-ok.yml"   "ok"   "v1"
out=$(run "$WORK/d-ok.yml"); rc=$?
check "a passing skill exits 0" 0 "$rc"
check "and reports the run" 1 "$(grep -c 'ran 1 of 1' <<<"$out")"

mk_skill "bad__v1"  "$ERRFAIL"; decl "$WORK/d-bad.yml"  "bad"  "v1"
out=$(run "$WORK/d-bad.yml"); rc=$?
check "an error-severity failure gates" 1 "$rc"
check "and the message names the checkpoint" 1 "$(grep -c '::error::bad: failing checkpoints of severity error: X-01' <<<"$out")"

# The severity split is the whole reason this script exists rather than a bare
# call to the runner, whose exit code is 1 for any failure at all.
mk_skill "warn__v1" "$WARNFAIL"; decl "$WORK/d-warn.yml" "warn" "v1"
out=$(run "$WORK/d-warn.yml"); rc=$?
check "a warning-severity failure does not gate" 0 "$rc"
check "but is still reported" 1 "$(grep -c '::warning::warn: failing checkpoints below severity error: X-02' <<<"$out")"

mk_skill "blk__v1"  "$BLOCKED"; decl "$WORK/d-blk.yml"  "blk"  "v1"
out=$(run "$WORK/d-blk.yml"); rc=$?
check "a blocked checkpoint does not gate" 0 "$rc"

mk_skill "na__v1"   "$NOTAPPL"; decl "$WORK/d-na.yml"   "na"   "v1"
out=$(run "$WORK/d-na.yml"); rc=$?
check "a skill gated out by its preconditions exits 0" 0 "$rc"
check "and says it did not apply" 1 "$(grep -c 'not applicable' <<<"$out")"

# A declaration is a promise that these checks run. Every way it can fail to
# keep that promise must be loud, because a silent no-op here reproduces
# exactly the defect the mechanism was built against.
decl "$WORK/d-missing.yml" "ok" "v1"
sed -i 's|skills/x/checkpoints.yaml|skills/nope/checkpoints.yaml|' "$WORK/d-missing.yml"
out=$(run "$WORK/d-missing.yml"); rc=$?
check "a declared file that does not exist is an error" 2 "$rc"
check "and names the path" 1 "$(grep -c 'has no skills/nope/checkpoints.yaml' <<<"$out")"

decl "$WORK/d-unfetchable.yml" "no-such-skill-repo" "v1"
out=$(run "$WORK/d-unfetchable.yml"); rc=$?
check "an unfetchable skill is an error, not a skip" 2 "$rc"

cat > "$WORK/d-incomplete.yml" <<'EOF'
skills:
  - repo: ok
    path: skills/x/checkpoints.yaml
EOF
out=$(run "$WORK/d-incomplete.yml"); rc=$?
check "an entry without a ref is an error" 2 "$rc"

out=$(run "$WORK/d-absent.yml"); rc=$?
check "no declaration at all exits 0" 0 "$rc"

cat > "$WORK/d-empty.yml" <<'EOF'
skills: []
EOF
out=$(run "$WORK/d-empty.yml"); rc=$?
check "an empty declaration exits 0" 0 "$rc"

# --- the declaration and the job must imply each other --------------------
# A declaration nobody runs reads as enforcement and buys false trust; a job
# with nothing to run is a green check that measures nothing. Three states,
# because asserting only the first would be satisfied by a check that always
# errors.
VERIFY="$ROOT/skills/agent-harness/scripts/verify-harness.sh"

mk_repo() { # mk_repo <name> <has-declaration: y|n> <has-job: y|n>
    local d="$WORK/repo-$1"
    mkdir -p "$d/.github/workflows" "$d/docs"
    printf '# %s\n\nSee [docs](docs/)\n' "$1" > "$d/AGENTS.md"
    # verify-harness.sh needs a repository: it reads git for drift detection
    # and exits 128 without one, which prints nothing and reads as "the check
    # did not fire".
    git init -q "$d"
    # ... and a remote: a later check runs `git remote get-url origin`, whose
    # failure aborts the whole verifier before it renders anything, so the
    # fixture would report zero matches for every assertion below.
    git -C "$d" remote add origin https://github.com/example/fixture.git
    git -C "$d" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false \
        add -A >/dev/null 2>&1
    git -C "$d" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false \
        commit -q -m init >/dev/null 2>&1
    if [ "$2" = y ]; then
        mkdir -p "$d/.harness"
        printf 'skills:\n  - repo: netresearch/x-skill\n    ref: v1\n    path: skills/x/checkpoints.yaml\n' > "$d/.harness/checkpoints.yml"
    fi
    if [ "$3" = y ]; then
        printf 'name: cp\njobs:\n  x:\n    steps:\n      - run: bash run-shipped-checkpoints.sh\n' > "$d/.github/workflows/harness-checkpoints.yml"
    fi
    printf '%s\n' "$d"
}

# Assert the severity, not only the wording: the verifier's exit code is 1 with
# any error and 2 with warnings only, so grepping the message alone would pass
# just as happily if the check were downgraded to a `pass` — a mutation that
# changed `fail` to `pass` and kept the text survived exactly that assertion.
# Read the severity off the annotation, not off the process exit code: a
# fixture repository trips other level-2 checks, so the exit code is 1 whatever
# this one decides. `--format=github` prefixes each finding with ::error or
# ::warning, which is the per-finding severity — a mutation downgrading this
# check to a `pass` while keeping its wording survived an assertion that
# grepped the message alone.
verify_annotation() { # verify_annotation <repo-dir> -> the ::kind for our file, or "none"
    local out
    out=$( cd "$1" && bash "$VERIFY" --format=github 2>&1 )
    grep -oE '::(error|warning) file=\.harness/checkpoints\.yml' <<<"$out" | head -1 | grep -oE 'error|warning' || echo none
}
verify_passline() { # verify_passline <repo-dir>
    ( cd "$1" && PLATFORM=github bash "$VERIFY" 2>&1 ) | grep -c 'shipped checkpoints are declared and run in CI'
}

r=$(mk_repo both y y)
check "declaration plus job is reported as passing" "1"       "$(verify_passline "$r")"
check "and raises no annotation"                    "none"    "$(verify_annotation "$r")"
r=$(mk_repo decl-only y n)
check "a declaration no job runs is an error"       "error"   "$(verify_annotation "$r")"
r=$(mk_repo job-only n y)
check "a job with no declaration is an error"       "error"   "$(verify_annotation "$r")"
r=$(mk_repo neither n n)
check "neither is a warning, not an error"          "warning" "$(verify_annotation "$r")"

echo
if [ "$fail" -eq 0 ]; then
    echo "All shipped-checkpoints tests passed"
else
    echo "Some shipped-checkpoints tests FAILED"
fi
exit "$fail"
