#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/rdp-test
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 \
  -I Vendor/Native/include/freerdp3 -I Vendor/Native/include/winpr3 \
  -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" \
  -framework Foundation -lfreerdp3 -lfreerdp-client3 -lwinpr3 \
  Tests/Integration/RDP/audio_backend.m -o .build/rdp-test/audio-backend
.build/rdp-test/audio-backend
