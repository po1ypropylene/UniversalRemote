#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ssh-fixture
rm -f .build/ssh-fixture/port
python_bin="${UNIVERSALREMOTE_TEST_PYTHON:-.build/test-venv/bin/python}"
"$python_bin" Tests/Integration/SSH/ssh_fixture.py .build/ssh-fixture > .build/ssh-fixture/server.log 2>&1 &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT
for ((i=0; i<100; i++)); do [[ -f .build/ssh-fixture/port ]] && break; sleep 0.05; done
xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I UniversalRemote/Native/SSH -I UniversalRemote/Native/RDP -I Vendor/Native/include -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation -lssh2 UniversalRemote/Native/SSH/SSHClient.m Tests/Integration/SSH/ssh_integration.m -o .build/ssh-fixture/client
fixture_port=$(cat .build/ssh-fixture/port)
for mode in password key ed25519 interactive bad-password reject cancel; do
  key_file=.build/ssh-fixture/user-key.pem
  [[ "$mode" != ed25519 ]] || key_file=.build/ssh-fixture/ed25519-key
  .build/ssh-fixture/client "$mode" "$fixture_port" "$key_file"
done
