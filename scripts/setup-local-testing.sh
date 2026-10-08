#!/bin/bash
# Preserve an existing credentials file; never print its contents.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
[[ ! -L .local-testing ]] || { echo 'Refusing a symbolic-link credentials directory.' >&2; exit 1; }
mkdir -p .local-testing
chmod 700 .local-testing
[[ ! -L .local-testing/servers.json ]] || { echo 'Refusing a symbolic-link credentials file.' >&2; exit 1; }
if [[ ! -e .local-testing/servers.json ]]; then
  cp Tests/Fixtures/servers.example.json .local-testing/servers.json
fi
chmod 600 .local-testing/servers.json
git check-ignore -q .local-testing/servers.json || { echo 'Credentials path is not Git-ignored.' >&2; exit 1; }
printf 'Local credentials file ready: %s/.local-testing/servers.json\n' "$PWD"
