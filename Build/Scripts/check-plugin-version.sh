#!/usr/bin/env bash
set -euo pipefail

# Verify that plugin.json version matches the git tag
TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "Usage: check-plugin-version.sh <tag>"
  exit 1
fi

VERSION="${TAG#v}"
PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")

if [ "$VERSION" != "$PLUGIN_VERSION" ]; then
  echo "ERROR: Tag version ($VERSION) does not match plugin.json version ($PLUGIN_VERSION)"
  exit 1
fi

echo "OK: Version $VERSION matches"
