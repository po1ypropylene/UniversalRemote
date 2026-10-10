#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/test-support.sh rdp-files
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I Farcast/Native/RDP \
  -I Vendor/Native/include -I Vendor/Native/include/freerdp3 -I Vendor/Native/include/winpr3 \
  -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation \
  -lfreerdp3 -lfreerdp-client3 -lwinpr3 Farcast/Native/RDP/RDPClipboard.m \
  Tests/Integration/RDP/clipboard_files.m -o "$fixture_root/client"
"$fixture_root/client" "$fixture_root"
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I Vendor/Native/include \
  -I Vendor/Native/include/freerdp3 -I Vendor/Native/include/winpr3 \
  -c Farcast/Native/RDP/RDPClipboard.m -o "$fixture_root/clipboard.o"
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 \
  -import-objc-header Farcast/Native/RDP/RDPClipboard.h \
  "$fixture_root/clipboard.o" -L Vendor/Native/lib -lfreerdp3 -lfreerdp-client3 -lwinpr3 \
  -Xlinker -rpath -Xlinker "$PWD/Vendor/Native/lib" \
  Farcast/Protocols/RDP/RDPClipboardBridge.swift Tests/Integration/RDP/ClipboardBridgeChecks.swift \
  -o "$fixture_root/bridge"
"$fixture_root/bridge" "$fixture_root"

