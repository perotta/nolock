#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build.sh"
destination="${1:-$HOME/Applications/NoLock.app}"
if [ -e "$destination" ]; then
    if [ ! -f "$destination/Contents/Info.plist" ] || [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist")" != "local.nolock.app" ]; then
        printf 'Refusing to overwrite a different app at %s\n' "$destination" >&2
        exit 1
    fi
    if pgrep -f "^$destination/Contents/MacOS/NoLock( |$)" >/dev/null; then
        printf 'Quit the existing NoLock app before installing an update.\n' >&2
        exit 1
    fi
fi
mkdir -p "$(dirname "$destination")"
ditto "$project_dir/dist/NoLock.app" "$destination"
open "$destination" --args --show
printf 'Installed and opened %s\n' "$destination"
