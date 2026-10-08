#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
icon_tool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$icon_tool" ]] || { echo 'Icon Composer from Xcode 27 is required.' >&2; exit 1; }
mkdir -p .build/icon-previews
for appearance in Default Dark Mono; do
  "$icon_tool" "$PWD/UniversalRemote/AppIcon.icon" --export-image \
    --output-file "$PWD/.build/icon-previews/UniversalRemote-$appearance.png" \
    --platform macOS --rendition "$appearance" --width 512 --height 512 --scale 1 --design-generation 27 > /dev/null
 done
for size in 16 32 64 128; do
  "$icon_tool" "$PWD/UniversalRemote/AppIcon.icon" --export-image \
    --output-file "$PWD/.build/icon-previews/UniversalRemote-$size.png" \
    --platform macOS --rendition Default --width "$size" --height "$size" --scale 1 --design-generation 27 > /dev/null
done
printf 'Icon previews: %s/.build/icon-previews\n' "$PWD"
