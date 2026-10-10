#!/usr/bin/env python3
"""Reset only Farcast's current-user data and credential service."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

BUNDLE = 'com.peterpo.farcast'
SERVICE = BUNDLE + '.credentials'
KEYCHAIN_SOURCE = '''import Foundation
import Security
import LocalAuthentication
let context = LAContext()
context.interactionNotAllowed = true
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.peterpo.farcast.credentials",
    kSecUseAuthenticationContext as String: context
]
let status = SecItemDelete(query as CFDictionary)
guard status == errSecSuccess || status == errSecItemNotFound else {
    fputs("Credential deletion failed (OSStatus \\(status)). Unlock/authorize the Keychain and retry.\\n", stderr)
    exit(1)
}
print("Farcast credential service cleared (or already empty).")
'''


def targets(home):
    library = home / 'Library'
    return [library / relative for relative in (
        f'Containers/{BUNDLE}',
        'Application Support/Farcast',
        f'Application Support/{BUNDLE}',
        f'Caches/{BUNDLE}',
        f'HTTPStorages/{BUNDLE}',
        f'WebKit/{BUNDLE}',
        f'Preferences/{BUNDLE}.plist',
        f'Saved Application State/{BUNDLE}.savedState',
    )] + [Path(tempfile.gettempdir()) / 'Farcast-Previews']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Permanently delete profiles, trust, settings and credentials.')
    args = parser.parse_args()
    print('Deletes current-user Farcast profiles/folders, WireGuard profiles/keys,')
    print('passwords/private keys, trust decisions, preferences, bookmarks, caches and SFTP previews.')
    print(f'Keychain scope: generic-password items with service {SERVICE}.')
    print('Preserves the installed app, repository, .local-testing, and unrelated Library/Keychain data.')
    if not args.apply:
        print('Preview only. Quit Farcast, then use --apply for a permanent reset.')
        return
    if os.geteuid() == 0:
        raise RuntimeError('Run as your own user without sudo.')
    for process in ('Farcast', 'FarcastWireGuard'):
        status = subprocess.run(['pgrep', '-x', process], stdout=subprocess.DEVNULL).returncode
        if status == 0:
            raise RuntimeError('Quit Farcast and its tunnel helper before resetting data.')
        if status != 1:
            raise RuntimeError('Could not check whether Farcast is running.')
    home = Path.home()
    paths = targets(home)
    for path in paths:
        # Never follow a redirected Library/container path during destructive cleanup.
        for ancestor in [path, *path.parents]:
            if ancestor == home or ancestor == Path(tempfile.gettempdir()):
                break
            if ancestor.is_symlink():
                raise RuntimeError('Refusing reset through a symbolic-link storage path.')
    # Compile before deleting anything. No credential lookup/export or secret output.
    with tempfile.TemporaryDirectory(prefix='farcast-reset-') as folder:
        source = Path(folder) / 'reset.swift'
        binary = Path(folder) / 'reset'
        source.write_text(KEYCHAIN_SOURCE)
        subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(folder) / 'module-cache'),
                        str(source), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    # Ask the preferences service to discard its cached domain before removing files.
    result = subprocess.run(['defaults', 'delete', BUNDLE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode and (home / f'Library/Preferences/{BUNDLE}.plist').exists():
        raise RuntimeError('Preferences deletion failed; reset may be partial. Retry after resolving access.')
    for path in paths:
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()
    print('User-data reset completed. Reopen the app to create an empty library.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'User-data reset failed (may be partial): {error}')
