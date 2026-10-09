#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v go >/dev/null || { echo 'Go 1.27+ is required to build the embedded WireGuard transport.' >&2; exit 1; }
mkdir -p .build/wireguard/cache .build/wireguard/mod Vendor/Native/bin
export GOCACHE="$PWD/.build/wireguard/cache" GOMODCACHE="$PWD/.build/wireguard/mod"
cd Networking/WireGuard
go mod verify
CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 CGO_CFLAGS='-mmacosx-version-min=27.0' CGO_LDFLAGS='-mmacosx-version-min=27.0' \
 go build -trimpath -ldflags='-s -w -linkmode=external -extldflags=-mmacosx-version-min=27.0' -o ../../Vendor/Native/bin/UniversalRemoteWireGuard .
