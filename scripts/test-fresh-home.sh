#!/bin/bash
# scripts/test-fresh-home.sh — run `swift test` with GRANTIVA_RUNNER_HOME set
# to a fresh empty directory and fail if the suite leaves anything in it.
# Tests must write only under their own temp directories, never into the
# runner home (K107-b, L31). Extra arguments go to `swift test`, for example
# `scripts/test-fresh-home.sh --filter DocsContractTests`.
# SWIFT overrides the swift executable (used to check this script itself).
set -uo pipefail

base=${TMPDIR:-/tmp}
home=$(mktemp -d "${base%/}/grantiva-runner-home.XXXXXX") || exit 1
trap 'rm -rf "$home"' EXIT
echo "GRANTIVA_RUNNER_HOME=$home"

GRANTIVA_RUNNER_HOME="$home" "${SWIFT:-swift}" test "$@"
status=$?

leftover=$(find "$home" -mindepth 1 2>/dev/null)
if [ -n "$leftover" ]; then
    echo "error: swift test wrote into the empty runner home $home:" >&2
    printf '%s\n' "$leftover" | sed 's/^/  /' >&2
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::error::swift test wrote into GRANTIVA_RUNNER_HOME; see the paths listed above"
    fi
    exit 1
fi
if [ "$status" -ne 0 ]; then
    exit "$status"
fi
echo "Runner home stayed empty."
