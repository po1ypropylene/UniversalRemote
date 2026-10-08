#!/bin/bash
# Regenerate original artwork while preserving Icon Composer's material settings.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/icon-artwork
xcrun swift scripts/generate-icon.swift .build/icon-artwork
cp .build/icon-artwork/Connection.png UniversalRemote/AppIcon.icon/Assets/Connection.png
cp .build/icon-artwork/Endpoints.png UniversalRemote/AppIcon.icon/Assets/Endpoints.png
mkdir -p UniversalRemote/Assets.xcassets/BrandMark.imageset
cp .build/icon-artwork/BrandMark.png UniversalRemote/Assets.xcassets/BrandMark.imageset/BrandMark.png
cat > UniversalRemote/Assets.xcassets/BrandMark.imageset/Contents.json <<'JSON'
{
  "images": [{ "filename": "BrandMark.png", "idiom": "universal" }],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "template-rendering-intent": "template" }
}
JSON
