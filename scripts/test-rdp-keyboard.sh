#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/rdp-test
xcrun swiftc -target arm64-apple-macos27.0 -parse-as-library \
  UniversalRemote/Protocols/RDP/RDPDesktopView.swift Tests/Integration/RDP/keyboard.swift \
  -o .build/rdp-test/keyboard
.build/rdp-test/keyboard
