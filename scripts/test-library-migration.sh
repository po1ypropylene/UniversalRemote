#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/test-support.sh library-migration
sources=(Farcast/Domain/*.swift Farcast/Persistence/*.swift Farcast/Shared/Security/*.swift Farcast/Shared/Testing/*.swift Tests/Integration/Migration/LibraryRenameChecks.swift)
# The old module name is fixture provenance, not an app/package identity.
xcrun swiftc -parse-as-library -module-name UniversalRemote -target arm64-apple-macos27.0 -D PREVIOUS_LIBRARY "${sources[@]}" -o "$fixture_root/previous"
xcrun swiftc -parse-as-library -module-name Farcast -target arm64-apple-macos27.0 "${sources[@]}" -o "$fixture_root/current"
"$fixture_root/previous" "$fixture_root/Library"
"$fixture_root/current" "$fixture_root/Library"
