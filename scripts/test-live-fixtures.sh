#!/bin/bash
# Exercise the protected-file probe against synthetic servers only.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
fixture_root="$PWD/.build/live-fixtures"
mkdir -p "$fixture_root/ssh"
rm -f "$fixture_root/ssh/port"
python_bin="${UNIVERSALREMOTE_TEST_PYTHON:-.build/test-venv/bin/python}"
"$python_bin" Tests/Integration/SSH/ssh_fixture.py "$fixture_root/ssh" > "$fixture_root/ssh.log" 2>&1 &
ssh_pid=$!
rdp_pid=''
trap 'kill "$ssh_pid" ${rdp_pid:+"$rdp_pid"} 2>/dev/null || true' EXIT
for ((i=0; i<100; i++)); do [[ -f "$fixture_root/ssh/port" ]] && break; sleep 0.05; done
fixture_server="$PWD/.build/rdp-fixture/server/Sample/sfreerdp-server"
[[ -x "$fixture_server" ]] || scripts/prepare-rdp-fixture.sh
Vendor/Native/bin/openssl req -config /dev/null -x509 -newkey rsa:2048 -nodes \
  -keyout "$fixture_root/key.pem" -out "$fixture_root/cert.pem" -days 1 -subj /CN=localhost > "$fixture_root/cert.log" 2>&1
( cd "$(dirname "$fixture_server")"; exec env -u UNIVERSALREMOTE_FIXTURE_NLA -u UNIVERSALREMOTE_FIXTURE_SAM \
  "$fixture_server" --port=33988 --cert="$fixture_root/cert.pem" --key="$fixture_root/key.pem" ) > "$fixture_root/rdp.log" 2>&1 &
rdp_pid=$!
sleep 0.5
python3 - "$fixture_root" <<'PY'
import base64, hashlib, json, os, ssl, sys
from pathlib import Path
root = Path(sys.argv[1])
ssh = dict(id='58C79947-6D5B-4515-8B76-1729C2D30A61', enabled=True, name='Synthetic SSH', protocol='SSH',
           host='127.0.0.1', port=int((root/'ssh/port').read_text()), username='fixture', password='fixture-password',
           expectedFingerprint=(root/'ssh/fingerprint').read_text().strip())
der = ssl.PEM_cert_to_DER_cert((root/'cert.pem').read_text())
rdp = dict(id='A92F52E2-3EC6-4B91-AD2A-78B07DF02DD0', enabled=True, name='Synthetic RDP', protocol='RDP',
           host='127.0.0.1', port=33988, username='fixture', password='fixture-password',
           expectedFingerprint='SHA256:'+base64.b64encode(hashlib.sha256(der).digest()).decode().rstrip('='))
for name, entries in [('servers.json', [ssh, rdp]), ('wrong-pin.json', [dict(ssh, expectedFingerprint='SHA256:wrong')]),
                      ('invalid.json', [dict(ssh, id=123)])]:
    (root/name).write_text(json.dumps(dict(schemaVersion=1, servers=entries)))
    os.chmod(root/name, 0o600)
PY
scripts/test-live-servers.sh "$fixture_root/servers.json"
for negative in wrong-pin invalid; do
  if WLOG_LEVEL=OFF .build/live-tests/client "$fixture_root/$negative.json" > "$fixture_root/$negative.log" 2>/dev/null; then
    echo "FAIL live probe $negative was accepted." >&2; exit 1
  fi
  echo "PASS live probe rejects $negative."
done
