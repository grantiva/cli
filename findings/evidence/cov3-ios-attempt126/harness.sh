#!/bin/zsh
set -euo pipefail
ROOT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt126
LOCKS=/Users/kyle/.grantiva-qa/runner/locks
[[ ! -e "$ROOT" && -d "$LOCKS" ]] || exit 73
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"
find "$LOCKS" -maxdepth 1 -type f -name 'install-*.lock' -print | sort >"$ROOT/install-lock-paths.txt"
[[ -s "$ROOT/install-lock-paths.txt" ]] || exit 74
while IFS= read -r p; do stat -f '%N %z %m %Sp' "$p"; shasum -a 256 "$p"; done <"$ROOT/install-lock-paths.txt" >"$ROOT/install-lock-inventory.txt"
{
 date -u +captured_utc=%Y-%m-%dT%H:%M:%SZ
 print -r -- 'join_lifecycle=findings/evidence/cov3-ios-attempt103b'
 print -r -- 'join_delete=findings/evidence/cov3-ios-attempt106c'
 print -r -- 'join_concurrent_release=/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorLeaseTests.swift'
} >"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
