#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/sftp-throughput
rm -f .build/sftp-throughput/port .build/sftp-throughput/proxy-port
python_bin="${UNIVERSALREMOTE_TEST_PYTHON:-.build/test-venv/bin/python}"
"$python_bin" Tests/Integration/SSH/ssh_fixture.py .build/sftp-throughput > .build/sftp-throughput/server.log 2>&1 &
server_pid=$!
proxy_pid=""
trap 'kill "$server_pid" ${proxy_pid:+"$proxy_pid"} 2>/dev/null || true' EXIT
for ((i=0;i<100;i++)); do [[ -f .build/sftp-throughput/port ]] && break; sleep 0.05; done
"$python_bin" Tests/Integration/SSH/sftp_latency_proxy.py "$(cat .build/sftp-throughput/port)" .build/sftp-throughput/proxy-port > .build/sftp-throughput/proxy.log 2>&1 &
proxy_pid=$!
for ((i=0;i<100;i++)); do [[ -f .build/sftp-throughput/proxy-port ]] && break; sleep 0.05; done
# Controlled comparison: identical new code, just the previous 32 KiB window.
python3 - <<'PY'
from pathlib import Path
code=Path('UniversalRemote/Native/SSH/SSHClient.m').read_text()
code=code.replace('upload ? 1024 * 1024 : 256 * 1024', '32768')
Path('.build/sftp-throughput/baseline.m').write_text(code)
PY
for mode in baseline pipelined; do
    source=.build/sftp-throughput/baseline.m
    [[ "$mode" == baseline ]] || source=UniversalRemote/Native/SSH/SSHClient.m
    xcrun clang -fobjc-arc -mmacosx-version-min=27.0 -I UniversalRemote/Native/SSH -I Vendor/Native/include -L Vendor/Native/lib -Wl,-rpath,"$PWD/Vendor/Native/lib" -framework Foundation -lssh2 "$source" Tests/Integration/SSH/sftp_throughput.m -o ".build/sftp-throughput/$mode"
    ".build/sftp-throughput/$mode" "$(cat .build/sftp-throughput/proxy-port)" "$PWD/.build/sftp-throughput" "$PWD/.build/sftp-throughput/fingerprint" > ".build/sftp-throughput/$mode-speed"
done
python3 - <<'PY'
from pathlib import Path
root=Path('.build/sftp-throughput')
before=float((root/'baseline-speed').read_text())
after=float((root/'pipelined-speed').read_text())
assert after > before * 2, (before,after)
print(f'PASS simulated 20 ms RTT upload: 32 KiB {before:.2f} MiB/s; 1 MiB {after:.2f} MiB/s; {after/before:.1f}x')
PY
