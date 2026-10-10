#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f Vendor/Native/lib/libssh2.1.dylib && -f Vendor/Native/lib/libfreerdp3.3.dylib && "$(cat Vendor/Native/.platform 2>/dev/null)" == arm64-macos27-audio1 ]] || scripts/prepare-dependencies.sh
scripts/prepare-wireguard.sh
# The always-running native packaging phase replaces sealed resources. Recreate
# only the generated app so Xcode cannot skip its final signing on a cached build.
rm -rf ".build/Xcode/Build/Products/Release/Farcast.app"
xcodebuild -project Farcast.xcodeproj -scheme Farcast -configuration Release \
  -derivedDataPath .build/Xcode -clonedSourcePackagesDirPath .dependencies/swift-packages -skipPackagePluginValidation CODE_SIGN_IDENTITY=- ENABLE_HARDENED_RUNTIME=NO build
python3 scripts/verify-bundle.py ".build/Xcode/Build/Products/Release/Farcast.app"
printf 'Built app: %s/.build/Xcode/Build/Products/Release/Farcast.app\n' "$PWD"
