#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/test-support.sh workspace
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 \
  UniversalRemote/Domain/*.swift UniversalRemote/Persistence/*.swift \
  UniversalRemote/Shared/Security/*.swift UniversalRemote/Shared/Prompting/*.swift \
  UniversalRemote/Shared/Testing/*.swift UniversalRemote/Features/Connections/EditorRequest.swift \
  UniversalRemote/Features/Workspace/Workspace.swift Tests/Integration/Workspace/WorkspaceChecks.swift \
  -o "$fixture_root/client"
"$fixture_root/client"

# Exercise the actual main-actor session and native SSH adapter after the fast doubles.
products="$PWD/.build/Xcode/Build/Products/Release"
[[ -f "$products/SwiftTerm.o" ]] || { echo 'Build the Release app before session checks.' >&2; exit 1; }
python_bin="${UNIVERSALREMOTE_TEST_PYTHON:-.dependencies/test-venv/bin/python}"
"$python_bin" Tests/Integration/SSH/ssh_fixture.py "$fixture_root" keyboard-no-shell > "$fixture_root/server.log" 2>&1 &
fixture_pids+=("$!")
for ((i=0; i<100; i++)); do [[ -f "$fixture_root/port" ]] && break; sleep 0.05; done
for protocol in SSH RDP; do
  xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I Vendor/Native/include \
    -I Vendor/Native/include/freerdp3 -I Vendor/Native/include/winpr3 \
    -c "UniversalRemote/Native/$protocol/${protocol}Client.m" -o "$fixture_root/$protocol.o"
done
session_sources=()
while IFS= read -r source; do session_sources+=("$source"); done < <(rg --files UniversalRemote -g '*.swift' | rg -v '^UniversalRemote/App/' | sort)
xcrun swiftc -parse-as-library -module-name UniversalRemote -target arm64-apple-macos27.0 \
  -I "$products" -import-objc-header UniversalRemote/Native-Bridge.h \
  "${session_sources[@]}" Tests/Integration/Workspace/SSHSessionChecks.swift \
  "$fixture_root/SSH.o" "$fixture_root/RDP.o" "$products/SwiftTerm.o" \
  -L Vendor/Native/lib -lssh2 -lfreerdp3 -lfreerdp-client3 -lwinpr3 -lcrypto \
  -Xlinker -rpath -Xlinker "$PWD/Vendor/Native/lib" -o "$fixture_root/ssh-session-client"
"$fixture_root/ssh-session-client" "$(cat "$fixture_root/port")" "$fixture_root/fingerprint"
