#!/bin/bash
# Source from a test harness after changing to the repository root.
umask 077
mkdir -p .build/tests
fixture_root="$(mktemp -d "$PWD/.build/tests/${1:-fixture}.XXXXXX")"
fixture_pids=()
cleanup_test() {
    local status=$?
    trap - EXIT
    for pid in ${fixture_pids[@]+"${fixture_pids[@]}"}; do kill "$pid" 2>/dev/null || true; done
    for pid in ${fixture_pids[@]+"${fixture_pids[@]}"}; do wait "$pid" 2>/dev/null || true; done
    rm -rf "$fixture_root"
    exit "$status"
}
trap cleanup_test EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
