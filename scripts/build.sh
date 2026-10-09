#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
bundle="$project_dir/dist/NoLock.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/NoLock" "$bundle/Contents/MacOS/NoLock"
cp "$project_dir/Resources/Info.plist" "$bundle/Contents/Info.plist"
swift "$project_dir/scripts/make-icon.swift" "$project_dir/dist/NoLock.iconset"
iconutil -c icns "$project_dir/dist/NoLock.iconset" -o "$bundle/Contents/Resources/NoLock.icns"
# Keep a stable developer signature across updates so macOS recognizes existing grants.
# Pin the selected identity locally, and fail instead of silently changing it if unavailable.
identity_file="$project_dir/.build/code-sign-identity"
signing_identity="${CODE_SIGN_IDENTITY:-}"
if [ -z "$signing_identity" ] && [ -f "$identity_file" ]; then
    signing_identity="$(cat "$identity_file")"
fi
if [ -z "$signing_identity" ]; then
    signing_identity="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi
if [ -z "$signing_identity" ]; then
    signing_identity=-
    printf 'No developer identity found; ad-hoc updates may require renewing Accessibility access.\n' >&2
fi
codesign --force --sign "$signing_identity" --identifier local.nolock.app "$bundle"
codesign --verify --deep --strict "$bundle"
if [ "$signing_identity" != - ]; then
    printf '%s\n' "$signing_identity" > "$identity_file"
fi
printf 'Built %s\n' "$bundle"
