#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/rdp-test
python3 - <<'PY'
from pathlib import Path
import subprocess
# This fixed synthetic password belongs only to the loopback fixture.
value = subprocess.check_output(['Vendor/Native/bin/openssl', 'dgst', '-md4', '-provider', 'default', '-provider', 'legacy'], input='fixture-password'.encode('utf-16le'))
Path('.build/rdp-test/sam').write_text('fixture:::' + value.decode().strip().split()[-1] + ':\n')
PY
export UNIVERSALREMOTE_FIXTURE_NLA=1
export UNIVERSALREMOTE_FIXTURE_SAM="$PWD/.build/rdp-test/sam"
scripts/test-rdp.sh
