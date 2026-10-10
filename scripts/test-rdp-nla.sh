#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/test-support.sh rdp-nla
python3 - "$fixture_root" <<'PY'
from pathlib import Path
import subprocess, sys
# This fixed synthetic password belongs only to the loopback fixture.
value = subprocess.check_output(['Vendor/Native/bin/openssl', 'dgst', '-md4', '-provider', 'default', '-provider', 'legacy'], input='fixture-password'.encode('utf-16le'))
(Path(sys.argv[1])/'sam').write_text('fixture:::' + value.decode().strip().split()[-1] + ':\n')
PY
export FARCAST_FIXTURE_NLA=1
export FARCAST_FIXTURE_SAM="$fixture_root/sam"
scripts/test-rdp.sh
