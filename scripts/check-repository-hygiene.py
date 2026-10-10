#!/usr/bin/env python3
"""Check repository candidates and ignore rules without reading local credentials."""
import json
from pathlib import Path
import re
import stat
import subprocess

root = Path(__file__).resolve().parent.parent
private_suffixes = {'.pem', '.key', '.p12', '.pfx', '.cer', '.crt', '.der', '.p7b', '.p7c', '.csr', '.jks', '.keystore', '.keychain', '.keychain-db', '.mobileprovision', '.provisionprofile'}
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).split(b'\0')
failures = 0
for encoded in paths:
    if not encoded:
        continue
    relative = encoded.decode()
    path = root / relative
    if relative.startswith('.local-testing/') or path.suffix.lower() in private_suffixes or path.name.startswith(('id_rsa', 'id_ed25519', 'id_ecdsa')) or (path.name.startswith('.env') and path.name != '.env.example'):
        failures += 1
        continue
    if not path.is_file() or path.suffix.lower() in {'.png', '.icns'}:
        continue
    data = path.read_bytes()
    if re.search(rb'-----BEGIN (?:[A-Z0-9 ]*PRIVATE KEY|CERTIFICATE)-----\s+[A-Za-z0-9+/=]{30,}', data):
        failures += 1
# Use synthetic names to test rules; do not enumerate the user's actual secrets.
probes = ['.local-testing/servers.json', '.local-testing/keys/custom-name', 'sample.pem', 'sample.key', 'sample.p12', 'sample.pfx', 'sample.crt', 'sample.cer', 'sample.der', 'sample.p7b', 'sample.csr', 'sample.jks', 'sample.keystore', 'sample.keychain-db', '.env', '.env.local', 'id_ed25519', '.build/rdp-test/key.pem', 'Vendor/Native/lib/example.dylib', '.dependencies/sources/example', '.dependencies/swift-packages/example']
for probe in probes:
    if subprocess.run(['git', 'check-ignore', '-q', '--no-index', probe], cwd=root).returncode != 0:
        failures += 1
for source in ['Farcast/Domain/ConnectionDraft.swift', 'Tests/Fixtures/servers.example.json', 'Farcast.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved']:
    if subprocess.run(['git', 'check-ignore', '-q', '--no-index', source], cwd=root).returncode == 0:
        failures += 1
example = json.loads((root / 'Tests/Fixtures/servers.example.json').read_text())
for entry in example['servers']:
    if entry['enabled'] or any(entry.get(field) for field in ['host', 'username', 'password', 'domain', 'expectedFingerprint']):
        failures += 1
local_dir = root / '.local-testing'
local_file = local_dir / 'servers.json'
for path, mode in [(local_dir, 0o700), (local_file, 0o600)]:
    if path.exists() and (path.is_symlink() or stat.S_IMODE(path.stat().st_mode) != mode):
        failures += 1
if failures:
    # Do not emit filenames/content: a badly named secret can itself disclose information.
    raise SystemExit(f'FAIL repository hygiene: {failures} violations. Inspect local files and ignore rules privately.')
print('PASS repository hygiene: ignore rules, source inclusion, blank example, permissions, no key/certificate payloads.')
