#!/bin/bash
# Secrets are read in memory from the local file, never passed as command arguments.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -m)" == arm64 ]] || { echo 'Apple silicon is required.' >&2; exit 1; }
[[ -f Vendor/Native/lib/libfreerdp3.3.dylib ]] || { echo 'Build the native dependencies first.' >&2; exit 1; }
mkdir -p .build/live-tests
xcrun clang -fobjc-arc -arch arm64 -mmacosx-version-min=27.0 \
  -I UniversalRemote/Native/SSH -I UniversalRemote/Native/RDP -I Vendor/Native/include \
  -I Vendor/Native/include/freerdp3 -I Vendor/Native/include/winpr3 \
  -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" \
  -framework Foundation -framework Security -lssh2 -lfreerdp3 -lfreerdp-client3 -lwinpr3 -lcrypto \
  UniversalRemote/Native/SSH/SSHClient.m UniversalRemote/Native/RDP/RDPClient.m \
  Tests/Integration/Live/live_servers.m -o .build/live-tests/client
probe_mode=""
[[ "${UNIVERSALREMOTE_TEST_CONFIGURED:-0}" != 1 ]] || probe_mode=--configured
# Library logging may contain server details, so suppress it for real credentials.
WLOG_LEVEL=OFF UNIVERSALREMOTE_RDP_CONFIG="$PWD/.build/live-tests/config" \
  .build/live-tests/client "${1:-$PWD/.local-testing/servers.json}" ${probe_mode:+"$probe_mode"} 2>/dev/null
