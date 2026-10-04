#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build -c release

app_path="$project_root/CodexRoute.app"
binary_path="$project_root/.build/release/CodexRoute"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_path" "$app_path/Contents/MacOS/CodexRoute"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
xattr -cr "$app_path"
codesign --force --deep --sign - "$app_path"
printf 'Built %s\n' "$app_path"
