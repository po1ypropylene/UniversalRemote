#!/usr/bin/env python3
"""Validate platform, dependency closure and signing, then exercise the macOS loader."""
import plistlib
from pathlib import Path
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
if float(info.get('LSMinimumSystemVersion', '0').split('.')[0]) < 27:
    raise SystemExit('The app must require macOS 27 or later.')
executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
libraries = list((app / 'Contents/Frameworks').glob('*.dylib'))

def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

def signing(path):
    details = command('codesign', '-dv', '--verbose=4', str(path))
    team = next((line.split('=', 1)[1] for line in details.splitlines() if line.startswith('TeamIdentifier=')), None)
    return details, team

command('codesign', '--verify', '--deep', '--strict', str(app))
app_signing, app_team = signing(executable)
if 'Signature=adhoc' in app_signing and '(runtime)' in app_signing:
    raise SystemExit('Ad-hoc signing with hardened runtime rejects the bundled libraries. Use scripts/build.sh.')
binaries = list((app / 'Contents/MacOS').iterdir()) + libraries
for binary in binaries:
    if not binary.is_file():
        continue
    if command('lipo', '-archs', str(binary)).strip() != 'arm64':
        raise SystemExit(f'{binary.name} must contain only arm64.')
    if signing(binary)[1] != app_team:
        raise SystemExit(f'{binary.name} has a different signing team.')
    for line in command('otool', '-L', str(binary)).splitlines()[1:]:
        dependency = line.strip().split(' (compatibility')[0]
        if dependency.startswith(('/System/', '/usr/lib/')):
            continue
        if dependency.startswith('@rpath/') and any((app / folder / Path(dependency).name).exists() for folder in ['Contents/Frameworks', 'Contents/MacOS']):
            continue
        raise SystemExit(f'{binary.name} has an unresolved dependency: {dependency}')
# This exits before creating the connection library or UI, but runs the real loader.
result = subprocess.run([str(executable), '--verify-bundle-launch'], capture_output=True, text=True, timeout=15)
if result.returncode != 0 or 'Universal Remote loader check passed' not in result.stdout:
    raise SystemExit('Packaged app failed its loader check. Inspect local build diagnostics.')
print(f'PASS bundle: macOS 27+, arm64, {len(libraries)} native libraries, signatures and loader.')
