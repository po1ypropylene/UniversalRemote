#!/usr/bin/env python3
"""Remove generated checkout artifacts, preserving source and private test input."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ('.build', 'Vendor/Native', 'DerivedData', 'build')


def targets(root):
    tracked = set(subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=root).decode().split('\0'))
    result = [root / name for name in GENERATED]
    for base, dirs, files in os.walk(root, followlinks=False):
        relative = Path(base).relative_to(root)
        dirs[:] = [name for name in dirs if name not in
                   {'.git', '.local-testing', '.agents', '.codex'} and
                   str(relative / name) not in GENERATED]
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
    for path in result:
        rel = str(path.relative_to(root))
        if any(item == rel or item.startswith(rel + '/') for item in tracked):
            raise RuntimeError('Refusing cleanup: a generated target contains tracked files.')
        for parent in path.parents:
            if parent == root:
                break
            if parent.is_symlink():
                raise RuntimeError('Refusing cleanup through a symbolic-link parent.')
    return result


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Actually delete generated files.')
    args = parser.parse_args()
    paths = targets(ROOT)
    print('Project cleanup: .build, Vendor/Native, DerivedData, build, ignored logs/Python caches.')
    print('Preserves tracked files, source fixtures, .local-testing and user Library/Keychain data.')
    print(f'{sum(p.exists() or p.is_symlink() for p in paths)} generated targets present.')
    if args.apply:
        for path in paths:
            remove(path)
        print('Project cleanup completed. Run scripts/build.sh to regenerate build dependencies.')
    else:
        print('Preview only. Use --apply to delete, including built apps and release DMGs.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Project cleanup failed: {error}')
