#!/bin/zsh
set -euo pipefail
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-final-inventory"
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
[[ ! -e "$ROOT" ]] || exit 73
mkdir -p "$ROOT"
python3 /Users/kyle/Developer/grantiva-cli/.worktrees/regression/.superpowers/sdd/2026-10-13-round3-coverage-pass/audit_coverage.py ios >"$ROOT/audit.json"
"$GRANTIVA" simulator sessions --json >"$ROOT/sessions.json" 2>"$ROOT/sessions.err"
xcrun simctl list devices -j >"$ROOT/devices.json" 2>"$ROOT/devices.err"
ps -axo pid,ppid,state,etime,command >"$ROOT/processes.txt"
find /tmp/grantiva-sessions -maxdepth 1 -type f -print | sort >"$ROOT/global-session-paths.txt" 2>"$ROOT/global-session-paths.err" || true
cp "$0" "$ROOT/harness.sh"
{
 date -u +captured_utc=%Y-%m-%dT%H:%M:%SZ
 print -r -- 'read-only final inventory; no teardown, shutdown, delete, cleanup, or signal commands'
} >"$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 >"$ROOT/all-files.sha256"
