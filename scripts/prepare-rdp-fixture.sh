#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d .dependencies/sources/FreeRDP ]] || scripts/prepare-dependencies.sh
fixture_source="$PWD/.dependencies/rdp-fixture/source"
mkdir -p "$(dirname "$fixture_source")"
if [[ ! -d "$fixture_source" ]]; then cp -R .dependencies/sources/FreeRDP "$fixture_source"; fi
# Start from the exact upstream sample each time; production libraries are untouched.
git -C .dependencies/sources/FreeRDP show HEAD:server/Sample/sfreerdp.c > "$fixture_source/server/Sample/sfreerdp.c"
git -C .dependencies/sources/FreeRDP show HEAD:server/Sample/sfreerdp.h > "$fixture_source/server/Sample/sfreerdp.h"
cp Tests/Integration/RDP/clipboard_fixture.h "$fixture_source/server/Sample/ur_clipboard_fixture.h"
python3 - "$fixture_source/server/Sample/sfreerdp.c" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1]); text = path.read_text()
header = path.with_suffix('.h')
header.write_text(header.read_text().replace('RdpsndServerContext* rdpsnd;', 'RdpsndServerContext* rdpsnd;\n    struct s_cliprdr_server_context* ur_clipboard;'))
text = text.replace('struct server_info', '#include "ur_clipboard_fixture.h"\n\nstruct server_info', 1)
text = text.replace('rdpsnd_server_context_free(context->rdpsnd);', 'ur_fixture_clipboard_stop(context);\n        rdpsnd_server_context_free(context->rdpsnd);')
text = text.replace('/* Dynamic Virtual Channels */', 'if (!ur_fixture_clipboard_start(context)) return FALSE;\n\n    /* Dynamic Virtual Channels */')
text = text.replace('instance->Open(instance, nullptr, (UINT16)port)', 'instance->Open(instance, "127.0.0.1", (UINT16)port)')
text = text.replace('freerdp_settings_set_bool(settings, FreeRDP_NlaSecurity, FALSE)', 'freerdp_settings_set_bool(settings, FreeRDP_NlaSecurity, getenv("UNIVERSALREMOTE_FIXTURE_NLA") != nullptr)')
text = text.replace('client->PostConnect = tf_peer_post_connect;', '''if (getenv("UNIVERSALREMOTE_FIXTURE_SAM"))
        freerdp_settings_set_string(settings, FreeRDP_NtlmSamFile, getenv("UNIVERSALREMOTE_FIXTURE_SAM"));
    client->PostConnect = tf_peer_post_connect;''')
path.write_text(text)
PY
cmake -S "$fixture_source" -B .dependencies/rdp-fixture/build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=27.0 -DBUILD_SHARED_LIBS=ON -DWITH_CLIENT=OFF \
  -DWITH_CLIENT_COMMON=ON -DWITH_SERVER=ON -DWITH_SHADOW=OFF -DWITH_PROXY=OFF \
  -DWITH_SAMPLE=ON -DWITH_SDL=OFF -DWITH_X11=OFF -DWITH_FFMPEG=OFF \
  -DWITH_DSP_FFMPEG=OFF -DWITH_SWSCALE=OFF -DWITH_OPENH264=OFF -DWITH_OPUS=OFF \
  -DWITH_PCSC=OFF -DWITH_CUPS=OFF -DWITH_FUSE=OFF -DWITH_AAD=OFF \
  -DWITH_JSON_DISABLED=ON -DCHANNEL_URBDRC=OFF -DWITH_MANPAGES=OFF \
  -DOPENSSL_ROOT_DIR="$PWD/Vendor/Native"
cmake --build .dependencies/rdp-fixture/build -j "$(sysctl -n hw.ncpu)"
