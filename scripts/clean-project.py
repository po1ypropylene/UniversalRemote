#!/usr/bin/env python3
"""Remove generated checkout artifacts, preserving source and private test input."""
import argparse
import os
from pathlib import Path
import shutil
import stat
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ('.build', 'DerivedData', 'build')
PRESERVED = (
    '.build/dependencies', '.build/openssl', '.build/libssh2', '.build/freerdp',
    '.build/test-venv', '.build/wireguard/cache', '.build/wireguard/mod',
    '.build/Xcode/SourcePackages', 'DerivedData/SourcePackages',
    '.build/core-tests/checkouts', '.build/core-tests/repositories', '.build/core-tests/artifacts',
    'Vendor/Native',
)


def targets(root):
    tracked = set(subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=root).decode().split('\0'))
    result = []

    def select(path):
        relative = str(path.relative_to(root))
        if relative in PRESERVED:
            return
        if any(item.startswith(relative + '/') for item in PRESERVED):
            if path.is_symlink():
                raise RuntimeError('Refusing cleanup of a redirected dependency parent.')
            if path.is_dir():
                for child in path.iterdir():
                    select(child)
        else:
            result.append(path)

    for name in GENERATED:
        select(root / name)
    for base, dirs, files in os.walk(root, followlinks=False):
        relative = Path(base).relative_to(root)
        dirs[:] = [name for name in dirs if name not in
                   {'.git', '.local-testing', '.agents', '.codex'} and
                   str(relative / name) not in (*GENERATED, *PRESERVED)]
        for name in files:
            path = Path(base) / name
            rel = str(path.relative_to(root))
            if (name.endswith(('.log', '.pyc')) or name == '.DS_Store') and rel not in tracked:
                if subprocess.run(['git', 'check-ignore', '-q', '--', rel], cwd=root).returncode == 0:
                    result.append(path)
        for name in list(dirs):
            if name == '__pycache__':
                path = Path(base) / name
                prefix = str(path.relative_to(root)) + '/'
                if not any(item.startswith(prefix) for item in tracked):
                    result.append(path)
                    dirs.remove(name)
    validate_targets(root, result, tracked)
    return result


def validate_targets(root, paths, tracked=None):
    if tracked is None:
        tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0'))
    for path in paths:
        rel = str(path.relative_to(root))
        if any(item == rel or item.startswith(rel + '/') for item in tracked):
            raise RuntimeError('Refusing cleanup: a generated target contains tracked files.')
        for parent in path.parents:
            if parent == root:
                break
            if parent.is_symlink():
                raise RuntimeError('Refusing cleanup through a symbolic-link parent.')


def make_directories_removable(path):
    # Go module-cache directories are intentionally read-only. On macOS/POSIX,
    # removing their contents needs write/search permission on each directory;
    # the files themselves need no permission changes (and may be hard-linked).
    def fail(error):
        raise error

    for base, dirs, _ in os.walk(path, topdown=True, followlinks=False, onerror=fail):
        # Open the directory without following links, then change only our own
        # directory inode. Never chmod a symlink's external target.
        descriptor = os.open(base, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            info = os.fstat(descriptor)
            if info.st_uid == os.geteuid():
                mode = stat.S_IMODE(info.st_mode)
                if mode & stat.S_IRWXU != stat.S_IRWXU:
                    os.fchmod(descriptor, mode | stat.S_IRWXU)
        finally:
            os.close(descriptor)
        dirs[:] = [name for name in dirs if not (Path(base) / name).is_symlink()]


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        make_directories_removable(path)
        shutil.rmtree(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Actually delete generated files.')
    args = parser.parse_args()
    paths = targets(ROOT)
    print('Project cleanup: build outputs, logs, caches and generated test fixtures.')
    print('Preserves native libraries, dependency sources/builds, Go modules, Swift packages, test venv,')
    print('tracked files, source fixtures, .local-testing and user Library/Keychain data.')
    print(f'{sum(p.exists() or p.is_symlink() for p in paths)} generated targets present.')
    if args.apply:
        for path in paths:
            remove(path)
        print('Project cleanup completed. Dependencies retained; run scripts/build.sh to rebuild the app.')
    else:
        print('Preview only. Use --apply to delete, including built apps and release DMGs.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Project cleanup failed: {error}')
