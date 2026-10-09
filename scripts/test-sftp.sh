#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/sftp-fixture
rm -f .build/sftp-fixture/port
python_bin="${UNIVERSALREMOTE_TEST_PYTHON:-.build/test-venv/bin/python}"
"$python_bin" Tests/Integration/SSH/ssh_fixture.py .build/sftp-fixture > .build/sftp-fixture/server.log 2>&1 &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT
for ((i=0; i<100; i++)); do [[ -f .build/sftp-fixture/port ]] && break; sleep 0.05; done
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I UniversalRemote/Native/SSH -I Vendor/Native/include -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation -lssh2 UniversalRemote/Native/SSH/SSHClient.m Tests/Integration/SSH/sftp_integration.m -o .build/sftp-fixture/client
fixture_port=$(cat .build/sftp-fixture/port)
for mode in roundtrip key interactive empty missing local-collision remote-collision missing-file directory race cancel; do
    .build/sftp-fixture/client "$mode" "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"
done

xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I UniversalRemote/Native/SSH -I Vendor/Native/include -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation -lssh2 UniversalRemote/Native/SSH/SSHClient.m Tests/Integration/SSH/sftp_operations.m -o .build/sftp-fixture/operations
.build/sftp-fixture/operations "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"

xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I Vendor/Native/include -c UniversalRemote/Native/SSH/SSHClient.m -o .build/sftp-fixture/native.o
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 -import-objc-header UniversalRemote/Native/SSH/SSHClient.h UniversalRemote/Features/Sessions/SFTPController.swift Tests/Integration/SSH/sftp_local_operations.swift .build/sftp-fixture/native.o -L Vendor/Native/lib -lssh2 -Xlinker -rpath -Xlinker "$PWD/Vendor/Native/lib" -o .build/sftp-fixture/local-operations-client
.build/sftp-fixture/local-operations-client "$PWD/.build/sftp-fixture"

xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I UniversalRemote/Native/SSH -I Vendor/Native/include -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation -lssh2 UniversalRemote/Native/SSH/SSHClient.m Tests/Integration/SSH/sftp_cancel.m -o .build/sftp-fixture/cancel-client
for direction in upload download; do
    .build/sftp-fixture/cancel-client "$direction" "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"
done

xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 -import-objc-header UniversalRemote/Native/SSH/SSHClient.h UniversalRemote/Features/Sessions/SFTPController.swift Tests/Integration/SSH/sftp_drop_operations.swift .build/sftp-fixture/native.o -L Vendor/Native/lib -lssh2 -Xlinker -rpath -Xlinker "$PWD/Vendor/Native/lib" -o .build/sftp-fixture/drop-client
.build/sftp-fixture/drop-client "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"

xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 -import-objc-header UniversalRemote/Native/SSH/SSHClient.h UniversalRemote/Features/Sessions/SFTPController.swift Tests/Integration/SSH/sftp_conflicts.swift .build/sftp-fixture/native.o -L Vendor/Native/lib -lssh2 -Xlinker -rpath -Xlinker "$PWD/Vendor/Native/lib" -o .build/sftp-fixture/conflict-client
.build/sftp-fixture/conflict-client "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"

kill "$fixture_pid" 2>/dev/null || true
wait "$fixture_pid" 2>/dev/null || true
rm -f .build/sftp-fixture/port
"$python_bin" Tests/Integration/SSH/ssh_fixture.py .build/sftp-fixture no-sftp > .build/sftp-fixture/no-sftp.log 2>&1 &
fixture_pid=$!
for ((i=0; i<100; i++)); do [[ -f .build/sftp-fixture/port ]] && break; sleep 0.05; done
fixture_port=$(cat .build/sftp-fixture/port)
.build/sftp-fixture/client no-sftp "$fixture_port" "$PWD/.build/sftp-fixture" "$PWD/.build/sftp-fixture/fingerprint"
