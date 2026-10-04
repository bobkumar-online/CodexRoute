#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build
plutil -lint Resources/Info.plist
swift package describe --type json | jq -e '.name == "CodexRoute"' >/dev/null
printf 'Build verification passed.\n'
