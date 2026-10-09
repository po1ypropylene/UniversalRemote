#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
fixture_root="$(mktemp -d "$PWD/.build/wireguard-migration.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT
python3 - "$fixture_root" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
# Reconstruct the pre-feature models by removing only the new optional selection.
for name in ['Domain/ConnectionDraft.swift', 'Persistence/SavedConnection.swift']:
    source = Path('UniversalRemote') / name
    text = ''.join(line for line in source.read_text().splitlines(True) if 'wireGuardID' not in line)
    (out / source.name).write_text(text)
PY
common=(UniversalRemote/Domain/RemoteProtocol.swift UniversalRemote/Domain/SSHAuthentication.swift UniversalRemote/Persistence/ConnectionFolder.swift Tests/Integration/WireGuard/migration.swift)
xcrun swiftc -parse-as-library -module-name UniversalRemote -target arm64-apple-macos27.0 -D BASELINE "${common[@]}" "$fixture_root/ConnectionDraft.swift" "$fixture_root/SavedConnection.swift" -o "$fixture_root/baseline"
xcrun swiftc -parse-as-library -module-name UniversalRemote -target arm64-apple-macos27.0 "${common[@]}" UniversalRemote/Domain/ConnectionDraft.swift UniversalRemote/Persistence/SavedConnection.swift UniversalRemote/Persistence/SavedWireGuard.swift UniversalRemote/Domain/WireGuardConfiguration.swift -o "$fixture_root/current"
"$fixture_root/baseline" "$fixture_root/library.store"
"$fixture_root/current" "$fixture_root/library.store"
"$fixture_root/current" "$fixture_root/library.store" reopen
