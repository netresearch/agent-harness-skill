#!/usr/bin/env bash
# Verify .claude-plugin/plugin.json version matches SKILL.md metadata.version.
# Mirrors the CI step in skill-repo-skill's validate.yml.
set -euo pipefail

PLUGIN_FILE=".claude-plugin/plugin.json"
[ -f "$PLUGIN_FILE" ] || { echo "  (no $PLUGIN_FILE, skipping)"; exit 0; }

plugin_version=$(python3 -c "import json; print(json.load(open('$PLUGIN_FILE'))['version'])")

skill_file=""
if [ -f "SKILL.md" ]; then
  skill_file="SKILL.md"
else
  for f in skills/*/SKILL.md; do
    [ -f "$f" ] && { skill_file="$f"; break; }
  done
fi
[ -n "$skill_file" ] || { echo "  (no SKILL.md, skipping)"; exit 0; }

skill_version=$(sed -n '/^---$/,/^---$/p' "$skill_file" \
  | grep -E '^[[:space:]]*version:' \
  | head -1 \
  | sed 's/.*version:[[:space:]]*//' \
  | tr -d '"'"'")

[ -n "$skill_version" ] || { echo "  (no metadata.version in $skill_file, skipping)"; exit 0; }

if [ "$plugin_version" != "$skill_version" ]; then
  echo "❌ Version mismatch:"
  echo "   $PLUGIN_FILE = $plugin_version"
  echo "   $skill_file  = $skill_version"
  exit 1
fi
