#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/prepare-wireguard.sh
export GOCACHE="$PWD/.build/wireguard/cache" GOMODCACHE="$PWD/.build/wireguard/mod"
export UNIVERSALREMOTE_WG_HELPER="$PWD/Vendor/Native/bin/UniversalRemoteWireGuard"
cd Networking/WireGuard
go test -race -count=1 -timeout=90s -v .
